# 0028. Agents get the login shell's environment, through the daemon's

## Context
Codex reads its provider's key from the environment (`env_key = "FIREWORKS_API_KEY"` in its `config.toml`), the way a terminal has it from the shell's config. An app opened from Finder gets launchd's bare environment (checked on macOS 27: `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `SHELL` from the user database, no shell variables). The bundled daemon starts through the login shell, `<shell> -l -c 'exec …'` ([0013](0013-app-starts-its-daemon.md); since [0036](0036-the-daemon-is-a-background-helper-app.md) `nushid -login` runs it, whether the app or Start at login opened the helper); the daemon starts agents and terminals with its own environment.

## Decision
- An agent gets the daemon's environment as it is: launched by the app, the login shell's (checked: a variable set in fish's config reaches a daemon started from Finder). Nushi doesn't read, filter, add to or log it.
- The daemon doesn't read the login shell's environment a second time ("the step 70 lookup"): the launch already gives it.

## Consequences
- Every variable the shell's config exports, secrets included, reaches every agent and every terminal, as in a terminal.
- A change to the shell's config reaches agents only once the daemon restarts.
- A daemon started some other way has that way's environment: `make run` a terminal's, a shell the launcher doesn't know (not sh, zsh, bash, fish, dash or ksh) zsh's login environment.

## Alternatives considered
- The daemon running `<login shell> -l -c env` once and giving agents that: the same environment for the app's launch, more code, and a second copy of what the shell's config prints or breaks.
- Passing agents only a list of variables Nushi names: a per-agent table, and Nushi would be choosing which secrets an agent gets.
