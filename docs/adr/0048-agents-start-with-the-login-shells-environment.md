# 0048. Agents start with the login shell's environment, which the daemon reads itself

Supersedes [0028](0028-agents-get-the-login-shells-environment.md).

## Context
0028 gave agents the daemon's own environment, trusting the launch to have made it the login shell's (`nushid -login`, [0036](0036-the-daemon-is-a-background-helper-app.md)). A daemon started any other way had that way's: one opened without `-login` (a restart by hand, which `open` gives the opener's environment) had the opener's, and an agent chat failed with "No API key for FIREWORKS_API_KEY", a fish universal variable (`set -Ux`) only fish has. A variable added to the shell's config also reached agents only after a daemon restart.

## Decision
- **Read, not inherited.** The daemon runs the login shell (the user database's, as terminals do; one it doesn't know: zsh, as the launcher) once at start, as a login, interactive shell (`-l -i -c`), stdin `/dev/null`, a session of its own, `NUSHI_RESOLVING_ENVIRONMENT=1` set so a config can skip what only a terminal wants. The line, the same in fish, zsh, bash, sh, dash and ksh, prints a random start mark, `/usr/bin/env -0`, and an end mark; what's between the last start mark and the end mark is the environment, so whatever a config prints first is skipped. 5 s at most, then the shell and what it started are killed.
- **Every agent** (Claude's and Codex's adapters, Ante's and PiG's bridges, omp) starts with that environment over the daemon's (the shell's wins), without Nushi's own variables (`NUSHI_*`, `NUSHID_*`) and those a shell sets for itself (`PWD`, `OLDPWD`, `SHLVL`, `_`), with the agent's own overrides on top (`CLAUDE_CODE_EXECUTABLE`, `CODEX_PATH`; what goes through `_meta` is unchanged). Finding agents (`PATH`, `--version` under the sandbox) and `npm ci` use it too. Terminals don't: they start a login shell already. The daemon's own process keeps the environment it started with.
- **Failure** is logged (the shell, how long, how it ended; never what it printed) and said in Settings › Agents ("Couldn't read your shell's environment: fish took over 5s"); agents then get the last reading that worked, else the daemon's own.
- **Fresh enough.** Opening Settings › Agents reads it again when the last reading is over a minute old; Reload there reads it now. A running agent keeps the environment it started with; a chat's next start (a wake, a reload) gets the new one.
- **Secrets.** The values live only in the daemon's memory and the agents' processes: never logged (the variables' names the shell adds, at DEBUG only), written, or sent to the app or a phone (the API says only the shell, when, and why it failed). Nushi's own secrets (the Jira and GitHub tokens, a chat's tools key) were never in its environment and still aren't in an agent's.

## Consequences
- An agent sees what a new terminal sees, however the daemon started; a changed shell config reaches the next agent started after Settings › Agents was opened.
- Each start and refresh costs one shell start (fish with the owner's config: about 0.4 s); the first chat or agent list after the daemon starts waits for it.
- An interactive config that waits for input gets EOF; one that never ends costs 5 s and the warning. A config that prints a secret prints it into a pipe that's dropped.
- The daemon's own reads of agents' folders (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `ANTE_HOME` for history and trust) still use its own environment: a daemon started without `-login` and a shell that sets those disagree with the agents.

## Alternatives considered
- Keep 0028 and make every start go through `-login`: holds only for the starts Nushi makes, and a config change still needs a restart.
- Read fish's universal variables (or any one shell's files) directly: one shell's format, and misses what configs compute.
- A non-interactive shell (`-l -c`): faster, but misses what configs set only when interactive (zsh's `.zshrc`, fish's `status is-interactive` blocks), where people put their keys.
