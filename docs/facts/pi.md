# Pi facts

What Nushi depends on, as seen when it was built against the versions named below. Read it before changing the code that talks to it. Pi's RPC mode is what PiG ports, so [PiG's facts](pig.md) hold unless this page says otherwise.

## Agent facts (Pi 1.4.0, 2026-11-01, through the bridge)

Seen from `@earendil-works/pi-coding-agent` 1.4.0 from npm (`--ignore-scripts`) in a throwaway `HOME` with a clean environment, `nushid pi-acp` driven over ACP, the model a local fake OpenAI-compatible server, and from its bundled docs.

- **Worked through the bridge:** initialize, new session, model option, streamed reply, usage, `bash` and `write` tool calls, `_pi/context`, list, `/name`, `/compact` (asked too early: "Nothing to compact (session too small)", as PiG), close, load with its replay and message times, fork whole, fork after a message.
- `pi --version` prints `1.4.0`, nothing else.
- Install: `curl -fsSL https://pi.dev/install.sh | sh` or `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`. Both run under Node 22.19 or newer (the installer can install it).
- Agent folder: `PI_CODING_AGENT_DIR`, else `~/.pi/agent`. No `PI_HOME`, no `XDG_CONFIG_HOME`. Sessions: `PI_CODING_AGENT_SESSION_DIR`, else the settings' `sessionDir`, else `<agent dir>/sessions`. **A relative `sessionDir` resolves from the working folder** (`normalizePath`), not the agent folder.
- With no model configured, `get_state`'s `model` is a stub (`id: "unknown"`, `provider: "unknown"`) and `get_available_models` is empty; the bridge offers no model option then.
- Trust as PiG's: `<agent dir>/trust.json`, `defaultProjectTrust`; RPC mode can't ask.
- Skills as PiG's, with `.pi` for `.pig`. Seen on get_commands: the project's only once trusted; a project's `-skills/<folder>` in the cwd's `.pi/settings.json` turns off `.agents/skills/<folder>`, from that folder only (from a subfolder, with no `.pi` of its own, it stays on); `!<glob>`; in your settings `-skills/<folder>` and `-<absolute path>`; a `SKILL.md` without a description isn't loaded.
- A version check goes to `pi.dev` unless `PI_SKIP_VERSION_CHECK` is set, and install and update telemetry unless `PI_TELEMETRY` says no. Nushi sets neither: they're the user's settings.
- Project trust came in 0.79.0 (changelog), `get_entries` in 0.80.3, `agent_settled` in 0.80.4.

**Not run:** extensions' dialogs, images, steering, a compaction that compacts, a real model. The protocol is PiG's, and those pass on the fake pi.
