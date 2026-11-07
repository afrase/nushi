# 0098. The daemon runs a folder's dev servers

Status: accepted, 2026-11-07. Amends [0056](0056-the-daemon-restarts-itself-when-idle.md) (a server holds the restart).

## Context
The owner asked for Claude desktop's Servers button: the dev servers a project configures (its launch files, ADR 0095) listed beside the browser tab (ADR 0094), each run and stopped from its row, its page opening beside the chat. Claude desktop runs them in its app and gives its agent `preview_*` tools; Nushi's app comes and goes while the daemon keeps chats and terminals, and six agents run there, four without MCP. Design and review: the browser design's D7 and D10 (docs/facts/claude.md has what Claude does).

## Decision
- **The daemon runs them** (`internal/features/servers`), only on the user's ▶: the Mac's calls `ListServers`, `StartServer`, `StopServer`, `StopAllServers` (macOnly, and the Mac's socket checked, as `WriteChatFile`), a `servers_changed` event naming the folder. No call takes a command: `StartServer` names an entry by name or place. Entries are read afresh from the chat's folder (or worktree, or the main checkout's) on each list.
- **A server is keyed by folder and entry name** with a stable id: the chats in a folder share it, each worktree has its own, five run in a folder at most, and starts of one entry at once are one server. Its config hash says when the entry changed since ("restart to apply").
- **Spawned like a terminal's program, without the shell**: on a pty (`internal/terminal`), the argv as the entry resolves it, the executable from the login shell's `PATH`, its environment plus `FORCE_COLOR=1`, the entry's `env` and `PORT`, in `cwd` checked again just before.
- **Ports by dialing**: a port is taken when a connection to 127.0.0.1 or ::1 is; a reservation holds one until the server answers or ends. `autoPort` true or unset scans 20 past and rewrites `--port`/`-p` (and `PORT`); false fails, naming the holder (`internal/listeners`).
- **Ready** when a dial (100 ms backing off to 1 s) and an HTTP HEAD (2 s; any answer, or a TLS error) succeed, and the port's listener is in the server's process tree, else it fails "another program answers on port N" (skipped where listeners can't be read). Ending before that fails with its last lines; 180 s without an answer is running, "not answering".
- **Stop**: SIGTERM to the pty's foreground group, the terminal's hang-up, then what's left of the processes seen under it (pid and start time), a `setsid` child included. Each end records who (the user, Nushi) and the exit; an ended server keeps 200 lines / 32 KB, five a folder.
- **The folder owns it**: it stops once no unarchived chat has that folder (events followed as terminals follow them, moves too); a worktree with a server isn't removed by a move (`inUse`), and Delete or a worktree's removal stops its servers first.
- **A running server holds the idle restart**, as a terminal running a command does (ADR 0056), and the daemon's stop ends every one. Their processes are recorded (`servers.json`, `atomicfile`) so the next daemon stops a crash's leftovers; nothing is started again.
- **The app**: a Servers button left of the browser tab's ⋯, its menu Claude's (rows with the command, ▶, ■, a spinner, failures; Stop all servers; Add server, which puts a request to write `.agents/launch.json` in the box, unsent). The user started it, so its page opens beside the chat once it answers, ADR 0068's "the agent never moves the user" untouched.

## Consequences
- A server left on all day holds a daemon update until stopped, as a terminal's command does; Restart now is the way out.
- After a crash or a restart the user presses ▶ again.
- Agents can't list, start or check servers; they run their own through Bash.
- Later (docs/roadmap.md): the agent's `preview_*` tools and `show {url}`, a logs drawer, the phone, spotting servers an agent or a terminal started, the package.json scan with Use this, starting them again after a restart, the details panel's widget.

## Alternatives considered
- Servers in the app (Claude desktop's way): they'd die with the window, and the phone and a later agent tool would have no one to ask.
- Recording what ran and starting it again after a restart (the design's D7): an update would restart a server whose dependencies changed, unasked; holding the restart is what terminals do, and simpler.
- Through the user's shell (`sh -c`): one more layer of the repository's text to quote, and Claude desktop spawns directly.
- A listen probe for free ports: macOS lets Go's SO_REUSEADDR bind beside another listener (internal/listeners).
