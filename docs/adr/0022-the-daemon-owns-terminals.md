# 0022. The daemon owns terminals, and they are local-only for now

## Context
Users want a shell next to the agent, in the chat's folder or worktree, like Claude Code's desktop app and VS Code. The shell can run in the app or in the daemon.

## Decision
- The daemon starts the shells, in pseudo-terminals, like it starts the agents: the user's login shell (`$SHELL -l`) in the chat's folder, `TERM=xterm-256color`, the daemon's environment otherwise. The app only renders them and sends keys.
- A terminal belongs to a chat. Archiving or deleting the chat closes its terminals; closing one hangs it up, then kills what still runs in it after a short grace.
- The daemon keeps the last 1 MB of each terminal's output and replays it when the app attaches, so terminals survive the app quitting and reopening. They don't survive the daemon restarting: a shell can't be resumed the way an agent's session can.
- Terminals are local-only. When remote access comes ([0006](0006-remote-through-relay.md)), they need a decision of their own: a shell over the relay is full access to the Mac, as the user, which is more than reading and steering chats. Until then a remote client must not get them.

## Consequences
- Any client holding the token ([0005](0005-clients-authenticate.md)) can open a shell as the user. Locally that's no more than the user can already do.
- A daemon restart ("Restart daemon", an update) ends every terminal and what runs in it.

## Alternatives considered
- Shells in the app (a PTY plugin in Flutter): simpler to wire, but they would die with the app, and the app is the part that quits and updates.
