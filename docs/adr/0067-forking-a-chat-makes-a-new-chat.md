# 0067. Forking a chat makes a new chat on a fork of its session

## Context
A side chat is a fork that ends when closed; rewind ([0020](0020-rewind-through-a-vendor-fork.md)) and move ([0014](0014-moving-a-chat-forks-it.md)) fork the session but replace the chat's. The owner wants a lasting fork: a new chat in the sidebar that starts from this one's conversation (all of it, or up to one of the agent's messages) and goes on separately, and a way to keep a side chat the same way.

## Decision
- **Fork chat** and **Fork from here** (`ForkAsChat`, API 94) make a new chat: same agent, same folder (and the same worktree record, shared: Delete already refuses to remove a worktree another chat works in, and now keeps a scratch folder another chat works in), the chat's picks, mode and Ultracode, its Jira issue and GitHub item. Its own agent process forks the session (`session/fork`, with `Dialect.ForkAt`'s meta for an agent message, as rewind does); the original's agent and session are left alone, so forking works while a turn runs.
- While a turn runs, the fork has what has finished: it is cut before the running turn's message, at the agent's message before it when the agent forks at messages (so the fork's session and transcript agree), else the agent's whole session is forked and its next reopen's merge shows what more it had.
- The new chat's transcript and Nushi's copy ([0047](0047-nushis-copy-of-transcripts.md)) are the original's items up to the fork point, with what was under way ended: tool rows, permissions and questions show as in the original.
- Its title is the original's marked " (fork)" (the user's name too, if it has one). Claude titles a fork "<title> (fork)" itself: equal to ours, or recognised by `ForkTitle` and ignored; its later titles win as for any chat. A shared worktree's branch is never renamed after a fork.
- **Keep as chat** (`KeepSideChat`, API 94) makes a side chat a chat with a new id, on the side chat's session (closed on the chat's agent, kept off its throwaway list); its transcript is the chat's as it was when the side chat opened plus the side chat's own, written to its copy. It reopens on its own agent when next shown (`session/load`), so an agent that can't reopen sessions can't keep one. A side chat is kept only between turns.
- Agents that can't fork don't get the actions (`can_fork`); Fork from here shows only on messages the daemon marks `Item.forkable`, while `can_rewind`.

## Consequences
- A fork shares files with its original (same folder): their changes mix, as two chats in one folder always did. A worktree of its own is a Move away.
- An agent's fork of a whole session mid-turn may hold more than the transcript shows until it reopens.

## Alternatives considered
- Forking on the original chat's agent process and handing the session over: needs a close and a load anyway, and ties the fork to the original's process.
- A new worktree for every fork: the owner asked for the same folder; Move does the rest.
