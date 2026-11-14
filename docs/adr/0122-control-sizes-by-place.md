# 0122. A control's size comes from its place

Status: accepted (the owner, 2026-11-14).

## Context
Every button, menu field and segmented control was 26 high with a 13-point label and 10 points at its ends, wherever it sat: a dialog's Cancel and Delete were as small as a row's Log. The owner finds the buttons, above all in dialogs, too small and "kind of ugly". Fields were 26 in the app's UI or code text and 30 with none set (Material's larger default), so a form's fields didn't match each other or its buttons. For comparison, AppKit on this Mac (macOS 27.2, measured with `fittingSize`) makes a push button 24 regular, 28 large and 36 extra large, all at 13 points, and a bordered field 24; Claude's desktop app, which Nushi follows, uses about 32 at 14 points for a button, 28 for a small one and 36 for a field (from its look, not measured).

## Decision
- **Three sizes, picked by place, never per call** (`ControlSize` in `app/lib/theme/sizes.dart`):

  | Size | Height | Label | Ends | Icon | Narrowest | Corners |
  |---|---|---|---|---|---|---|
  | `compact` | 26 | 13 w500 | 10 | 14 | — | 8 |
  | `regular` | 30 | 13 w500 | 12 | 14 | — | 9.2 |
  | `large` | 34 | 14 w500 | 16 | 15 | 80 | 10.5 |

- **`ControlScale` says the size below it**; without one a control is `regular`. `compact`: the details panel's widgets, a list's or a table's row (a pull request's to-do rows, Chat history's rows), a menu's row (the servers menu), a one-line toast (Undo), and the Changes bar while it's narrow. A compact `Segmented` keeps its old 25, as high as `PlainTabs`. `large`: a dialog's actions (`nushiDialog`, and the MCP server form, its own `AlertDialog`) and a view's main call to action (the empty window's New chat and Open a folder…).
- **What follows the size**: `Button`, `MenuButton`, `SplitButton`, `SendButton`, a `MenuField` with its fill, `Segmented` (the header's `roomy` one is `large`, 34 as before), `LineSlider`. A field is a regular control's height and corners, in either font: its padding centres a 19-point line in 30, and its hint, whose room Flutter keeps while there's text, takes that line (`theme.dart`'s `_hintLine`); a field without its own style sets UI text (the theme's `bodyLarge`), not Material's larger default. A field with no hint is a point or two shorter, so a form's fields have one. Fields are regular everywhere: no compact place has one yet. The composer's pills and round buttons (32), the tool rows' small pills (24), `IconTap` (26; 32 in the header), `WideButton` (38), menu rows (30) and settings rows (46) keep their own sizes: each is already set by what it sits in.
- **Corners keep one shape**: a control's corners are `control` at the compact height and the same share of the height at the others, so the later rounder pass changes one token and every size follows (ADR 0110).
- Settings' switch is 22 high (was 20), nearer the Mac's.

## Consequences
- Dialogs, cards, bars, settings and forms are four points taller where they have buttons; dense places look as before.
- A new dense place has to say so (`ControlScale.compact`), or its buttons grow: the goldens show it.
- Every field with a hint is 30, in UI text or code; a search field over a list (the palette's, a menu's filter) too.

## Alternatives considered
- Every control 30: the details panel, a to-do row and a table's row get crowded, and a 30-high Log beside a line of 12-point text looks heavy.
- A size argument on each call: 134 buttons to keep in step, and a new one picks at random.
- The Mac's own 24/28: smaller than the owner wants, and Nushi's 13-point text in a 24-high box is what looked cramped.
