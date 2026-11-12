# 0110. Corners come from the theme's radius tokens

Status: accepted, 2026-11-11.

## Context
The owner finds the app's look dated, above all its harsh, square corners (2026-11-07), and liked a mock with a 14-point base radius, smaller radii nested inside it and pill-shaped chips. The theme had three radii (`control` 4, `card` 6, `panel` 10), but about seventy corners outside it were written as numbers (1, 2, 3, 4, 7, 8, 10, 12, 14, 16), so no change to the theme could make the app rounder. This is pass one of the redesign: shapes only. Colors, fonts, the layout and the sidebar's projects are later decisions (`docs/roadmap.md`).

## Decision
- **Every rounded corner is a token of `NushiTheme`** (`app/lib/theme/theme.dart`), as every color is one of `tokens.dart`'s:
  - `tag` 4: the smallest things (a key hint, a branch's name, a loading bar, a checkbox);
  - `control` 8: buttons, fields, icon buttons, a row's hover and selected fill, and the transcript's own parts (a tool call's row, a code block, a diff, an image);
  - `card` 12: cards and boxes (`box` and `framed` unless told otherwise): a permission, a question, a settings group, a list's card;
  - `panel` 14: a menu, a dialog, a popover, Settings' window, a message's bubble, the composer's box;
  - `pill`: round ends whatever the height (chips, badges, counts, `Segmented`, round buttons, thin bars).
- **A shape nested in a rounded one** takes `NushiTheme.inner(outer, gap)`: its parent's radius less the padding and border between them, so the two curves stay parallel and the inner one is never the rounder. A menu's rows are `inner(panel, menuPad)`. Where a control sits in a card, its own 8 is close enough to that and stays.
- **A row one line high is never a card**: at 28 high a card's 12 makes a lozenge, so a tool call's row takes `control`, open or closed.
- **What isn't a corner keeps its size**: a circle (a dot, an avatar), a scrollbar's thumb, a drawn icon's own geometry, a splash's reach. Such a number takes `// not a corner: <why>`.
- **A list that scrolls to a rounded container's corners** says so with `RoundedScroll(corner:)`: its scrollbar's ends keep half the corner off the list's ends, where the curve would cut the thumb.
- **A test holds it** (`app/test/corners_test.dart`): a `Radius.circular(<number>)` or `radius: <number>` outside `app/lib/theme/` fails. The Markdown package can't see the theme, so its code block's corners are its style's (`MarkdownStyle.codeRadius`).

## Consequences
- A rounder or squarer app is a change to four numbers, then a look at what clips: text or an icon at a corner, a list's first and last rows, a focus ring, a hover fill, a scrollbar.
- A new shape has to say which kind of thing it is, not how round it looks beside its neighbours.
- Nothing moved or changed size, and no color changed. A chat's color bar is two points shorter at each end, to stay inside its row's corners.

## Alternatives considered
- The mock's 14 everywhere, with pill-shaped buttons: at this app's row and control heights (26 to 28) it reads as bubbly, and the owner found parts of the mock too busy.
- Radii on `Tokens`, so a theme file could set them: nobody has asked for a theme's own shapes, and every `const` decoration would stop being one.
- A lint rule in the analyzer: a plugin to build and pin for one pattern a test finds in a second.
