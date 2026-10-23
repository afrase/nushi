# 0016. A chat can have a git worktree of its own

## Context
Several agents working in one repository step on each other's files. Git worktrees give each chat its own checkout and branch.

## Decision
- A worktree is an option when a chat starts in (or moves into) a git repository, off by default and remembered per repository by the app; never forced.
- Nushi makes it at `<repo>/.worktrees/<name>`, on a new branch `nushi/<name>` from the folder's current `HEAD`, and records the branch it started from (the base). `<name>` is two random words, unique in the repository. `.worktrees/` goes into the repository's `.git/info/exclude`, never into a tracked `.gitignore`.
- The chat runs in the worktree and is listed under its repository.
- Nushi never deletes a branch or a worktree with work in it without saying so first; a worktree a chat without messages leaves is removed only if git calls it clean and the branch merged (no `--force`).

## Consequences
- Worktrees live inside the repository's folder, so tools that walk the folder without git's ignores (editors, `grep -r`) see them.
- Claude keeps each worktree's sessions under its own history folder, as for any folder.

## Alternatives considered
- Worktrees outside the repository (`~/.nushi/worktrees/...`, as some tools do): harder to find and to clean up by hand.
