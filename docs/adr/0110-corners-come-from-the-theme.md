# 0110. Corners come from the theme's radius tokens

Status: accepted, 2026-11-11.

## Context
The owner finds the app's look dated, above all its harsh, square corners (2026-11-07), and liked a mock with a 14-point base radius, smaller radii nested inside it and pill-shaped chips. The theme had three radii (`control` 4, `card` 6, `panel` 10), but about seventy corners outside it were written as numbers (1, 2, 3, 4, 7, 8, 10, 12, 14, 16), so no change to the theme could make the app rounder.

## Decision
- **Every rounded corner is a token of `NushiTheme`** (`app/lib/theme/theme.dart`), as every color is one of `tokens.dart`'s:
  - `tag`: the smallest things (a key hint, a branch's name, a loading bar);
  - `control`: buttons, fields, icon buttons, a row's hover and selected fill;
  - `card`: cards and boxes (`box` and `framed` unless told otherwise);
  - `panel`: a menu, a dialog, a popover, a message's bubble;
  - `pill`: round ends whatever the height (chips, badges, counts, round buttons, thin bars).
- **A shape nested in a rounded one** takes `NushiTheme.inner(outer, gap)`: its parent's radius less the padding and border between them, so the two curves stay parallel and the inner one is never the rounder.
- **What isn't a corner keeps its size**: a circle (a dot, an avatar), a scrollbar's thumb, a drawn icon's own geometry, a splash's reach. Such a number takes `// not a corner: <why>`.
- **A test holds it** (`app/test/corners_test.dart`): a `Radius.circular(<number>)` or `radius: <number>` outside `app/lib/theme/` fails. The Markdown package can't see the theme, so its code block's corners are its style's (`MarkdownStyle.codeRadius`, the app's `card`).
- **The values** are today's until the rounder pass, which changes the tokens and nothing else.

## Consequences
- A rounder or squarer app is a change to five numbers, then a look at what clips.
- A new shape has to say which kind of thing it is, not how round it looks beside its neighbours.

## Alternatives considered
- Radii on `Tokens`, so a theme file could set them: nobody has asked for a theme's own shapes, and every `const` decoration would stop being one.
- A lint rule in the analyzer: a plugin to build and pin for one pattern a test finds in a second.
