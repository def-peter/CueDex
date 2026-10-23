import test from "node:test";
import assert from "node:assert/strict";
import { readFile, writeFile, mkdtemp, readdir, stat, rm } from "node:fs/promises";
import vm from "node:vm";
import { createHash, randomUUID } from "node:crypto";
import * as fs from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const source = await readFile(new URL("../CueDex/Resources/cuedex-opencode.js", import.meta.url), "utf8");
const { supportsVersion, createCompletionTracker, writeCompletion, default: plugin } = await import(
    `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
);
const now = 2_000_000;
function fixture({ parentID, lookup, enabled = async () => true } = {}) {
    const emitted = [];
    let sequence = 0;
    const tracker = createCompletionTracker({
        now: () => now,
        enabled,
        session: { get: lookup ?? (async ({ sessionID }) => ({ id: sessionID, parentID, location: { directory: "/fixture" } })) },
        emit: async event => emitted.push(event),
    });
    function event(type, data = {}, overrides = {}) {
        const seq = sequence++;
        return {
            id: `evt_${seq}`, created: now, type: `session.${type}`,
            durable: { aggregateID: "ses_main", seq, version: 1 },
            data: { sessionID: "ses_main", assistantMessageID: "msg_primary", ...data }, ...overrides,
        };
    }
    async function send(type, data, overrides) { await tracker.accept(event(type, data, overrides)); }
    async function steps() { await send("step.started"); await send("step.ended", { finish: "stop" }); }
    async function round() { await send("execution.started"); await steps(); await send("execution.succeeded"); }
    return { tracker, emitted, event, send, steps, round };
}

test("root primary success forwards only the metadata whitelist", async () => {
    const f = fixture();
    await f.send("execution.started");
    await f.steps();
    await f.send("execution.succeeded", {}, { metadata: { secret: "DO NOT RETAIN" } });
    assert.deepEqual(f.emitted, [{ source: "opencode", eventID: "evt_3", sessionID: "ses_main", completedAt: now / 1000 }]);
});

test("child completions and absent session metadata are skipped", async () => {
    for (const options of [{ parentID: "ses_parent" }, { lookup: async () => ({}) }]) {
        const f = fixture(options); await f.round(); assert.equal(f.emitted.length, 0);
    }
});

test("mid-execution loading and compaction-only drains never notify", async () => {
    const f = fixture();
    await f.steps(); await f.send("execution.succeeded");
    await f.send("execution.started"); await f.send("execution.succeeded");
    assert.equal(f.emitted.length, 0);
});

test("a started request without a matching successful end is insufficient", async () => {
    const f = fixture();
    await f.send("execution.started"); await f.send("step.started"); await f.send("execution.succeeded");
    assert.equal(f.emitted.length, 0);
});

test("latest primary step must complete, even if a prior step ended", async () => {
    const f = fixture(); await f.send("execution.started"); await f.steps();
    await f.send("step.started"); await f.send("execution.succeeded");
    assert.equal(f.emitted.length, 0);
});

test("failure and interruption never notify", async () => {
    for (const terminal of ["failed", "interrupted"]) {
        const f = fixture(); await f.send("execution.started"); await f.steps();
        await f.send(`execution.${terminal}`); await f.send("execution.succeeded");
        assert.equal(f.emitted.length, 0);
    }
});

test("retries may reuse message IDs, but only final complete execution notifies", async () => {
    const f = fixture(); await f.send("execution.started"); await f.send("step.started");
    await f.send("step.failed"); await f.steps(); await f.send("execution.succeeded");
    assert.equal(f.emitted.length, 1);
});

test("isolated tool-calls, errors, and mismatched message ends never notify", async () => {
    for (const data of [{ finish: "tool-calls" }, { finish: "error" }, { finish: "stop", assistantMessageID: "msg_other" }]) {
        const f = fixture(); await f.send("execution.started"); await f.send("step.started");
        await f.send("step.ended", data); await f.send("execution.succeeded");
        assert.equal(f.emitted.length, 0);
    }
});

test("reconnect discards incomplete execution evidence", async () => {
    const f = fixture(); await f.send("execution.started"); await f.steps();
    await f.tracker.accept({ type: "server.connected" }); await f.send("execution.succeeded");
    assert.equal(f.emitted.length, 0);
    await f.round(); assert.equal(f.emitted.length, 1);
});

test("stale or future terminal events are discarded", async () => {
    for (const created of [now - 60_000, now + 1]) {
        const f = fixture(); await f.send("execution.started"); await f.steps();
        await f.send("execution.succeeded", {}, { created }); assert.equal(f.emitted.length, 0);
    }
});

test("disabling during metadata lookup prevents forwarding", async () => {
    let enabled = true;
    const f = fixture({ enabled: async () => enabled, lookup: async ({ sessionID }) => {
        enabled = false; return { id: sessionID, location: { directory: "/fixture" } };
    } });
    await f.round(); assert.equal(f.emitted.length, 0);
});

test("lookup errors never become completion notifications", async () => {
    const f = fixture({ lookup: async () => { throw new Error("private error"); } });
    await assert.rejects(f.round()); assert.equal(f.emitted.length, 0);
});

test("duplicate terminal and out-of-order events cannot create another round", async () => {
    const f = fixture(); await f.send("execution.started"); await f.steps();
    const terminal = f.event("execution.succeeded");
    await f.tracker.accept(terminal); await f.tracker.accept(terminal);
    assert.equal(f.emitted.length, 1);
    await f.round(); assert.equal(f.emitted.length, 2);
});

test("stable V2 upgrades remain eligible while old, prerelease and malformed versions do not", () => {
    for (const version of ["2.1.1", "2.1.2", "2.1.3", "2.1.10", "2.2.0", "2.10.0", "v2.1.3", "2.1.3+build.1"]) {
        assert.equal(supportsVersion(version), true, version);
    }
    for (const version of [undefined, null, 213, "", "1.9.0", "2.0.32", "2.1.0", "3.0.0", "v3.1.1", "2.1.3-beta.1", "2.2.0-rc.1+build", "2.1", "2.01.3", "2.1.03", "2.1.3junk", "2.1.3\n", " 2.1.3", "2.1.3+", "2.1.3+foo..bar", "2.1.9007199254740992"]) {
        assert.equal(supportsVersion(version), false, String(version));
        assert.equal(plugin.setup({ app: { version } }), undefined);
    }
});

test("eligible versions still require the session and event interfaces", () => {
    for (const context of [undefined, {}, { app: { version: "2.1.3" } },
        { app: { version: "2.1.3" }, session: { get: true }, event: { subscribe() {} } },
        { app: { version: "2.1.3" }, session: { get() {} }, event: { subscribe: true } }]) {
        assert.equal(plugin.setup(context), undefined);
    }
});

test("supported plugin subscribes with cancellation and cleans up without forwarding", async () => {
    for (const version of ["2.1.1", "2.1.3", "v2.1.3", "2.1.10", "2.2.0"]) {
        let signal;
        let stopped = false;
        const cleanup = plugin.setup({
            app: { version },
            session: { get: async () => { throw new Error("must not look up an incomplete round"); } },
            event: { async *subscribe(options) {
                signal = options.signal;
                try {
                    await new Promise(resolve => signal.addEventListener("abort", resolve, { once: true }));
                } finally { stopped = true; }
            } },
        });
        assert.equal(typeof cleanup, "function");
        assert.equal(signal.aborted, false);
        cleanup();
        await new Promise(resolve => setImmediate(resolve));
        assert.equal(signal.aborted, true);
        assert.equal(stopped, true);
    }
});

test("V2.1.3 setup delivers a complete round through the rendered bridge and honors disable", { timeout: 5000 }, async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "cuedex-setup-"));
    const gate = path.join(directory, "enabled");
    const events = path.join(directory, "Events");
    const generation = "fixture-generation";
    const app = "/Applications/CueDex.app";
    let cleanup;
    try {
        await writeFile(gate, generation);
        let rendered = source;
        for (const [key, value] of Object.entries({ EVENTS: events, GATE: gate, GENERATION: generation, APP: app })) {
            rendered = rendered.replaceAll(`"__CUEDEX_${key}__"`, JSON.stringify(value));
        }
        const launches = [];
        let complete;
        const launched = new Promise(resolve => { complete = resolve; });
        const script = rendered.replace(/^import .*;\n/gm, "")
            .replace(/^export (?=(?:async )?function )/gm, "")
            .replace("export default ", "globalThis.bridge = ");
        const context = vm.createContext({
            ...fs, createHash, randomUUID, path, AbortController, setTimeout, clearTimeout,
            execFile: (...args) => { launches.push(args.slice(0, 2)); complete(); },
        });
        vm.runInContext(script, context);
        const f = fixture();
        const completedAt = Date.now();
        const round = () => [f.event("execution.started"), f.event("step.started"),
            f.event("step.ended", { finish: "stop" }), f.event("execution.succeeded", {}, { created: completedAt })];
        let subscription;
        let finishStream;
        const streamFinished = new Promise(resolve => { finishStream = resolve; });
        cleanup = context.bridge.setup({
            app: { version: "2.1.3" },
            session: { get: async ({ sessionID }) => ({ id: sessionID, location: { directory: "/fixture" } }) },
            event: { async *subscribe({ signal }) {
                subscription = signal;
                for (const event of round()) yield event;
                await rm(gate);
                for (const event of round()) yield event;
                finishStream();
                await new Promise(resolve => signal.addEventListener("abort", resolve, { once: true }));
            } },
        });
        assert.equal(typeof cleanup, "function");
        await launched;
        await streamFinished;
        const files = await readdir(events);
        assert.equal(files.length, 1);
        assert.deepEqual(JSON.parse(await readFile(path.join(events, files[0]), "utf8")), {
            source: "opencode", eventID: "evt_3", sessionID: "ses_main",
            completedAt: completedAt / 1000,
        });
        assert.equal(launches.length, 1);
        assert.equal(launches[0][0], "/usr/bin/open");
        assert.deepEqual(Array.from(launches[0][1]), ["-gj", app]);
        cleanup();
        assert.equal(subscription.aborted, true);
    } finally {
        cleanup?.();
        await rm(directory, { recursive: true, force: true });
    }
});

test("atomic bridge files are private and do not retain temporary files", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "cuedex-bridge-"));
    try {
        let launches = 0;
        const event = { source: "opencode", eventID: "evt_test", sessionID: "ses_main", completedAt: 2000 };
        await writeCompletion(event, { directory, enabled: async () => true, launch: () => launches++ });
        const files = await readdir(directory); assert.equal(files.length, 1);
        assert.equal((await stat(path.join(directory, files[0]))).mode & 0o777, 0o600);
        assert.deepEqual(JSON.parse(await readFile(path.join(directory, files[0]), "utf8")), event);
        assert.equal(launches, 1);
        await writeCompletion({ ...event, eventID: "evt_disabled" }, { directory, enabled: async () => false, launch: () => launches++ });
        assert.equal((await readdir(directory)).length, 1); assert.equal(launches, 1);
    } finally { await rm(directory, { recursive: true, force: true }); }
});
