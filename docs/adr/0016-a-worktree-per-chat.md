# 0016. A chat can have a git worktree of its own

## Context
Several agents working in one repository step on each other's files. Git worktrees give each chat its own checkout and branch.

## Decision
- A worktree is an option when a chat starts in (or moves into) a git repository, off by default and chosen per chat (remembered per repository until the third amendment); never forced.
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
- The transcript gets a quiet line ("Branch renamed to nushi/…"). The agent is told with the next prompt (the amendment below).
- Rename branch… in the Environment card renames it to any name git takes, between turns, and turns the naming off. A branch on a remote (an upstream, or a remote's branch of its name) is refused, "It's on the remote: rename it there too, or keep it", rather than renamed here alone, which would leave the local and the remote names apart (a plain `git push` then refuses, or pushes another branch).

## Amendment (steps 334–335): the agent is told
- A rename, Nushi's or Rename branch…'s, goes to the agent with the next prompt: a text block of its own before the user's, `[Nushi] This worktree's branch was renamed from <old> to <new>. Use the new name.`, once. Several renames before it make one note, from the name the agent last had to the latest; renamed back to that name, none. What's pending is the worktree's `Told` (the name the agent last had) against its branch, kept with the chat, so it survives a restart; it's recorded once the prompt is written to the agent.
- A rename before the first prompt is told too: Claude's system prompt takes git's status when its session starts, before any turn (seen by hand, step 334), so it has the old name. Agents without such a snapshot get one sentence about a name they never saw, which is harmless.
- Both names are checked by git (its rules, then `git check-ref-format --branch`) before going in; they're the note's only variable text. A name refused drops the note (logged).
- The note is in the agent's own history, as the first part of that prompt (Claude's transcript and Codex's rollout: the message's first text block; Ante's and PiG's sessions: its first paragraph, as their bridges join blocks with a blank line), so resuming in a terminal shows it there. Nushi takes it out of the user's message when the agent replays it.
- The rename's line gets "· told the agent" once the note went with a prompt, rather than the prompt's bubble showing the note: quieter, and the line is where the rename was shown. Rename branch… draws the line too.
- Alternatives: merged into the user's words (they'd change, and the copy and the replay would differ); a prompt of its own at the rename (a turn nobody asked for, in the user's quota); `_meta` (agents ignore it).

## Amendment (step 337): the choice is per chat, not remembered
- The owner's call, 2026-10-27, after a new chat opened in a worktree unasked: "I don't want it to auto create worktrees because I don't always want to work in one." Every plain new chat starts in the folder itself; the "New worktree" chip (and the Environment card's switch) moves that chat only, and the next new chat starts without one again. The app no longer keeps the repositories it was turned on in; an older `app.json`'s `worktrees` key is ignored and dropped by the next save.
- A worktree comes only from a choice in sight: the chip or switch on the chat, Move to new worktree… on a chat with messages, or a Jira or GitHub issue's chat, whose New chat sheet shows its worktree switch (on when the issue is picked, as before). Moving a new chat to another folder (its folder button) never makes one. Side chats and rewinds stay in the chat's own folder (a worktree chat's worktree) and never make one; opening an agent's session runs in the folder picked; the API's `worktree` fields default to false.
- Alternatives: remembering it with a visible "remembered" mark (still a surprise in a repository the user forgot they'd turned it on in); a setting for the default (one more control for what's one tap per chat).

## Amendment (steps 392–393): worktrees that were there, and switching a folder's branch
- The owner, 2026-10-28, after `git checkout try-sqrly` refused ("already used by worktree"): "I'm on main but have a worktree that I want to open", and "Can the branch in the Environment widget let me switch branches?"
- A chat can move into, or start in, any of its repository's worktrees (`git worktree list`; those git would prune left out, locked ones marked). One Nushi didn't make for the chat is kept as `Found`: listed under its repository, never removed or its branch deleted by Nushi (Delete doesn't offer it), never named after the chat. Moving back into one Nushi made for the chat before makes it the chat's own again.
- A chat in a repository's own folder switches its branch (`git switch`, a local branch only, or a new one from HEAD), between turns. Not to a branch another worktree has (git refuses; Nushi offers that worktree instead), not with uncommitted changes to tracked files (no stash: the user decides; a new branch takes them along), not while any chat in the same checkout works, and only after the user confirms when other chats work there: they move too. A worktree chat moves to another worktree instead of switching inside its own.
- The agent is told with the next prompt, a note of its own as for a rename: `[Nushi] This folder's branch changed from <old> to <new>. Work on <new> from now on.` (every chat in the checkout, from the branch it last had; none when back on it), and after any move of a chat with messages ``[Nushi] This chat moved to `<folder>`, on branch <b>. Work there from now on.`` (a fork's history still names the old folder). Both are taken out of the replayed message, as the rename's note is.
- Alternatives: stashing changes to switch (the stash is easily forgotten, and the agent's work in progress would vanish from its folder); `git switch` inside a worktree (a worktree is one branch's checkout; another worktree is the way to another branch).
