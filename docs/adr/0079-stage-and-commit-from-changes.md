# 0079. Stage and commit from Changes

Amends [0019](0019-changes-read-only-toward-git.md).

## Context
0019 kept Changes read-only so no git write could go wrong beside an agent that may be writing. In use, a review in Changes ended by asking the agent to commit or leaving for a terminal. The owner asked for stage and commit (2026-11-01). The risk 0019 named is real: staging takes the work tree as it is, which may be newer than the diff on screen, and the agent may stage or commit too.

## Decision
- **Uncommitted has a checkbox on each file and folder, and a commit box under the files.** Staging is whole files; a file staged in part (by a terminal, or changed since) shows a dash, and a click stages all of it. Branch and Commits stay read-only. Checking out and pushing stay with the agent or a terminal.
- **Only a click writes.** No timer, agent or tool stages or commits, and an agent gets no tool for it. `StageFiles` and `CommitStaged` are the Mac's calls: the phone has no Changes view.
- **A commit takes what the app last showed as staged.** `GetDiff` names the index and HEAD (`index`, a hash over every staged blob's id), and `CommitStaged` refuses if that moved, so what an agent staged after the last look isn't committed unseen. It also refuses when files outside the chat's folder are staged, which the view never showed.
- **Mid-turn it warns, it doesn't block** ("Claude is working, so files may change."). Nushi is unopinionated, a turn can be long, and the index check covers what a block would.
- **A commit is `git commit`: hooks and signing run**, in the login shell's environment so they find their tools, with `core.fsmonitor` off. Skipping hooks without saying so would make commits the user's own git refuses. Unlike every other git Nushi runs, this one runs the repository's code, so it's a user's click, never on its own.

## Consequences
- A file changed between the last reload and a click is staged as it is then. The reload after each click shows it, before any commit.
- A hook can run for a while: a commit gives up after five minutes, and what the hook said shows in the box.
- A hook or `gpg.program` in a folder the user never trusted runs on Commit, as it would in a terminal. The trust cards don't cover it.

## Alternatives considered
- Blocking while the agent works: safe, but it holds a commit for a whole turn, and doesn't stop a terminal.
- `--no-verify`: safer, but it silently skips what the repository requires.
- Staging by hunk: wanted, later; diff_view has no per-hunk controls yet.
