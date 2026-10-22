# 0001. Nushi is a chat wrangler and a very good diff viewer

## Context
The first build (the POC) grew task workspaces, review loops, Jira and GitHub UIs, settings layers and a 43-ADR process before it was a good daily chat. It worked, but was hard to change. The user's north star: "a chat wrangler and a very very good diff viewer."

## Decision
Nushi is a macOS desktop app for running coding agents as chats, plus a diff viewer. It is rebuilt from scratch, small: a Go daemon and a Flutter app. It stays unopinionated: options and warnings rather than enforced flows. Worktrees per chat, more agents, review comments, Jira and GitHub are decided one at a time after the first diff viewer.

## Consequences
- Anything outside chats and diffs needs a real need, recorded in an ADR, before it is built.
- The product's unit is the chat (an agent session), never a "task".
