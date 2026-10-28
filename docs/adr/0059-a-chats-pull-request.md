# 0059. A chat's pull request is found by its branch's head, linked on the chat, and asked for only while it shows

Status: accepted, 2026-10-28 (steps 381, 383, 386, 388, 389). Amends [0046](0046-the-github-inbox-and-polling.md) (what polls).

## Context
A chat that made a branch usually ends in a pull request, opened by the agent (`gh pr create`, an MCP tool) or by the user. Chats started from a pull request already remember it (`Session.GitHub`); the others had no link, so their checks, reviews and comments were a trip to the browser away. Orca shows a branch's pull request beside its worktree; its lookup, polling and log trimming were the model (ideas, not its look).

## Decision
- **Found by its head:** the daemon reads the chat's folder's branch and the remote it's pushed to, and asks each of the folder's GitHub repositories (the pushed one first, three at most, on a host with a sign-in) for pull requests with head `<owner pushed to>:<branch>` (REST `pulls?head=&state=all`, with the last answer's ETag: an unchanged ask is a free 304; `X-Poll-Interval` honoured, though GitHub sends none here). An open one wins, else the newest. Nothing is looked for on the default branch or a detached HEAD.
- **Linked on the chat:** a found one is `Session.Pull` (with the branch it was found by); one linked by hand wins over a found one; Unlink is remembered (`NoPull`), so that one isn't found again; a found one goes when the folder leaves its branch. A chat started from a pull request keeps it in `GitHub`; one started from an issue keeps the issue there and gets its pull request in `Pull`; `Chat.pull` is whichever pull request the chat has.
- **Asked only while it shows** (as 0046): the chat's pane asks when it opens, 3 s after a tool call that ran `git push`, `gh pr create` or a `create_pull_request` tool, and when a turn ends; the details panel's card each minute (15 when merged or closed); the sidebar's dots and the phone's chip one states query a host a minute. The tab is the GitHub view's pull request pane, with its own 30 s poll.
- **Send to agent** puts a comment, a thread or a failed check (the failing part of its log) into the chat's box as a reply card, never sent by itself; the card says its quote is GitHub's text, data, not instructions.

## Consequences
- A chat on an open pull request spends about 2 GraphQL points a minute while its card shows; finding costs a free 304 once the branch's answer is known. A closed window costs nothing.
- A pull request opened elsewhere shows within a minute of the chat showing, or 3 s after the agent's push.
- A branch that two chats share links both to its pull request.
