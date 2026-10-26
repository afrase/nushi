# Ante facts

What Nushi depends on, as seen when it was built against the versions named below. Read it before changing the code that talks to it.

## Agent facts (Ante 0.2.14, through the bridge)

What the bridge (`internal/ante`) depends on, seen with `ante serve --stdio`; the protocol is Ante's open `crates/protocol-shape/src/msg.rs` at v0.2.14.
- Ops go in as `{"op": …, "id": "op_<ULID>"}` (a bad id is an `Error`); events come out with `parent`, the op they answer. An input's op id is its turn's id. No greeting.
- `StartSession{cwd}` answers `SessionStart` (session id, cwd, permission mode, model with `effort` and maybe `supported_efforts`, provider); unset fields come from `~/.ante/settings.json` (the user's default model, Kimi K3 here). `ResumeSession` answers `SessionEnd` (of any running one), `SessionStart`, `ExtensionRefreshed`, then the saved event log, with no end marker: the bridge sends `ContextReport` right behind it and takes its answer as the end (the host answers ops in order). Permission mode always comes from the current settings on a resume; the model is the session's.
- Live, the host echoes every input as `UserInput` (steers too, which the docs say it doesn't); streams `MessageDelta`/`ThinkingDelta`, then repeats the whole text (dropped once deltas came; replays have only the whole texts). A turn can hold several `AgentMessage`s; the bridge names them `<turn id>.<n>`.
- An approval (`TurnPause.Approval`) comes before the call's `ToolStart`; a denied call ends with a `ToolEnd{Denied}` and no start. `AcceptAlways` would write an allow rule into `settings.json`, so the bridge never offers it. Questions are `TurnPause.Question` (AskUser), answered with `QuestionResponse`.
- `UpdateSession` (model, effort, permission mode) answers `SessionUpdated` and doesn't write `settings.json` (checked). `ForkSession{at: <input id>}` needs an idle session and saves the fork without starting it (`SessionForked`); the bridge resumes it on a host of its own.
- `ToolEnd.result_json` shapes: Bash `{"Completed":{exit_code, stdout, stderr}}` (status `Failed` when the code isn't 0), Read `{file_type:{Text:{lines}}}`, Edit `{patch, summary}`, Write `{lines_written, message}`, AskUser `{message}`, a denial a string.
- Sessions are `~/.ante/sessions/<id>/{meta.json, events.jsonl, dialog.json}` (`ANTE_HOME` moves `~/.ante`, logs included); there's no op to list or delete them, so the bridge reads `meta.json` and removes the folder. A resume rewrites `meta.json` with zero usage.
- A project's `.ante/settings.json` can't widen what Ante may do: mode, allow rules, MCP servers, system prompt, model and provider are ignored with an `Info` notice (checked).
- `ante catalog` prints every provider's models (no keys: a provider's key is named by `env_key`).

- Listing and two writers (milestone X): a headless or TUI session's `meta.json` has `message_count`, `model`, `provider` and `first_user_message`, which Ante's front end ends with a `<folder-structure>` listing of the folder (the bridge drops it in titles and replays). Ante takes no lock: its TUI keeps `events.jsonl` open for writing while it has the session (lsof finds it in about 0.07 s). With the TUI and Nushi on one session both appended to `events.jsonl`, and a later `ante -r` knew only Nushi's turn: the resume reads `dialog.json`, which the last to save rewrites.
