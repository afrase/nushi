# 0016. A chat can have a git worktree of its own

## Context
Several agents working in one repository step on each other's files. Git worktrees give each chat its own checkout and branch.

## Decision
- A worktree is an option when a chat starts in (or moves into) a git repository, off by default and remembered per repository by the app; never forced.
- Nushi makes it at `<repo>/.worktrees/<name>`, on a new branch `nushi/<name>` from the folder's current `HEAD`, and records the branch it started from (the base). `<name>` is two random words, unique in the repository. `.worktrees/` goes into the repository's `.git/info/exclude`, never into a tracked `.gitignore`.
- The chat runs in the worktree and is listed under its repository.
- A chat started from a Jira issue (ADR 0042) gets a worktree when the issue is picked (the user can turn it off), on a branch named after the issue: `<KEY>-<summary-slug>`, the key uppercase so Jira links the branch, which the user can change to any name git takes; the worktree's folder is the branch with `-` for `/`, and a number goes after both when the name is taken.
- Nushi never deletes a branch or a worktree with work in it without saying so first. Archiving leaves both alone. Delete… offers removing the worktree and deleting the branch, each on by default only when nothing would be lost (no uncommitted or untracked changes; no commits the base lacks); otherwise off, saying what would be lost, and forced (`git worktree remove --force`, `git branch -D` past unmerged commits) only when the user ticks it. A worktree a chat without messages leaves is removed only when nothing would be lost.

## Consequences
- Worktrees live inside the repository's folder, so tools that walk the folder without git's ignores (editors, `grep -r`) see them.
- Claude keeps each worktree's sessions under its own history folder, as for any folder.

## Alternatives considered
- Worktrees outside the repository (`~/.nushi/worktrees/...`, as some tools do): harder to find and to clean up by hand.

## Amendment (steps 315–317): a plain chat's branch is named after the chat
- Nushi's two words (`nushi/brave-otter`) are a placeholder: once the chat has a title between turns (the user's name for it, else the agent's, else the first prompt's line; Claude's own title is waited for, a turn at most, since it can come just after a short first turn), the branch becomes `nushi/<title-slug>`, the slug as a Jira issue's (ASCII letters and digits, lowercase, `-` between words, 40 characters at most, cut between words), a number after it when a branch or a remote's branch has the name. A title with none of those words leaves the two words until one has. Once only.
- Only while the branch still has Nushi's name and the worktree is on it, it tracks nothing and no remote has a branch of its name, and no other worktree or chat has it; otherwise it keeps its name for good. Never during a turn (or while background subagents run): the title often comes mid-turn, and the rename waits for the turn's end.
- `git branch -m`; the worktree's folder keeps its name (the agent's session and terminals have it as their cwd), so the folder and branch differ from then on.
- The transcript gets a quiet line ("Branch renamed to nushi/…"); the agent isn't told. Claude's prompt keeps the old name from the session's start, so it may run one command with it first, which fails (`docs/facts/claude.md`).
- Rename branch… in the Environment card renames it to any name git takes, between turns, and turns the naming off. A branch on a remote (an upstream, or a remote's branch of its name) is refused, "It's on the remote: rename it there too, or keep it", rather than renamed here alone, which would leave the local and the remote names apart (a plain `git push` then refuses, or pushes another branch).
