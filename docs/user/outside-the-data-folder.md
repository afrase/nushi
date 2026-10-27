# What Nushi changes outside its data folder

Everything Nushi writes outside its data folder, and why.

## What Nushi changes outside its data folder (milestone Z)

Everything else Nushi writes is in its data folder (`~/Library/Application Support/Nushi`, or `NUSHI_DATA`): chats, settings (`app.json`), trust answers (`trusted.json`), remote keys, the log, scratch chats' folders, and the adapters (`agents/`). Outside it, each change is one you ask for, or the agent's own doing while you use it:

| What | Where | Why |
|---|---|---|
| The agent's history and state | Claude: `~/.claude` (projects, sessions, `~/.claude.json`); Codex: `$CODEX_HOME` (sessions, state, shell snapshots, its app-server); Ante: `~/.ante` (sessions, logs, its update check); omp: `~/.omp`; PiG: `~/.pig` (or `$PIG_HOME`), and a folder's `.pig/commands` renamed to `.pig/prompts` by PiG's own migration | Using the agent: it writes them as in a terminal. Nushi's own steps add to it the way the agent does: side chats, `/context` and rewinds are forks of the session (throwaway ones deleted after), a rename is the agent's, Delete takes a chat's history (Codex archives it). |
| A copy of a Claude transcript | `~/.claude/projects/<folder>/` | Move (you asked): the copy lets Claude fork the session in the new folder; removed after. |
| Claude's MCP servers | `~/.claude.json`, through `claude mcp add-json/remove/login/logout` | The MCP view's Add, Edit, Remove, Sign in and out. |
| A project's MCP switch | `<repo>/.claude/settings.local.json` (its two MCP lists), and that file into `.git/info/exclude` | The MCP view's on/off switch. |
| A user or local MCP server's switch | `~/.claude.json`'s `projects[<project>].disabledMcpServers`, written by Claude (a `claude -p --bare` run told to, ADR 0050) | The MCP view's or card's switch. |
| Skills' and plugins' switches | `skillOverrides` and `disableBundledSkills` in `~/.claude/settings.json` (through a link to it), `skillOverrides` and `enabledPlugins` in `<repo>/.claude/settings.local.json` (and that file into `.git/info/exclude`); your plugins through `claude plugin enable/disable/uninstall` | The Skills view's switches and Uninstall… (ADR 0051). |
| Other agents' skill switches | Codex: `[[skills.config]]` entries in `$CODEX_HOME/config.toml` (comments and order kept); PiG: the `skills` list of `<agent dir>/settings.json` or of the folder's `.pig/settings.json` (a file the repository may commit); Ante: `exclude_skills` in `$ANTE_HOME/settings.json`; omp: `disabledExtensions` in `~/.omp/agent/config.yml` | The Skills view's switches for that agent (ADR 0052). |
| A link giving Claude a shared skill | `<folder>/.claude/skills/<name>` → `../../.agents/skills/<name>` (yours: in your Claude skills folder) | Link for Claude… on a shared skill. |
| A deleted skill | its folder (or the link in its place), moved to the Trash; for a shared skill, the agents' links to it too | The Skills view's Delete… |
| A worktree | `<repo>/.worktrees/<name>`, its branch, `.git/info/exclude` | A chat in a new worktree; Delete removes them when asked. The branch is renamed (`git branch -m`) after the chat between turns, unless pushed, or by Rename branch…; the folder keeps its name. The agent is told with the next prompt, which its history keeps. |
| MCP servers started | whatever each server does | Opening the MCP view runs `claude mcp list`, which starts every server to check it, as in a terminal. |
| A shell | your shell's own files (history) | A terminal you open; the daemon's start (`nushid -login`, ADR 0036); reading its environment for agents, at start and from Settings › Agents (`-l -i -c`, ADR 0048): your config runs as in a terminal. |
| A login item | launchd's per-user list, Login Items | Start at login (Settings). |
| A Jira site's API token | the login keychain, service "Nushi Jira", account "<email> on <host>" | Settings › Jira (you added it); Remove deletes it. |
| Jira itself | the site | A move, a comment you make, or an agent's through its tools (its harness asks first). Nothing else: lists and issues are only read. |
| A GitHub token you paste | the login keychain, service "Nushi GitHub", account the host | Settings › GitHub (you added it); Remove deletes it. gh's own login is gh's: Nushi only reads it. |
| GitHub itself | the host | A reply, a resolve or unresolve, a comment, a review you send. Nothing else: the inbox, pull requests, issues, checks and files are only read. |
| A pull request's head in a repository | `refs/remotes/<remote>/<branch>` or `refs/nushi/pull/<n>`, and a worktree's branch on it | Start work on a pull request: `git fetch` from the folder's remote that is its repository. |
| A worktree named after an issue | `<repo>/.worktrees/<KEY>-<slug>`, branch `<KEY>-<slug>` | A chat started from an issue, when you pick a worktree. |
| Ante's prompt images | a private folder in `$TMPDIR` | An image in an Ante prompt; removed when the bridge ends. |
| A PiG session's file in the Trash | `~/.Trash` | Delete (you asked), and a side chat closed: moved there with `trash`, as PiG's `/resume` deletes. |
| The Mac kept awake | `caffeinate` (a process, no file) | Remote access on. |
| Files you open | macOS's open-panel state (`com.nushihq.Nushi` preferences) | The folder picker. |

What changed in milestone Z:
- **npx's cache** (`~/.npm/_npx/<hash>`, about 330 MB per adapter with its own Claude Code or Codex, 1.1 GB for omp with Bun): gone. Adapters are set up only when asked, into `agents/` (ADR 0037). Those left in your npx cache from before are yours to delete: `1f872328d1400346` (claude-agent-acp 0.94.0), `4a4ca55c38a52b9f` (codex-acp 2.2.2), `0bc28aba708345f9` (omp 18.12.6 and Bun 1.4.3), `72bcd8a8dc4e8361` (claude-agent-acp 0.91.0).
- **Finding agents** asks each CLI its version under macOS's sandbox (`sandbox-exec`) with file writes and the network denied: `codex --version` writes its PATH aliases (`$CODEX_HOME/tmp/arg0-macos/…`) otherwise.
- **Setting up** runs `npm ci` under the sandbox too, with writes allowed only in `agents/`; its cache is a folder of the install's own, removed after; no logs, no update check, no audit.
- Starting an agent changes nothing beyond the agent's own: Claude and Codex run your own CLIs, not copies; nothing is written to their configs (Codex's trust of a chat's folder is an override codex-acp passes, never written; ADR 0029).
