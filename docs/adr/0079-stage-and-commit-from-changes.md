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

- **The chat's agent can write the message** (the owner, 2026-11-01; Orca and JetBrains do). A button in the commit box sends the staged diff to a throwaway fork of the chat's session, which knows why the work was done, as an unasked `/context` does (Claude, Codex for now). The answer lands in the message field and nothing commits until the user does. The diff is anyone's text and nobody watches the fork, so an injected instruction mustn't get to act: the fork goes to the harness's read-only mode first (no read-only mode, no button: Pi, PiG, Ante and omp), a permission ask in it is declined, its first tool call ends it, and the diff sits between random marks, with secrets' shapes masked, 64 KiB at most.

## Consequences
- A file changed between the last reload and a click is staged as it is then. The reload after each click shows it, before any commit.
- A hook can run for a while: a commit gives up after five minutes, and what the hook said shows in the box.
- A commit follows the local git: identity, signing (GPG or SSH), hooks and `commit.*`. A signature that fails stops the commit, and a passphrase prompt shows where pinentry shows it; a pinentry that needs a terminal fails, with gpg's words in the box.
- Claude's plan mode still runs a tool the user's settings allow outright, until the first tool call ends the fork, so such a call can start. The fork can only be asked while the chat is idle.
- A hook or `gpg.program` in a folder the user never trusted runs on Commit, as it would in a terminal. The trust cards don't cover it.

## Alternatives considered
- Blocking while the agent works: safe, but it holds a commit for a whole turn, and doesn't stop a terminal.
- `--no-verify`: safer, but it silently skips what the repository requires.
- Staging by hunk: wanted, later; diff_view has no per-hunk controls yet.

## Amendment (2026-11-09): only the staged files shown commit
A commit sent the newest reload's index, so a reload landing between the click and the commit (a turn's, or staging's own) could bring a file an agent staged, and it was committed unseen. Commit now takes the files shown staged at the click, the user's own Stage and Unstage included. Once staging and reloads under way are in, it refuses if other files are staged: "Staged files changed since you looked: X. Look them over and commit again." Otherwise it sends the index the view showed, or, after the user's own staging, which only a later reload names, that reload's. Changes reads nothing while hidden, so only what showed counts. The daemon reads the index's state before the files, so a file staged between the two moves the index and the commit is refused. Left uncaught: an agent staging a newer copy of a file already staged, in the moment between the user's own Stage and its reload.

**Amendment (2026-11-25): no /context to compare with.** The Context widget no longer forks: it asks Claude through `_session/contextUsage` ([ADR 0017](0017-context-breakdown-from-claude.md)), so the commit message's is the only fork of a chat's session that Nushi prompts unseen; the guards above are unchanged.

## Amendment (2026-11-25): a change block at a time
The owner asked for single hunks (#82). A file modified in place stages and unstages one change block at a time, the blocks being the ones Changes shows (diff_view's, from the HEAD and work tree texts): the app sends the blocks by line numbers and the ones the user pressed, never patch text; the daemon reads the texts from git and the disk, and writes the index entry alone, as HEAD's lines with the staged blocks' lines from the work tree (`StageHunks`). `GetDiff` gives each such file a token over its texts and index entry, and `GetHunks` and `StageHunks` refuse when it moved, so a press never takes lines the user didn't see. Pressing a staged block again on a fresh look changes nothing. A new, deleted or renamed file, a binary or over-large one, a link, a submodule, an unmerged file and one a filter driver cleans (git-lfs) stage whole; so does a file whose index isn't made of its blocks (staged, then changed again), until it is staged or unstaged whole. A change only to a line's ending (a last newline added, CRLF to LF) is no block, so only the whole file stages it.

## Amendment (2026-11-25): Push
Changes pushes too (#82), on the user's click alone: the folder's checked-out branch and nothing else, as the user's own `git push` (their pre-push hook, credential helper and ssh agent; Nushi reads no credential). It goes to the branch's upstream when that is a branch of the same name, else to the only remote or `origin`, setting the upstream; it refuses a detached HEAD, an upstream of another name (pushing a feature branch onto the `main` it tracks would surprise), a local upstream, and several remotes without `origin`. Never a force, tags, another branch or a submodule's. `GetFolderStatus` says how many commits the remote's copy lacks, or that there is none yet, from the refs as last fetched (no network), and is zero where Push would refuse, so the button shows only when there is something it would send. A pre-push hook can lint for minutes, so a push gives up only after 15 minutes, or when its request ends. A push from a chat's Changes makes the branch the chat's own, as an agent's push does, so its pull request is found.
