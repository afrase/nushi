# Codex facts

What Nushi depends on, as seen when it was built against the versions named below. Read it before changing the code that talks to it.

## Agent facts (codex-acp 2.2.2; Codex 0.160.1, then yours, 0.163.0)

Until milestone Z the adapter ran its own Codex, 0.160.1 (the facts below were seen with it). Since then it runs yours (`CODEX_PATH`, which codex-acp reads for its app-server, `codex app-server`): 0.163.0, tried by hand in milestone Z (a turn, a reopen after a daemon restart, on DeepSeek V4.1 Flash with a temp `CODEX_HOME`). `codex.Tested` lists both. Your `codex` is npm's `codex.js` launcher (Node, about 14 MB) in front of the native binary, as in a terminal.

What the code depends on, and how the adapter behaves. Everything Nushi does about it is in `internal/codex*`.

**Sessions**
- `initialize`: `agentInfo.name` `@agentclientprotocol/codex-acp`, `loadSession`, `sessionCapabilities` resume, list, close, delete, fork, additionalDirectories, subagents; `promptCapabilities.image`; `_meta.steering.supported`. It advertises an `api-key` auth method (ChatGPT login too, unless `NO_BROWSER`); with a provider in `config.toml` no `authenticate` is needed. Without a login or provider, `session/new` fails "Authentication required".
- `session/new` returns legacy `modes` (read-only, workspace-write, agent "Auto review" (the default), agent-full-access "Full access"), the unstable `models` list (ids carry the effort as a suffix, `gpt-6.1-sol[medium]`; Nushi doesn't read it) and config options `mode`, `collaboration_mode` (default, plan), `model` (base ids), and, when the model has reasoning levels, `reasoning_effort` (category `thought_level`) and `fast-mode`. A custom model is listed only while it is the current one: after switching to a GPT model, switching back is "Invalid params" (with a model catalog it stays listed). Agent-full-access is a mode like Claude's Bypass permissions: shown, never picked by Nushi itself.
- codex-acp starts and forks every session with `projects.<cwd>.trust_level = "trusted"` as a config override (ADR 0029).
- `session/load` replays user messages (with `messageId`), agent messages (same `msg_…` ids as live), tool calls with their output, thoughts and the title; not the model-metadata warning, permission cards or questions. `session/list` works for a `/private/…` cwd.
- `session/fork` takes another `cwd` (so a move needs no history copy) and `_meta.jetbrains.air.fork = {version: 1, messageId}` for any client: the fork keeps the turns up to the one that has the message. It replays nothing. After a fork Codex titles the session after its next prompt.
- `session/delete` is `thread/archive`: the rollout moves to `$CODEX_HOME/archived_sessions/`; `codex resume <id>` then asks "Unarchive and resume". `codex delete <id>` would delete for good. History is `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-…-<id>.jsonl`; `codex resume` in a terminal first asks to trust the folder, says when another app has the session open, and leaves a Codex app-server running in the background (`$CODEX_HOME/packages/app-server-daemon`).

**Updates**
- Commands are `exec_command` tool calls: `kind` execute (content a `terminal` reference even without the client's `terminal` capability) or read/search for listing commands (no content). A client that isn't AIR gets the output in `_meta.terminal_output_delta {data}` on `tool_call_update`s and the end in `_meta.terminal_exit {exit_code, signal}`; read commands send `rawOutput.exit_code`. After Stop a running command finishes on its own and its call completes then.
- Permission requests come before the call's `tool_call`; options "Yes, proceed" (allow_once), "Yes, and don't ask again for commands that start with …" (allow_always), "No, and tell Codex what to do differently" (reject_once). In Auto review nothing harmless asks; in Read-only writing a file does.
- Questions (`request_user_input`) only in collaboration mode Plan: an `elicitation/create` form tied to a call id it never sends as a tool call, each question a required string with `oneOf` plus "None of the above", then an optional `<id>_note` "Additional answer or note".
- `session_info_update` carries the title (the first prompt, whole) and `_meta.codex.threadStatus`. `usage_update` gives used/size (no cost); the prompt result has `usage` and `_meta.quota`. Thoughts come as `agent_thought_chunk`s with `rs_…` ids.
- Without model metadata each turn starts with an agent message without `messageId`: "Warning: Model metadata for `…` not found…", and the window is 258,400.
- Plans come as agent text: codex-acp sends `plan` updates only to clients advertising a `plan` capability.

- Listing (milestone X): codex-acp's `session/list` pages through every thread (`thread/list`, sources cli, vscode, exec, appServer, unknown: no subagents; unarchived only) and then keeps those whose cwd equals the request's exactly (no link resolved: `/tmp` finds nothing, `/private/tmp` does); the title is the first prompt. A fork's rollout starts with `session_meta.payload.forked_from_id`.
- One writer at a time: whoever has a thread holds a lock on `$CODEX_HOME/thread-writer-locks/<id>.lock` (flock; F_GETLK sees it). The TUI then shows "This conversation is open in another app… press R" and is read-only; codex-acp's `session/load` fails "This Codex session is in use by another Codex client (the Codex app, the CLI or an IDE extension)". The TUI runs through a background app-server (`$CODEX_HOME/packages/app-server-daemon`), which keeps the thread, and its lock, after the TUI quits. A Nushi chat that sleeps lets go (the lock file goes).
- The TUI asks to update itself at start: Enter there runs `npm install -g @openai/codex`. `check_for_update_on_startup = false` in `config.toml` stops it.
