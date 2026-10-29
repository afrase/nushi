# 0065. Nushi stops Claude's background commands itself

## Context
Stop on a background command asked Claude, in a prompt, to call its `TaskStop`: a whole turn (Claude reads its context, loads `TaskStop` through `ToolSearch`, calls it, replies), queued behind a running turn, and two cards in the transcript, one with the whole command. The owner: "Do we need the full text of the background worker, or can we send just the id? A way to use fewer tokens." Claude Code gives a client that isn't JetBrains AIR no way to stop a task itself (`_session/async_task/stop` answers `{stopped: false}`).

## Decision
- A background command is a process under the chat's agent: Claude Code's shell, leading a process group of its own (Node's `detached`), its command line `<shell> -c [-l] "… && eval <the command, quoted> [< /dev/null] && pwd -P >| <file>"` (docs/facts/claude.md). Stop finds, below the agent's process, the group leaders whose command line unquotes to the call's command whole (`claude.RunsShell`, `internal/proctree`), and when there is exactly one sends SIGTERM to its group, then SIGKILL to what is left after 2 s. No prompt, no tokens, at once mid-turn.
- Only that group is signalled, and only while its leader is still below the agent's process, the same process (its start time) and the group's leader, checked again just before the signal (the group then holds only what the command started); the SIGKILL goes only to a group whose every process started before the SIGTERM.
- None found, two alike, a command line not readable whole (the input Nushi kept cut or masked, Claude Code's own changes to the command) or a refused signal: Claude is asked as before, in a shorter prompt (the id, and "reply only stopped or not running"). Subagents always are (they live inside Claude's process), unless their own session can be cancelled.
- The row ends "stopped" when Claude's output file says the command ended (`Shell.Killed`). Claude hears only that it failed ("exit code 144"); the next prompt tells it the user stopped it (a `[Nushi]` note, as a branch's rename is told, kept out of the transcript on replay).

## Consequences
- Claude still answers the failure notification with a short turn of its own, which Nushi can't prevent; it costs one model call instead of three or four.
- Codex, Ante and omp have background commands too, but Nushi shows no row or Stop for them (docs/facts).

## Alternatives considered
- Only a shorter prompt: still a turn and still waits behind a running one.
- Matching by "the command is in the command line": a longer command containing it, or a pipeline's subshell (same command line, not the group's leader), would match.
- AIR's async tasks (`asyncTasks`), which give a real stop: they switch the adapter to AIR's behaviour throughout.
