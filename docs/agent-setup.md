# Agents

Nushi runs seven coding agents over the [Agent Client Protocol](https://agentclientprotocol.com): Claude, Codex, Ante, oh-my-pi, OpenCode, Pi and PiG. Each is your own CLI, with its own login, settings and history. Nushi never brings a copy of one ([ADR 0037](adr/0037-agents-you-set-up.md)).

## Finding them

Settings › Agents shows each agent as Nushi finds it on your login shell's `PATH`: its version and path, or "Not installed" with where to get it. Finding them asks each CLI its version (and Claude whether it's signed in), run as you with nothing denied, as a chat runs it, for 10 s at most ([ADR 0037](adr/0037-agents-you-set-up.md)'s note of 2026-11-08). Nushi changes nothing itself; a CLI may write what it writes whenever it starts.

## Their environment

Agents start with your login shell's environment, as a new terminal has it, however the daemon was started ([ADR 0048](adr/0048-agents-start-with-the-login-shells-environment.md)).

- The daemon runs your shell (fish, zsh, bash…) as a login, interactive shell and reads what it exports, fish's universal variables included.
- It reads it again when you open Settings › Agents (if it's over a minute old) or press Reload there. A variable you add reaches the agents started after that, with no restart; a chat whose agent runs keeps what it started with.
- The last line of Settings › Agents says when it was read, or why it couldn't be ("Couldn't read your shell's environment: fish took over 5s"). Agents then get the last one read, else the daemon's.
- While it's read, `NUSHI_RESOLVING_ENVIRONMENT=1` is set, so your config can skip what only a terminal wants: `if not set -q NUSHI_RESOLVING_ENVIRONMENT; …`.
- Nushi never logs or writes down the values, and gives them only to the agents' processes.

## Each agent

### Claude

Nushi runs your `claude` through its own ACP agent, `nushid claude-acp` ([ADR 0066](adr/0066-claude-through-nushis-go-agent.md)): no Node and nothing to set up once `claude` is on your login shell's `PATH`. It uses Claude Code's own login and settings. Until 2026-11-04 Claude ran through the Node adapter, claude-agent-acp; chats from then reopen and resume as they were, and the adapter Set up installed is removed.

- **Code review.** Claude's `/code-review` reports its findings as a card in the transcript (Nushi sets `CLAUDE_CODE_REPORT_FINDINGS` for Claude Code). A review that writes them as JSON gets the same card, with Show JSON. A row opens to how the finding fails; its `file:line` opens the chat's Changes at that line, or the file as it is when it isn't changed.
- **Ultracode**, in the ⋯ menu under the box, turns on Claude Code's standing multi-agent workflows for the chat. It's off by default; "Ultracode" shows beside the model while it's on. Changing it reopens the chat's session (a second or so), so it waits for a turn to end. The word "ultracode" in a message opts just that turn in, as in the terminal.

### Codex

Nushi runs your `codex` through `@agentclientprotocol/codex-acp` 2.2.2, set up the same way (about 2 MB).

- It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml`. [Codex config](user/codex-config.md) has one for Fireworks.
- A provider's key comes from the environment, which agents get from your login shell (above).
- A Codex chat resumes in a terminal with `codex resume <session id>`.

### Ante

Through Nushi's own bridge, `nushid ante-acp`, which runs an `ante serve --stdio` per session ([ADR 0030](adr/0030-our-own-bridge-for-ante.md)). Nothing to set up.

- It needs Ante 0.2.14 or newer: the `ante` on `PATH`, else `~/.ante/bin/ante`. The bridge follows 0.2.14 and was run on 0.3.2 too; the protocol's events didn't change between them.
- It uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`), so your default model until you pick another in the chat. A provider's key, such as `FIREWORKS_API_KEY`, comes from the environment.
- An Ante chat resumes in a terminal with `ante --resume <session id>`.
- Ante leaves out a prompt's images when they don't fit what's left of the chat's context, and says nothing. So the bridge scales a big image down first (usually a JPEG of 1568 px at most), smaller as the chat fills. When even that won't fit, a note in the chat says so; `/compact` or a new chat makes room.

### oh-my-pi

Nushi runs your `omp --mode acp` under your Bun. Nothing to set up once you've installed both:

```sh
brew install oven-sh/bun/bun        # or: npm i -g bun
bun add -g @oh-my-pi/pi-coding-agent@18.12.6
```

18.12.6 is the version Nushi was tried with. `~/.bun/bin` must be on your login shell's `PATH`; Settings › Agents then shows omp.

- It uses omp's own config and keys: `~/.omp`, and the environment (`FIREWORKS_API_KEY` for Fireworks, whose models it then lists).
- To pick the model it starts on, set `modelRoles` in `~/.omp/agent/config.yml`:

  ```yaml
  modelRoles:
    default: fireworks/deepseek-v4.1-flash
  ```

- An omp chat resumes in a terminal with `omp --resume <session id>`. Nushi can't delete an omp session's history.

### OpenCode

Nushi runs your `opencode acp`. Nothing to set up once `opencode` is on your login shell's `PATH`:

```sh
brew install anomalyco/tap/opencode-v2     # or: curl -fsSL https://opencode.ai/v2/install | bash
```

opencode's README also names Homebrew's own `opencode` formula (the one Nushi was built against) and npm's `@opencode/cli`. Nushi follows opencode 2.2.6 and needs 2.0.0 or newer: opencode 1 (npm's `opencode-ai`) isn't supported, and Settings › Agents says "Needs 2.0.0 or newer" for it.

