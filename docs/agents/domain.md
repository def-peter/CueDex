# Domain Docs

Before exploring the codebase, read:

- `CONTEXT.md` at the repository root when it exists
- relevant ADRs under `docs/adr/`

Missing files should not block work or trigger suggestions to create empty
documents. Domain-modeling skills create them when terminology or architectural
decisions are actually resolved.

## Layout

CueDex uses a single-context layout:

- `/CONTEXT.md` - domain vocabulary and boundaries
- `/docs/adr/` - architectural decision records

Use vocabulary defined in `CONTEXT.md`. Explicitly flag proposals that conflict
with an existing ADR instead of silently overriding it.
