# 0039. PiG runs through a bridge of Nushi's own, on its RPC mode

## Context
PiG (pi-in-go.dev, a Go port of the Pi coding agent, MIT) has no ACP in its core. Its RPC mode, `pig --mode rpc`, is Pi 1.4.0's protocol: JSON lines of commands (with ids) in, responses and events out, one session per process (`new_session`, `switch_session`, `fork` and `clone` replace it). It has what Nushi uses: prompts with images, streamed text and thinking, tool events, `abort`, `steer`, models and thinking levels, `get_session_stats` (context and cost), `get_commands`, `get_entries` (the session's tree), `fork` before a user's message and `clone`, and extensions' dialogs (`extension_ui_request`: select, confirm, input, editor; notify). Sessions are JSON Lines files under PiG's agent folder. PiG has no permissions or modes: its tools run without asking.

The author's ACP adapter, `pig-acp` (MichaelKinsy/pigpen, `components/acp`, MIT, a port of Sergii Kozak's pi-acp), also drives RPC mode. It has no published binary: it is installed as an npm package through `pig install`, then built with the user's Go. It keeps one pig per connection (a new session closes the last), has no fork, close or steering, maps dialogs to permission requests and drops input dialogs.

## Decision
- Nushi brings its own ACP agent for PiG, in Go: `nushid pig-acp` speaks ACP on stdio and runs a `pig --mode rpc` per session, in the session's folder, with the daemon's environment (ADR 0028), as the Ante bridge does for `ante serve` (ADR 0030). It runs the user's `pig` from `PATH` (ADR 0037); nothing to set up. Nothing outside `internal/pig` knows PiG's protocol.
- Mapping: session new; load (`--session <file>`, the replay walked from `get_entries`' leaf to its root); list (session files' headers, forks left out: `parentSession`); fork whole (`clone`) or after the turn that has a message (`_meta.pig.afterMessage`: `fork` before the user's next message); close; delete (the file to the Trash, as PiG's `/resume`). Prompt (files as `@path`, images), cancel (`abort`), `_session/steering` (`steer`); tool calls with their output, an edit's changes and a write's diff; model and thinking level as config options; `usage_update` with cost after each turn; slash commands from `get_commands` (prompt templates, skills, extensions' commands), and `/compact` and `/name` of the bridge's own (RPC's `compact` and `set_session_name`); a compaction as a tool call holding its summary, live and in a replay; the Context card from `get_session_stats` (`_pig/context`); an extension's todo list as the plan; the title from `session_info_changed`; a dialog as a one-field question, withdrawn when PiG's timeout ends it, a notification as a message.
- An assistant message's id is its timestamp, which the event and the session file share, so a fork finds it after a reload.
- No trust card: in RPC mode PiG loads a folder's settings, MCP servers, extensions, skills, prompts and system prompt only for a folder the user trusted in PiG (its `trust.json`, or `defaultProjectTrust: always`); it can't ask, and loads none of them otherwise. What it loads regardless is instructions (`AGENTS.md`, `CLAUDE.md`).
- The bridge follows PiG 0.5.3's RPC mode; another version is tried and says so in the log. It logs pig's start and exit, passes pig's stderr on (the daemon tags it with the chat), and writes each RPC call as a line the daemon logs at DEBUG (ADR 0038).

## Consequences
- Nothing to install beyond PiG; PiG's settings, keys and sessions are PiG's, and a PiG chat resumes in a terminal (`pig --session <id>`).
- A PiG chat runs every tool call without asking: PiG has no permission control for Nushi to show (ADR 0007).
- PiG takes no lock on a session: a terminal's pig and Nushi's both append, each on its own branch, and a resume follows whichever wrote last. Nushi can't tell a session is open elsewhere.
- The bridge follows RPC mode as PiG changes it; the version it was built against is pinned in `internal/pig`.

## Alternatives considered
- `pig-acp`: npm and a Go toolchain on the user's Mac and a build step, one pig per connection, no fork, close or steering. Nothing in RPC mode is hidden from a bridge of ours, so it would only be worse.
- PiG's Go SDK inside Nushi: a copy of PiG of Nushi's own, not the user's (ADR 0037), a large module that changes often, and provider logins in the daemon.