- It uses opencode's own config, providers and sign-in (`~/.config/opencode`, `~/.local/share/opencode`): sign in with `opencode auth login` in a terminal. Settings › Agents doesn't say whether you're signed in: opencode starts either way, with free models of its own.
- Model, effort and mode are opencode's. So are its permission prompts (`permissions` in its config): as installed it asks almost nothing, and its `plan` mode still runs shell commands.
- opencode loads a folder's config, plugins and MCP servers without asking, the folder's own and those of every folder above it. Nushi's trust card lists them before a chat starts there ([ADR 0031](adr/0031-warn-before-a-folder-runs-code-for-ante-and-omp.md)).
- **Only `/compact` is offered.** opencode 2.2.6 answers its other commands (`/init`, `/review`, `/goal`, your own) at once over ACP and then runs them where Nushi can't see, so the menu leaves them out. One typed by hand still goes out, and the next message waits behind it.
- A subagent shows as one tool call with its result, not its steps.
- Background commands aren't listed, and they end when the chat goes to sleep ([ADR 0032](adr/0032-idle-chats-sleep.md)) or its agent stops.
- An opencode chat gets none of Nushi's tools (`show`, the previews, Jira's): [MCP servers and skills](mcp-and-skills.md).
- An opencode chat resumes in a terminal with `opencode --session <session id>`. Delete deletes its session, as opencode does. New chat's Sessions list also holds its subagents' sessions, which opencode doesn't mark.

### Pi

[Pi](https://pi.dev) runs through the same bridge as PiG, `nushid pi-acp`, which runs your `pi --mode rpc` per session ([ADR 0078](adr/0078-pi-and-pig-share-a-bridge.md)). It needs Node 22.19 or newer.

```bash
curl -fsSL https://pi.dev/install.sh | sh     # or: npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

Nushi follows Pi 1.4.0 and needs 0.80.4 or newer; Settings › Agents then says Ready.

- It uses Pi's own settings, providers and keys in `~/.pi/agent` (or `$PI_CODING_AGENT_DIR`).
- **Pi has no permission prompts**: its tools run without asking.
- A folder's `.pi` settings, extensions and MCP servers load only once you've trusted the folder in Pi (`/trust` in a terminal `pi`).
- A Pi chat resumes in a terminal with `pi --session <session id>`. Delete moves its session file to the Trash, as Pi does.

### PiG

[PiG](https://pi-in-go.dev) runs through Nushi's own bridge, `nushid pig-acp`, which runs your `pig --mode rpc` per session ([ADR 0039](adr/0039-our-own-bridge-for-pig.md)). Nothing to set up once `pig` is on your login shell's `PATH`:

```sh
curl -fsSL https://pi-in-go.dev/install.sh | sh     # or: npm i -g @pi-in-go/pig
```

Nushi follows PiG 0.5.3; Settings › Agents then says Ready.

- It uses PiG's own settings, providers and keys: `~/.pig` (or `$PIG_HOME`), and the environment (`FIREWORKS_API_KEY` for Fireworks).
- To pick what new chats start on, set it in `~/.pig/agent/settings.json`:

  ```json
  { "defaultProvider": "fireworks", "defaultModel": "accounts/fireworks/models/deepseek-v4p1-flash", "defaultThinkingLevel": "low" }
  ```

- **PiG has no permission prompts**: its tools run without asking.
- A folder's `.pig` settings, extensions and MCP servers load only once you've trusted the folder in PiG (`/trust` in a terminal `pig`).
- A PiG chat resumes in a terminal with `pig --session <session id>`. Delete moves its session file to the Trash, as PiG does.

## Setting up adapters

Codex needs an adapter; Settings › Agents' **Set up** installs it.

- It needs Node and npm on the login shell's `PATH`; Nushi doesn't install them.
- It runs `npm ci` from Nushi's lockfile: every package's version and hash pinned, no install scripts, and no optional packages (such as the adapters' own Claude Code or Codex). npm's cache goes in the folder and is removed after.
- **Update** installs a newer adapter when Nushi pins one. **Remove** deletes it.
- `make adapters` writes the lockfiles again after a version changes ([Development](development.md)).

What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports. A control it lacks isn't shown.

## Sessions started elsewhere

New chat also opens a session started elsewhere, such as `claude` or `codex` in a terminal ([ADR 0035](adr/0035-open-sessions-started-elsewhere.md)).

- Press → (or "Sessions →" on the highlighted agent's row) to list the agent's sessions in the folder; from No folder, every folder's. Enter opens one as a chat.
- The agent replays it, and Nushi keeps its own copy of what shows from then on, as for every chat. It goes on in the same history the terminal resumes.
- A session still open elsewhere is marked. Claude and Ante let both write (Nushi asks first); Codex and oh-my-pi only one. Pi and PiG leave no mark, and both write. OpenCode leaves none either: it locks nothing.
