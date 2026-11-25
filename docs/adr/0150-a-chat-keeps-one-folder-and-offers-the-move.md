# 0150. A chat keeps one folder and offers the move

Status: accepted, 2026-11-25. Builds on [0014](0014-moving-a-chat-forks-it.md) (a move forks the session there) and [0016](0016-a-worktree-per-chat.md) (a worktree per chat).

## Context
Claude's agent can enter a worktree itself (Claude Code's EnterWorktree). It said it had switched; Nushi's folder, branch, Changes and terminals stayed in the start folder, and the owner moved the chat by hand from the folder button's menu.

## Decision
- **One folder per chat.** Nothing about where the agent says it works is kept on the chat's record, and nothing follows it by itself.
- **The call says it.** A harness that knows reads, from a tool call's update, where the agent works once the call completes: a worktree it entered (its path) or its session's folder again (`chats.WorkReader`; Claude's from EnterWorktree's and ExitWorktree's `toolResponse`, `docs/facts/claude.md`). The item keeps it (`Item.WorksIn`, API 152), only for the main agent's call that didn't fail and only as an absolute path, and the transcript copy keeps it past a restart.
- **The call offers the move.** The chat's latest such call, when it entered a worktree the chat isn't in (its folder, or its worktree's path), has **Move chat here** at its row's end: the folder button's own Move, its question included. A later call that left the worktree, or the move, ends the offer. While the agent works or waits on the user it stays in place, disabled, saying it can move once the agent is done. Its row never folds into a run. None in an archived chat or a side chat; the Mac's, not the phone's.
- **No git check when the item is made**: the path is Claude Code's own tool result, not the model's words; nothing runs or writes there until the user presses it, and Move takes it as any folder the user picks (`docs/security.md`).
- The fork a move makes into such a worktree was recorded before it was trusted (`worktree-fork-into`): a plain session in the worktree, on its branch.

## Consequences
- A `cd` or a `git worktree add` the agent runs itself offers nothing: only a harness's own report does, and only Claude has one.
- After the move the chat is in the worktree as if picked from the folder button: Changes, terminals and the branch follow, and the worktree is one Nushi didn't make, so Nushi never removes it.

## Alternatives considered
- **The chat follows its agent**: a second place per chat (`WorksIn` beside `Folder`, with when it began), built in part and dropped (2026-11-25). Every reader of a chat's folder would have had to choose between the two, Changes, terminals and the sidebar each in its own way, and it still wouldn't follow a plain `cd`. A move the user asks for keeps one answer.
