# 0074. The chat is a centred column, or takes the whole width

## Context
ADR 0072 kept the transcript at `readableWidth` (860) and at the left, under the chat's title. The owner, on a wide window: "that looks stupid", and "I would prefer to have the option to take up the entire chat window real-estate or keep it fixed in the middle".

## Decision
- **Chat width** in Settings › General, also in the ⌘K palette: Centered, the default, or Full width (`chatFullWidth`, in `app.json`).
- Centered puts the transcript's text, the composer and the lines over it in a column of `readableWidth` in the pane's middle. Full width runs them to the gutters. A user message's band still goes edge to edge either way.
- `chatSides` and `ChatColumn` (`chat_column.dart`) say where the column is, so everything in it keeps the same edges. The phone keeps its own margins.

## Consequences
- Centered, the text no longer sits under the chat's title, which stays at the left gutter with the header.
- Full width on a wide window gives long lines, which are harder to read. That's the choice being offered.
- The archived and MCP banners that fill the pane's width keep the gutters.

## Alternatives considered
- Dropping the cap for everyone: no choice, and long lines by default.
- Keeping the column at the left: what the owner rejected.
