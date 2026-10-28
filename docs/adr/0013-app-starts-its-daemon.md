# 0013. The packaged app starts its own daemon, never stops one on its own

Amended by [0036](0036-the-daemon-is-a-background-helper-app.md): the daemon is a helper app the app opens through Launch Services (`nushid -login` goes through the login shell), and Start at login is a launch agent. The rest holds. Amended by [0056](0056-the-daemon-restarts-itself-when-idle.md): the app asks an older daemon to restart itself once nothing runs, and starts the bundled one when it has.

## Context
The packaged app (`make package`) carries `nushid` inside its bundle. Agents must outlive the app ([0002](0002-separate-daemon.md)), and a daemon may be older than the app that finds it ([0004](0004-connect-over-unix-socket.md)). An app opened from Finder gets launchd's bare environment, while agents need the user's `PATH` (Node, the agents' CLIs, and every tool an agent runs).

## Decision
- When no daemon answers, the app starts its bundled `nushid`, detached, through the user's login shell (`$SHELL -l -c 'exec …'`), so the daemon and its agents get the same environment as a terminal. Its log goes to `nushid.log` in the data folder.
- The app never stops or restarts a running daemon by itself. When the daemon's API version is lower than the app's, the app shows only a "Restart daemon" screen (ADR 0004); only that button stops it (SIGTERM, which stops its agents) and starts the bundled one. Chats reopen through `session/load`.
- No launchd agent: the daemon runs from the moment the app first needs it until it is stopped or the Mac restarts.

## Consequences
- After a reboot, nothing runs until the app is opened.
- A shell profile that prints or fails slows or breaks the start; `nushid.log` is where to look.
- An older daemon rewriting a session file drops fields it doesn't know (a renamed or archived chat could lose that).

## Alternatives considered
- A launchd agent (`SMAppService`): starts at login and restarts on crash, but needs a signed helper and more setup than an ad-hoc signed app for one user.
- Reading the login shell's environment in the app and passing it on: more code for the same result.
