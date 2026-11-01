# 0076. Messages as bubbles, their actions on hover, tool rows in their tint

## Context
The owner, after ADR 0072 took the box off tool rows: "I like that they were more prominent". They also liked Claude Code's chat layout, with their own messages on the right and a row of actions under a message under the pointer, its time and "Read by Claude" among them.

## Decision
- **On the Mac a user message is a bubble** at the column's right, 640 at most, in the band's colors. The phone keeps its band.
- **A message's actions** are a row under it, on hover: on the user's the Read mark, its time, Copy and Rewind, on the agent's Copy, Fork from here and its time. They replace the buttons at the message's top right. Their 28 is kept while they don't show, so nothing moves as the pointer passes, and comes out of the gap below.
- **A tool row is in the tool rows' tint and outline again**, reversing ADR 0072's "no box until it fails".
- **The time** is `Item.sent`, now also set as an agent's message begins to arrive; a replay says nothing of when, so a message only the agent replayed has none. The tooltip has the date and time.
- **Read** is two checks once something of the agent's own follows the message, one until then: the app works it out from the transcript, and nothing is stored.

## Consequences
- Messages from before this have no time unless they're the user's and Nushi's copy has it.
- Read means the agent answered, not that it took the message in.
- A run of tool rows is busier than a line of text. That's the prominence asked for.

## Alternatives considered
- Showing the row's room only on hover: the transcript would move under the pointer.
- Tool rows with brighter text and no box: less crowded, but it isn't what the owner liked.
