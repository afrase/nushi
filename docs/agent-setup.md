# Agents

Nushi runs five coding agents over the [Agent Client Protocol](https://agentclientprotocol.com): Claude, Codex, Ante, oh-my-pi and PiG. Each is your own CLI, with its own login, settings and history. Nushi never brings a copy of one ([ADR 0037](adr/0037-agents-you-set-up.md)).

## Finding them

Settings › Agents shows each agent as Nushi finds it on your login shell's `PATH`: its version and path, or "Not installed" with where to get it. Finding them changes nothing: each CLI is only asked its version, with writes and the network denied.

## Their environment

Agents start with your login shell's environment, as a new terminal has it, however the daemon was started ([ADR 0048](adr/0048-agents-start-with-the-login-shells-environment.md)).

- The daemon runs your shell (fish, zsh, bash…) as a login, interactive shell and reads what it exports, fish's universal variables included.
- It reads it again when you open Settings › Agents (if it's over a minute old) or press Reload there. A variable you add reaches the agents started after that, with no restart; a chat whose agent runs keeps what it started with.
- The last line of Settings › Agents says when it was read, or why it couldn't be ("Couldn't read your shell's environment: fish took over 5s"). Agents then get the last one read, else the daemon's.
- While it's read, `NUSHI_RESOLVING_ENVIRONMENT=1` is set, so your config can skip what only a terminal wants: `if not set -q NUSHI_RESOLVING_ENVIRONMENT; …`.
- Nushi never logs or writes down the values, and gives them only to the agents' processes.

## Each agent

### Claude

Nushi runs your `claude` through Claude Code's ACP adapter, `@agentclientprotocol/claude-agent-acp` 0.94.0. **Set up** installs it into `~/Library/Application Support/Nushi/agents/claude` (about 9 MB from npm, from the lockfile in `internal/claude/adapter`). It uses Claude Code's own login and settings.

Or turn on **Use Nushi's Go agent**, under Claude in Settings › Agents: Nushi then runs your `claude` through its own ACP agent, with no Node and nothing to set up ([ADR 0066](adr/0066-claude-through-nushis-go-agent.md)). New chats, and chats as they reopen or wake, use it; a chat already running keeps its agent until then. It's off by default while it's new.

- **Code review.** Claude's `/code-review` reports its findings as a card in the transcript (Nushi sets `CLAUDE_CODE_REPORT_FINDINGS` for Claude Code). A review that writes them as JSON gets the same card, with Show JSON. A row opens to how the finding fails; its `file:line` opens the chat's Changes at that line, or the file as it is when it isn't changed.
- **Ultracode**, in the ⋯ menu under the box, turns on Claude Code's standing multi-agent workflows for the chat. It's off by default; "Ultracode" shows beside the model while it's on. Changing it reopens the chat's session (a second or so), so it waits for a turn to end. The word "ultracode" in a message opts just that turn in, as in the terminal.

### Codex

Nushi runs your `codex` through `@agentclientprotocol/codex-acp` 2.2.2, set up the same way (about 2 MB).

- It uses Codex's own login or config (`$CODEX_HOME`, else `~/.codex`): sign in with `codex login`, or name a provider in `config.toml`. [Codex config](user/codex-config.md) has one for Fireworks.
- A provider's key comes from the environment, which agents get from your login shell (above).
- A Codex chat resumes in a terminal with `codex resume <session id>`.

### Ante

Through Nushi's own bridge, `nushid ante-acp`, which runs an `ante serve --stdio` per session ([ADR 0030](adr/0030-our-own-bridge-for-ante.md)). Nothing to set up.

- It needs Ante 0.2.14 or newer: the `ante` on `PATH`, else `~/.ante/bin/ante`. The bridge follows 0.2.14; 0.2.15 changed nothing in the protocol, per its notes.
- It uses Ante's own settings, providers and sign-in (`~/.ante`, or `$ANTE_HOME`), so your default model until you pick another in the chat. A provider's key, such as `FIREWORKS_API_KEY`, comes from the environment.
- An Ante chat resumes in a terminal with `ante --resume <session id>`.

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

Claude and Codex need an adapter; Settings › Agents' **Set up** installs it.

- It needs Node and npm on the login shell's `PATH`; Nushi doesn't install them.
- It runs `npm ci` from Nushi's lockfile: every package's version and hash pinned, no install scripts, and no optional packages (such as the adapters' own Claude Code or Codex). npm's cache goes in the folder and is removed after.
- **Update** installs a newer adapter when Nushi pins one. **Remove** deletes it.
- `make adapters` writes the lockfiles again after a version changes ([Development](development.md)).

What each agent can do (fork, rewind, steering, questions, the context breakdown, MCP) follows what it reports. A control it lacks isn't shown.

## Sessions started elsewhere

New chat also opens a session started elsewhere, such as `claude` or `codex` in a terminal ([ADR 0035](adr/0035-open-sessions-started-elsewhere.md)).

- Press → (or "Sessions →" on the highlighted agent's row) to list the agent's sessions in the folder; from No folder, every folder's. Enter opens one as a chat.
- The agent replays it, and Nushi keeps its own copy of what shows from then on, as for every chat. It goes on in the same history the terminal resumes.
- A session still open elsewhere is marked. Claude and Ante let both write (Nushi asks first); Codex and oh-my-pi only one. PiG leaves no mark, and both write.
