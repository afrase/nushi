# 0081. A chat's related worktrees: git says what exists, the tool calls say whose

## Context
An orchestrating chat runs subagents in worktrees off main, and their work should show in the chat. Nothing told Nushi about those worktrees: a chat's `Worktree` is the one it runs in, and `chats.Subagents` is Claude's alone. Claude's own record is thin. A background subagent's worktree reaches ACP nowhere; `.meta.json` names it until a clean removal, and only for the Agent tool's `isolation`; a subagent can also run `git worktree add` itself, which leaves only its Bash input (`docs/facts/claude.md`). And a worktree goes: Claude sweeps a clean one, an orchestrator removes the rest.

## Decision
- **`git worktree list` for the chat's repository says what exists; the chat's tool calls say whose it is.** A listed worktree is related when a subagent's `Paths`, `Diffs` or shell input names it, absolutely or relative to the chat's folder, or when Claude says so (`worktreePath` in a foreground subagent's result, `.meta.json`). The first subagent to name one has it. git, not an agent's word, is what could cover other agents later.
- **Trust neither.** An agent writes `.git/worktrees/*/gitdir` as it writes `.meta.json`. A path counts only if git lists it and it is the top of a work tree whose `--git-common-dir` is the chat's, by real path; failing that, a known one is `removed`. Nothing here joins `Roots`.
- **A chat's own and other chats' worktrees stay out**, and so do those a chat's folder is in. The first chat to find a worktree keeps it.
- **The head is recorded at every look**, and a subagent's end is a look of its own, since a turn ends while background subagents run (ADR 0044). Looks also come with a turn's end, with `GetRelatedWorktrees`, and with a subagent's steps, at most every 5 s. A worktree that goes keeps its record as `removed`, so its commits can be diffed while git keeps them. The base is where it left the chat's branch, as first seen.
- **A look runs only `worktree list`, `rev-parse`, `merge-base` and `rev-list`**, so no look runs a filter or a hook, whoever asks for it.
- **"Merged" is what git shows**: a worktree with commits of its own whose `LastHead` is on the chat's branch or its base, at each look. A squash merge leaves nothing for git to see, so it reads as removed; so does a worktree that made no commits, whose head is on the branch without anything having been merged.
- **The app never stages, commits, discards or comments in one.** Its Changes view is read-only, and review comments would go to the orchestrator if they come back, as the subagent has usually exited (the owner, 2026-11-02).
- **Only a click runs a `GetDiff` there**, as it runs the repository's filters (`git.Status` doesn't). A turn's end, an event or showing the tab again never does: what's read stays, with a line saying it changed. `GetRelatedWorktreeStats` is the automatic read: it costs less than `GetFolderStatus`, as a base that is a commit needs no merge base and no branch name, and a removed worktree's come from its commits alone.
- **A removed worktree's diff is `after` its base, not `since`**: `since` counts its own commit, which would put the chat's last commit under the subagent's work.
- **The record is the chat's** (`ChatRecord.RelatedWorktrees`), read with `GetRelatedWorktrees`; the `related_worktrees` event carries all of them when they change. Unnumbered, as terminals: a client reads them when it shows the chat.
- **Nushi writes nothing for this.** No ref, and no Clean up: Claude's sweep and the orchestrator remove worktrees (the owner, 2026-11-02).

## Consequences
- A removed worktree's commits can be collected by git once nothing else holds them: `LastHead` then names nothing, and its diff is gone. The owner chose that over Nushi keeping a ref.
- A subagent's reading another's worktree before that one's own steps show can take it, as the first to name it. Claude's word comes first, so this is about Bash-made ones.
- A worktree a subagent reaches only through a path it built at run time, or by a relative path from outside the chat's folder, isn't found unless a later step names it.
- A subagent that made no call Nushi can read and left a clean worktree is never seen: there is nothing to show of it.

## Alternatives considered
- **`refs/nushi/*` to keep a removed worktree's head**: reachable for good, but the owner's rule is that Nushi doesn't mess with git refs.
- **The lock's reason** (`claude agent agent-<id> (pid …)`), which `git.List` drops: it names the subagent, but only while it runs, in free text with a pid, and `.meta.json` says the same for longer.
- **The transcript's `cwd`**: stays the chat's folder for a Bash-made worktree, and says nothing `.meta.json` doesn't for an isolated one.
- **Only `worktreePath` and `.meta.json`**: they miss Bash-made worktrees, and every agent but Claude.
- **Watching `.git/worktrees`**: a file watcher per repository for what a look at a subagent's end already gives.
