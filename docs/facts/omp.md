# oh-my-pi facts

What Nushi depends on, as seen when it was built against the versions named below. Read it before changing the code that talks to it.

## Agent facts (oh-my-pi 18.12.6)

What the code depends on (`internal/omp*`), from driving `omp --mode acp` and its source.
- `initialize`: `agentInfo` `omp`, `loadSession`, `sessionCapabilities` list, fork, resume, close (no delete: `session/delete` fails "Unknown ACP ext method"), `promptCapabilities.image`, `_meta.steering.supported`; extensions `_omp/usage`, `_omp/extensions` and more.
- `session/new` returns legacy modes and config options `mode` (default, plan; not permissions), `model` (`<provider>/<id>`, the models of providers with a key: with `FIREWORKS_API_KEY`, 35 Fireworks ones; Kimi K3 by default) and `thinking` (category `thought_level`: off, auto, then the model's levels). A model picked stays with the session.
- Permissions: only bash, delete and move ask (Allow once, Always allow, Reject, Always reject); writes and edits never do. The request comes before the call's `tool_call`. A command's title starts with `$ ` (the dialect drops it).
- Questions: its ask tool exists only for a client with form elicitation; each question is `qN` with `oneOf`, then `qN__other`, "Other (type your own)". An empty answer ends the turn as cancelled.
- `usage_update` carries used, size and cost; the prompt result carries usage. A prompt during a turn cancels the turn; `_session/steering` injects ("injected").
- `session/load` replays user messages, tool calls and agent messages (fresh message ids each time); `session/fork` copies the whole session.
- Sessions are `~/.omp/agent/sessions/<folder name>/<time>_<id>.jsonl`; all of omp's state is under `~/.omp` (`PI_CODING_AGENT_DIR` moves only `agent/`), so a test points `HOME` at a temp folder.
- It runs only under Bun (≥ 1.3.14). Since milestone Z Nushi runs your `omp`, whose `#!/usr/bin/env bun` finds your Bun on PATH; with no `omp` it isn't offered, with no `bun` it says "Needs Bun".

- Listing (milestone X): `session/list` gives `{sessionId, cwd, title, updatedAt, _meta: {messageCount, size}}`, 50 a page (cursor an offset), the cwd matched either way (`/tmp` or `/private/tmp`); a `-p` run has an empty title. Session files start with a title record, then `{"type":"session", id, cwd, parentSession?}` (a fork names its parent). One process owns a session: a flock on `~/.omp/run/session-owners/<id>.lock`; another that writes to it saves to a new session instead, with `parentSession` ("Session … is open for writing in another omp process, so this session now saves to …").
