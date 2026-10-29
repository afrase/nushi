# 0063. Clean up after a pull request: each part asked for, guarded twice, the GitHub branch only at the pull request's head

Status: accepted, 2026-10-29 (the PR redesign's clean-up). Amends [0016](0016-a-worktree-per-chat.md) (a found worktree may go, when asked) and [0059](0059-a-chats-pull-request.md).

## Context
A chat's pull request merges (or closes) and leaves its worktree, its local branch, the branch on GitHub and the chat itself behind. Removing them by hand is four places; doing it for the user risks losing what isn't anywhere else: uncommitted files, commits a squash merge didn't keep, a branch someone pushed to after the merge, another chat's folder.

## Decision
- **Asked, part by part:** the PR widget offers Clean up… once its pull request merged (quietly once it closed; the chat's ⋯ has it for any worktree chat). A dialog names each part with what it costs: the worktree (a dirty one starts unticked; ticking it names the files lost and turns the button red), the local branch (not while its worktree stays or another worktree has it; with commits its base lacks only after a merge GitHub reports, else it's a loss named on the button), the branch on GitHub (ticked after a merge, not after a close), archiving the chat. Nothing goes that the dialog didn't name.
- **Guarded again in the daemon:** `RemoveChatWorktree` refuses mid-turn, while another chat (not archived) works in the worktree, and with uncommitted changes unless forced; the chat's agent stops (sleeps) and its terminals end first. `DeleteChatBranch` refuses while any worktree has the branch and with commits its base lacks unless forced. `DeleteGitHubBranch` deletes only a merged or closed pull request's head branch, on its head repository, only while it points at the pull request's head (a branch that moved on stays), never the repository's default branch; one already gone is no error.
- **Mid-turn** the clean-up waits for the turn to end (or stops it, when picked), then runs: the GitHub branch, archive, worktree, local branch; each part's failure is shown and the rest go on.
- **Undo where it can be:** the branch on GitHub is made again at the pull request's head (`RestoreGitHubBranch`), the chat unarchived. A removed worktree and a deleted local branch can't come back from Nushi (the dialog said so).

## Consequences
- Found worktrees (0016: never removed by Nushi on its own) may now go, but only ticked by hand, "Made outside Nushi" said in the dialog.
- The GitHub writes are the user's token's: a fork's branch goes only where the user can push; a protected branch's refusal is GitHub's message.
