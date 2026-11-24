# 0130. Claude's task status ends a background command

Status: accepted (2026-11-17).

## Context
Nushi guessed when a Claude background command (`run_in_background`) ended: from its output file's end line (`[exited with code N]`, `[killed]`), since 2026-11-17 only once the file had stopped growing after it and the command's shell no longer ran, and from `TaskStop`'s result. Each guess had a way to go wrong: a server logging its shutdown after `[killed]` read "running" for ever, a command printing such a line itself could read ended, and a file Nushi can't read leaves the end unknown. claude-acp-go v0.5.0 forwards Claude's own task for the command, as updates of the Bash call (`_meta.claudeCode.task`: `running`, then `completed`, `failed`, or `killed` then `stopped`; replayed on `session/load` where the transcript has the end; `docs/facts/claude.md`).

## Decision
- **Claude's task status is the source of truth** for whether a Claude background command runs and how it ended: `running` runs; `completed` is done, `failed` failed (stopped if Nushi's own Stop killed it, as before), `killed`/`stopped` stopped. The first of an end's two updates ends the row; the second only fills in how. A task update changes nothing else: no turn of Claude's own, no change to the call.
- **The file and the shell are the fallback**, used only for a command whose task no update told: an agent without these updates, a claude that exited mid-command (its `running` no longer counts once that claude is gone), a reopened chat whose history had no end. Their rules are unchanged.
- **The file still gives the output** ("Output so far") and, when it has Claude's end line, the words of how it ended; else the exit code is read from the task's summary, else none.
- **A reopened chat's copy** takes the end the replay told for a command it shows ended unknown; a replayed `running` (only from a claude that still runs it, which a reopen never has) doesn't revive one.
- **`TaskStop`'s result** still ends the row at once (the same fact, sooner), now also one whose end was unknown.

## Consequences
- What shows a command running (the details panel, the daemon update's "in background" wait, auto-sleep) follows Claude's status where there is one.
- A claude that exits mid-command leaves its commands to the fallback: their file's end line, else "started" (the end unknown), as when the daemon goes (background commands outlive Claude).

## Alternatives considered
- Keeping the file as the source and the task as a hint: the guesses above stay.
- Dropping the fallback: other agents and older chats would lose their ends.

## Amendment (2026-11-25): following a command costs little while it runs
A command can run for hours (a dev server), so following it must cost little while it does.
- **The file is read only once it changed**: each poll (a second) looks at its size and time (an `lstat` by the same path rules, in `internal/claude`), and reads it again only when either differs from its last read; meanwhile that read's output and end stand, and each poll still judges them, so the fallback's "stopped growing after the end line" and an end Claude told of still end the row.
- **Its output is sent at most every two seconds**: a change to a running command's output alone goes to the apps (and the phone) at most every two seconds (`commandTail`), still live to a person watching the tail, at half the events of a command that writes all the time; a change of its state (running, its end, a stop) goes at once, with the output as the file has it then.
- **The copy (ADR 0047) takes the row at its call's end and at the command's end**, not at each model call after: a change to the output alone no longer marks the row for the copy, since the file gives the output again while the command runs; its end (or "started", its end unknown) is written to the copy at once, with the output as the file then has it. A daemon that goes mid-command leaves the copy with the output as at the call's end, or as at the last state change.
