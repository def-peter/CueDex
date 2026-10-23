// CueDex managed OpenCode V2 bridge. Only metadata is written to disk.
import { mkdir, readFile, writeFile, rename, unlink } from "node:fs/promises";
import { createHash, randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import path from "node:path";

export function supportsVersion(version) {
    if (typeof version !== "string") return false;
    const match = /^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.exec(version);
    if (!match || match[0] !== version) return false;
    const [major, minor, patch] = match.slice(1, 4).map(Number);
    return [major, minor, patch].every(Number.isSafeInteger)
        && major === 2 && (minor > 1 || (minor === 1 && patch >= 1));
}

// Kept dependency-free: Plugin.define in @opencode/plugin@2.1.1 is the identity
// function. This is its documented { id, setup } Promise plugin contract.
export function createCompletionTracker({ session, emit, enabled, now = Date.now }) {
    const executions = new Map();
    const reset = () => executions.clear();
    async function accept(event) {
        if (event.type === "server.connected") { reset(); return; }
        const sessionID = event.data?.sessionID;
        const sequence = event.durable?.seq;
        if (typeof sessionID !== "string" || !sessionID || event.durable?.aggregateID !== sessionID
            || !Number.isSafeInteger(sequence) || sequence < 0 || event.durable?.version !== 1) return;
        if (event.type === "session.execution.started") {
            const previous = executions.get(sessionID);
            if (previous && sequence <= previous.seq) return;
            // Bound metadata retained by long-running, globally loaded instances.
            if (executions.size >= 1024) executions.delete(executions.keys().next().value);
            executions.set(sessionID, { seq: sequence, message: null, ended: false });
            return;
        }
        const state = executions.get(sessionID);
        if (!state || sequence <= state.seq) return;
        state.seq = sequence;
        switch (event.type) {
        case "session.step.started":
            state.message = event.data.assistantMessageID;
            state.ended = false;
            break;
        case "session.step.failed":
            state.ended = false;
            break;
        case "session.step.ended":
            state.ended = typeof state.message === "string"
                && state.message === event.data.assistantMessageID
                && ["stop", "length"].includes(event.data.finish);
            break;
        case "session.execution.failed":
        case "session.execution.interrupted":
            executions.delete(sessionID);
            break;
        case "session.execution.succeeded": {
            executions.delete(sessionID);
            const age = now() - event.created;
            if (!state.ended || typeof event.id !== "string" || !/^evt_[a-zA-Z0-9_-]+$/.test(event.id)
                || !Number.isFinite(age) || age < 0 || age >= 60_000 || !await enabled()) return;
            // The Promise plugin's session.get returns Session.Info directly.
            const info = await session.get({ sessionID });
            if (info?.id !== sessionID || info.parentID != null || !info.location?.directory) return;
            if (!await enabled()) return;
            await emit({ source: "opencode", eventID: event.id, sessionID, completedAt: event.created / 1000 });
            break;
        }
        }
    }
    return { accept, reset };
}

export async function writeCompletion(event, { directory, enabled, launch }) {
    await mkdir(directory, { recursive: true, mode: 0o700 });
    const name = createHash("sha256").update(event.eventID).digest("hex");
    const temporary = path.join(directory, `.opencode-${randomUUID()}.tmp`);
    try {
        await writeFile(temporary, JSON.stringify(event), { mode: 0o600, flag: "wx" });
        if (!await enabled()) return;
        await rename(temporary, path.join(directory, `cue-opencode-${name}.json`));
        launch();
    } finally { await unlink(temporary).catch(() => {}); }
}

export default {
    id: "cuedex.attention",
    setup(ctx) {
        if (!supportsVersion(ctx?.app?.version)
            || typeof ctx?.session?.get !== "function"
            || typeof ctx?.event?.subscribe !== "function") return;
        const eventsDirectory = "__CUEDEX_EVENTS__";
        const gate = "__CUEDEX_GATE__";
        const generation = "__CUEDEX_GENERATION__";
        const appBundle = "__CUEDEX_APP__";
        const controller = new AbortController();
        const enabled = async () => {
            try { return !controller.signal.aborted && (await readFile(gate, "utf8")) === generation; }
            catch { return false; }
        };
        const tracker = createCompletionTracker({
            session: ctx.session,
            enabled,
            emit: event => writeCompletion(event, {
                directory: eventsDirectory, enabled,
                launch: () => execFile("/usr/bin/open", ["-gj", appBundle], () => {}),
            }),
        });
        let retry;
        let resolveRetry;
        void (async () => {
            while (!controller.signal.aborted) {
                tracker.reset();
                try {
                    for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
                        if (controller.signal.aborted) break;
                        try { await tracker.accept(event); }
                        catch { tracker.reset(); } // Never log raw events or private errors.
                    }
                } catch { tracker.reset(); }
                if (controller.signal.aborted) break;
                await new Promise(resolve => { resolveRetry = resolve; retry = setTimeout(resolve, 1000); });
            }
        })();
        return () => {
            controller.abort();
            clearTimeout(retry);
            resolveRetry?.();
            tracker.reset();
        };
    },
};
