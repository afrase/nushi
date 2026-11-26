# 0139. The workflow card says each thing once and opens in place

Status: accepted, 2026-11-20. Amends [0127](0127-claudes-workflows-show-in-the-chat.md).

## Context
A workflow's card (ADR 0127) had three lines: the name with the current phase's count, how many ran and the time; the description; then every phase's count again with the labels of who ran. The current phase showed twice, the labels were hard to read at a glance, and the card couldn't be opened where it was: only the Workflow pane showed more. It said nothing of what the run used. A workflow's agents never reach a chat's turn, so the usage store doesn't count them (ADR 0136), and Claude reports no cost for a run.

## Decision
- **One line**, as a subagent's row: the name, then where it is and how long, in the subagent row's order (what it does or how it ended, its count, its tokens, its time; done says no word, its check does: "Review 4/7 · 3 running · 412k tokens · 4m 12s"). Narrow, the state takes a line under the name and gives way from its count, then its tokens, never where it is or its time. An end that wasn't done keeps a line of its own. The mark and its Stop share one room.
- **Opens in place**: a chevron at the card's start, as a tool call's, opens it to its description and each phase reached, a line each with its mark, progress and the labels of its agents running now ("+3" for more, never cut). It's built from the summary on the item (each running label now carries its phase's index), so the phone shows it too; the pane keeps the whole tree and opens from the pane button at the card's end (2026-11-20: a click on the card opens it in place too, as its chevron; before, the click opened the pane and the card ended in a second chevron, two things on one card that looked alike. A row that opens a side pane, a subagent's too, now ends in the pane icon; a chevron is only for what opens in place). Open stays open while the app runs, as a tool call's.
- **Tokens from the agents' transcripts**: while it runs the daemon reads each listed agent's transcript as it grows (every few seconds while it runs, once after it ended) and keeps its last message's token counts, as Claude counts a subagent's; the run's tokens are their sum, and once it ended its snapshot's `totalTokens`. No cost is shown or guessed.

## Consequences
The summary on the item grows by a number and an index per running label. A run's total can step when its snapshot replaces the daemon's reading, should Claude count an agent otherwise than by its last message (the recordings can't tell, `docs/facts/claude.md`). Were claude's `task_progress` usage passed on by the agent, it could replace the reading of transcripts.

## Amendment (2026-11-26): commas, not dots
The line joins its parts with commas ("Review 4/7, 3 running, 412k tokens, 4m 12s"), as a subagent's row does at every width: no dot between a line's parts (issue 119).
