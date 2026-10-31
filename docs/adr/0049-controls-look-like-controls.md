# 0049. Controls look like controls

## Context
The owner couldn't tell what was clickable: Settings › General's terminal font and size and "After 30 minutes" were menus drawn as plain text, "Show logs" a borderless "ghost" button that read as a label, "Start work" and "Make a token" link-colored text you could click, a refresh icon whose meaning the screen didn't give, and the details panel's cards moved by dragging with nothing saying so. Each had grown as a `Tap` around a `Text` where it was needed.

## Decision
- **One set of controls** (`app/lib/controls.dart`), each on `Pressable` (a hover state, keyboard focus with a ring, Enter and Space, the pointing hand; nothing when disabled), in named tokens for both themes (`fieldFill`, `fieldBorder`, `fieldBorderHover`, `grip`):
  - **Button**: secondary (outlined; every action by default), primary (accent fill; only a dialog's or card's one main action), destructive (red text; Delete…, Remove, Revoke, a confirm that loses something). One height and padding; no borderless kind.
  - **MenuField**: a value picked from a list, as a bordered box with its value and a ▾; compact (no box, the ▾ and a hover tint) for a picker in a header or a row. **MenuButton**: an action with choices ("Start work ▾"). **MenuIcon**: ⋯.
  - **LinkText**: the link color, underlined under the pointer; for going somewhere from within text ("Settings › Agents"), never for an action.
  - **IconTap**: an icon with a hover tint and a tooltip, only where the icon alone is clear in its place (close, back, open in the browser, a refresh beside "Updated 3m ago").
  - **DragGrip**: six dots on a draggable card's title row under the pointer, with the open hand (the closed hand while dragged).
- **Plain text is never clickable.** `Menu` has no face of its own: it opens from one of the controls above or a row's right-click. `Tap` stays for list rows and tabs (a hover tint and the pointing hand, often a selected tint) and disclosures with their triangle. Amended (2026-10-31): a view's tabs are `PlainTabs`, labels with a line (ADR 0071), the one kind of plain text that's clickable, as the pane's file tabs already were.
- **⌘ keys**: ⌘1–⌘9, ⌘[ and ⌘] switch chats everywhere (holding ⌘ numbers them in the sidebar); a terminal's tabs and the Jira view's lists, which had ⌘1–9, take ⌥⌘1–9.

## Consequences
- Rows of lists carry outlined buttons ("Start work ▾" on every Jira and GitHub row): busier than link text, but they read as buttons. Amended (2026-10-26): five of them in a column dominated the GitHub inbox, so its rows show Start work as an icon button only on hover and on the selected row (⌘⏎ and the right-click menu as before). Amended again (2026-10-27): Jira's rows had the same column of buttons (the owner's Sprint list at work), so they do as GitHub's, with Start work in a new right-click menu; their status menu is a pill with no border at rest, its border under the pointer.
- A new screen picks from these: a `Menu` takes what opens it from its caller, and a `Tap` around bare text stands out in review.
- Muscle memory for ⌘1–9 in a terminal or the Jira view changes.

## Alternatives considered
- Keep the ghost kind for toolbars and dialogs' Cancel: it's what the owner couldn't read as a button.
- `borderSubtle` for fields' outlines, as first asked: on a dialog's raised fill it nearly vanishes in light; the field tokens sit between it and `borderStrong`.
- Keep ⌘1–9 local to the terminal and the Jira view while they have the focus: the sidebar's numbers would then lie there.
