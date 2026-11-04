# 0086. A color theme is a named pair of token sets

## Context
Nushi had one palette, `Tokens.light` and `Tokens.dark`, picked by Appearance. The owner wants to change the colors of tool calls, subagents and the rest later, and to try palettes beside each other (the Clearer step and a bolder Vivid one were two branches). Every color already comes from the tokens (`theme/tokens.dart`); the terminal's ANSI colors and a diff's did not (VS Code's and `diff_view`'s, fixed), so a dark-blue palette would have kept a white diff.

## Decision
- **A theme is a name and two sets of tokens** (`ColorTheme`: `dark`, `light`). Appearance still picks which set shows; the theme picks the palette. Widgets keep reading `t.<token>`: a theme changes values, never names, and nothing outside the tokens holds a color. The terminal's sixteen colors (`Tokens.terminal`, VS Code's unless a theme gives its own), a diff's (`Tokens.diff`, drawn from the surfaces and status colors unless given; Nushi's are `diff_view`'s), hover and pressed (the text's tint unless given) became tokens for that.
- **Built in**: Nushi (the default, unchanged), Vivid (commit a95daedd's bolder step), Solarized, Nord and Catppuccin (MIT each, credited under `docs/development.md`'s Dependencies), each held by the token tests to the same floors as Nushi's: text AA on every fill it sits on, marks 3:1, washes and borders a visible distance off their surface. Where a palette's own inks read under AA on a fill (Solarized's body text is 4.75:1 on its base, under on a hovered row), they're moved in lightness, keeping their hue. Nord has a dark form only: its light set is derived (Snow Storm's surfaces, Polar Night's text, Frost and Aurora taken darker); no theme is dark-only.
- **The user's themes** are files, `themes/<name>.json` in the data folder beside `app.json`: `{"name", "from", "dark": {...}, "light": {...}}`, `from` a built-in's id (Nushi's unless given), each set mapping token names (`base`, `avatars.blue`, `syntax.keyword`, `terminal.red`, `diff.insertedLine`) to `#RRGGBB` or `#AARRGGBB`. What a file doesn't name is its `from` theme's. A file is untrusted input: a regular file only, 64 KB at most, 50 files at most, parsed as JSON and never run; an unknown key or a bad value is a note in Settings and is ignored, a file that's no JSON object is a note and no theme, never a crash. The app watches the folder and reads a file again when it changes. "New from" writes every token of the current theme, so a file starts whole and is edited, not written from nothing.
- **Contrast is a warning for the user's themes**: a pair under its floor is a line in Settings naming it, never a refusal (Nushi is unopinionated). The built-ins can't ship under it: the tests run over every one.
- **The phone** picks from the built-ins, its own setting kept in the browser's storage, read with the pairing before anything shows. Custom themes stay on the Mac.

## Consequences
- A new token is a new field in `Tokens`, its value in every built-in, and a line in `theme_file.dart`'s list (which names it for files); a file written before it lacks the token and gets its `from` theme's.
- `hover` and `pressed` in a file are fixed colors: a file that changes `text` without them keeps its `from` theme's tint, which is near the same text color in practice.
- A picked theme whose file is taken away shows Nushi's until the file is back; the pick stays.

## Alternatives considered
- A theme as a few seeds (base, accent, a hue per accent) that Nushi derives tokens from: less to write, but no one could fix the one pair that reads badly, and the built-ins' hand-held contrast would be a formula's.
- Themes from VS Code or iTerm files: their roles don't map onto Nushi's tokens (a tool call's tint, a subagent's, the findings card) without guessing.
- Refusing a custom theme under AA: Nushi gives warnings, not enforced flows.
