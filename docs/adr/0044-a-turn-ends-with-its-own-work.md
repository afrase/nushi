# 0044. A Claude turn ends with its own work, not when the adapter answers its prompt; Stop spares background subagents

## Context
claude-agent-acp holds a turn's `session/prompt` open, for v1 clients, until the background subagents the turn started have ended and Claude has answered their reports (so their permission requests land inside a turn). A chat that waited for the answer showed "Thinking" for as long as a subagent ran (30 minutes in use), queued every message, and offered only "stop Claude and send". Stopping it was worse: without a host option, Claude Code's interrupt kills background subagents, and nothing tells the client, so the subagent's row ran on forever. Claude Code's terminal lets you talk to Claude while a background agent works, and Esc there leaves it running.

## Decision
- A turn is over for the chat at its result: Claude's usage report with the cost from a cycle the user started (`_claude/origin.kind` "human"), when subagents the turn started still run in the background (`Dialect.TurnDone`). The chat is idle; a message goes as the next prompt, which the adapter takes at once (answering the held one); the held prompt's answer changes nothing. A result just after a steered message is the cut-short work's and doesn't count; a turn told to stop ends with its answer, as before.
- Claude's sessions declare `perTaskStopAffordance` (`Dialect.SessionMeta`), as Claude Code's terminal does: Stop stops only the turn. Nushi has no per-subagent stop (the adapter's `_session/async_task/stop` is AIR's); one is stopped by asking Claude, or by stopping Claude.
- Whatever stops Claude stops its background subagents: Sleep, Archive and Reload ask first, a subagent stopped that way shows "stopped", and Move and Rewind wait for them.

## Consequences
- The end of a turn rests on vendor `_meta` (`_claude/origin`); without it a held turn stays busy, as before. A new adapter that answers the prompt at the result needs nothing.
- Claude's answer to a subagent's report comes outside a turn: it shows as Claude working on its own, as after a background command.
- A runaway background subagent can't be stopped from its row.

## Alternatives considered
- Advertising the ACP subagents RFD (`subagents` client capability), which also spares subagents on cancel and gives each a session that can be cancelled: it changes how every subagent update arrives; a bigger move, in Later ideas.
- Treating any idle moment while only background tasks run as the turn's end: no signal says when that is.
