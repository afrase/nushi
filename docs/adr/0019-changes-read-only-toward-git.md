# 0019. The Changes view is read-only toward git

[0079](0079-stage-and-commit-from-changes.md) amends this: Uncommitted stages and commits, from a click. Checking out and pushing stay out. [0096](0096-editing-in-the-preview.md) amends it too: the preview edits a file, saved through the daemon.

## Context
The Changes view shows a chat's work: what's uncommitted, the branch since it left its base, and its commits. Diff tools often also stage, commit, check out or push.

## Decision
Nushi only reads git in the Changes view. Committing, staging, checking out and pushing are done by the agent or in a terminal. The branch's base is the chat's worktree base, else the remote's default branch (`origin/HEAD`), else `main` or `master`.

## Consequences
- No git write paths to get wrong next to the agent, which may be writing at the same time.
- Feedback goes to the agent as review comments instead of edits made in Nushi.
