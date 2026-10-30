# 0027. What lives only in memory

## Context
Nushi keeps little on disk: a JSON file per chat (ADR 0010), each agent's remembered mode and picks, the trusted folders, and the app's settings. The agent keeps the conversation (ADR 0008).

## Decision
- The daemon keeps in memory only: each chat's transcript (rebuilt from the agent with `session/load` after a restart), its queue of messages, its usage and cost, side chats, terminals, and whether the agent can delete its history (learned by starting it once per run).
- The app keeps in memory only: what is written in each chat's box (its draft, side question included), the last context breakdown per chat, and checked MCP states per folder. It keeps on disk, in the data folder, `app.json` (panel, cards, panes, scopes, worktree choices, open terminal panels) and `reviews.json` (review comments, the app's drafts).
- After a daemon restart chats reopen only when opened or prompted (each is an agent process); an archived chat shows no history until unarchived.
- One exception, so a crash leaves no copy of a conversation behind: the ids of sessions forked from a chat that nobody will see again (side chats, a `/context` run whose delete failed) are kept in the chat's file until the agent has deleted them; a fresh agent deletes them the next time the chat opens, or Delete does. Side chats themselves still end with the daemon, and when no app has followed the daemon for two minutes.

## Consequences
- A daemon restart loses queues, usage, running turns and pending prompts, side chats and terminals; quitting the app loses drafts.
- Storing any of these needs a reason and a new place on disk.

## Amendment (2026-10-26)
Each chat's transcript is also copied to disk as it settles, in the data folder, unless turned off ([ADR 0047](0047-nushis-copy-of-transcripts.md)): after a restart a chat shows its copy until the agent has replayed it, and an archived chat shows it too.

## Amendment (2026-10-29)
The app also keeps on disk, in the data folder, `context.json` (each chat's last context breakdown, categories only) and `pulls/` (the pull requests read last), beside `app.json`, `reviews.json` and `drafts.json` (ADR 0062): each written whole, 0600.

## Amendment (2026-10-30)
The app also keeps in memory only what's written in a GitHub or Jira comment box and not posted (a thread's reply, a pull request's or issue's comment, an inline comment being written, a review's text), by what it answers (host, repository, number, and the thread or `comment`, `review`), with each pull request's tab and Files' file and lines as left: a look at a chat comes back to them. Posting, emptying the box or a reply's Cancel clears it; quitting loses it, as ADR 0062 leaves such boxes off disk.
