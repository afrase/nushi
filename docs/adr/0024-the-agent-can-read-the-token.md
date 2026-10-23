# 0024. The agent can read Nushi's token, and that stays (amends 0005)

## Context
[0005](0005-clients-authenticate.md) puts same-user processes outside the threat model. The agent is one of them, and the one process Nushi mediates: with the token from `~/Library/Application Support/Nushi/token` it could answer its own permission prompts (`AnswerPermission`) or open a terminal. The review (S5) asked for a way the app gets the token that the agent can't simply read from disk.

## Decision
Keep the token file. None of the ways looked at holds against a process running as the user, and each costs more than it gives:
- Keychain with an access list naming the app: Nushi is signed ad hoc, so every build has a new code identity and the list stops matching after each `make install` (a prompt each time, or a list that names nothing). `security find-generic-password` from the agent gets the system's own "allow?" prompt, which teaches clicking Allow.
- A handoff when the app starts the daemon: the daemon outlives the app, and a reopened app connects to a daemon it didn't start, so it needs a lasting secret anyway.
- Checking the peer process on the socket (`LOCAL_PEERPID`, then its path or signature): the agent can start the app's own binary, or rewrite `~/Applications/Nushi.app`, which it can write; and development runs (`flutter run`, the tests) would need exceptions.
The boundary that does hold is the agent's own: its permission mode, and Claude's sandbox and deny rules. In Manual mode, reading the token is a command or file read Claude asks about.

## Consequences
- An agent allowed to run commands freely (Auto, Bypass permissions, or a broad allow rule) can act as the app. Users who want that closed can deny it in Claude's own settings, for example `Read(~/Library/Application Support/Nushi/**)` and the matching Bash rules, or turn on Claude's sandbox; Nushi doesn't write Claude's settings.
- The daemon replaces an empty or short token file and keeps it at mode 0600.
- Remote access ([0006](0006-remote-through-relay.md)) still needs its own per-device tokens; this file token stays local.
