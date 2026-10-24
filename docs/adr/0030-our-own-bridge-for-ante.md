# 0030. Ante runs through a bridge of Nushi's own

## Context
Ante speaks its own protocol (`ante serve`: ops in, events out, JSON lines), not ACP. Its ACP adapter, `ante-acp` 0.2.0 (crates.io, Rust, not in Ante's release tarballs), covers prompts, tools with diffs and permissions, but not what Nushi uses beyond that: reopening a session (`session/load` with its replay; without it an Ante chat comes back empty after a daemon restart, ADR 0027), fork at an input, steering (a prompt sent during a turn becomes a steer), questions (AskUser is switched off), usage, `ContextReport`, model and effort. The serve protocol has all of them, and its types are open (`crates/protocol-shape/src/msg.rs`).

## Decision
- Nushi brings its own ACP agent for Ante, in Go: `nushid ante-acp` speaks ACP on stdio and runs an `ante serve --stdio` per session. The daemon launches it like any agent; nothing outside `internal/ante` knows Ante's protocol.
- It maps only what Nushi uses: session new, load (the resume's replay, which has no end marker: a `ContextReport` sent right behind the resume marks it), list (from `sessions/*/meta.json`), fork (whole, or after a turn, through `_meta.ante.afterMessage`), close and delete (the session's folder: Ante has no op for it); prompt, cancel, `_session/steering`; tool calls with diffs; permissions (Allow, Allow for this session, Deny: never Ante's "always", which writes the user's settings); AskUser as an elicitation form; usage; `_ante/context` (the `ContextReport`, for the Context card); model and effort as config options (models from `ante catalog`), mode as the session's modes. `/term`, goals, ambient hints, the gateway and Ante Remote are left out.
- It follows Ante 0.2.14's protocol; an older `ante` is refused at `initialize`, a newer one tried (logged).

## Consequences
- Nothing to install beyond Ante itself; Ante's `settings.json` is read by Ante, never by Nushi, and the bridge changes nothing in it (model, effort and mode changes are the session's).
- The bridge follows Ante's protocol as it changes; the pinned version says which one it was built against.
- Agent message ids are the bridge's own (`<input op id>.<n>`), so a fork at a message can cut after its turn.

## Alternatives considered
- `ante-acp` as it is: Ante chats that can't reopen, no questions, no usage.
- Filling `ante-acp`'s gaps upstream: the right home for the community, but Nushi would wait on a release and on users running `cargo install`.
