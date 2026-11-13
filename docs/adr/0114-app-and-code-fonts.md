# 0114. An App font and a Code font

Status: accepted, 2026-11-13.

## Context
The owner (2026-11-13): "App font. Right now you can only set terminal font but we should allow all of the UIs font to be changed." Only Settings › Terminal had a font menu. Everything else was set in two constants of the theme, IBM Plex Sans (`NushiTheme.uiFont`) and JetBrains Mono (`codeFont`), which a few widgets and the diff view also named for themselves.

## Decision
- **Settings › Appearance has a Fonts group**: **App font** (every installed family) and **Code font** (the monospaced ones: code in chats, diffs, previews and the editor). Each is the terminal's kind of menu: the bundled font first ("bundled"), a line, then the installed families, in order whatever their case. On the Mac, App font also has **System** (`.AppleSystemUIFont`, San Francisco, which no family list has) after the bundled one. No size setting.
- **Two app preferences**, `appFont` and `codeFont` (`settings.dart`): a family's name, or null for the bundled font.
- **The theme carries them** (`NushiTheme.uiPicked`, `codePicked`): `ui()`, `code()`, Material's text theme and the diff view's theme take their family from it, and no widget names a family itself (`uiFamily`, `codeFamily`). `main.dart` makes the window's theme from the two preferences (`NushiTheme.forTheme(…, ui:, code:)`, made once per theme and pair of fonts) and listens to them, so a pick redraws everything at once, with no restart.
- **The bundled font always follows a picked one** as its fallback (`fontFamilyFallback`), so a family that was uninstalled, or lacks a glyph, still draws. A widget that adds fallbacks of its own (emoji in a tile, a key's symbol in a menu) adds them after it (`thenFonts`), never in its place. Code keeps ligatures off.
- **A family's name is someone else's text**, from the system's list or from `app.json`: one line of at most 100 printable characters (`isFamilyName`), else it's no name: a stored one reads as null, a listed one is left out. A menu also leaves out the Mac's private families (a dot first). A name is only shown and given to the text engine as a family to look for.
- **The lists come through `Native.fonts`** (ADR 0097): `families()` beside `monospaced()`, and `system`, the name of the system's font where one reaches it. NSFontManager on the Mac, `fc-list : family` on Linux.
- **The terminal keeps its own font** and default, and its bundled icon font. Its menu is the same widget, and its stored name is read by the same rule.
- **The phone keeps the bundled fonts**: its theme is made without the preferences, and a browser has no system fonts to name.
- **A theme's preview keeps them too**: the cards in Settings are small pictures laid out to the bundled fonts' measures, and what they show is a theme's colors.
- **The font menu is the app's `Menu`**, which already gives a list of more than ten a filter field, arrow keys and a scrolling list. One thing was missing for a list of hundreds, and is now every filtered menu's: it opens scrolled to the current row.
- **The chat's header folds sooner in a wider font.** Its row decides what folds from widths measured in the bundled font; it now measures how much wider the app's font sets the row's words and counts that much more (`headerFolds`' `wider`).

## Consequences
- Line height is 1.4 of the text's size whatever the font, so rows keep their heights. Widths don't: in a wide font, titles and rows are cut with an ellipsis sooner.
- Only the chat's header re-measures. Other rows still count on the bundled font's widths, and `wide_font_test.dart` holds the main window, a chat, Changes and every section of Settings to no overflow in JetBrains Mono at 1700 and 720, naming what's known and left: at 720, a server's row in Settings › MCP servers runs ten points past its end.
- A picked family that's no longer installed stays picked and listed ("not installed"), and its text is drawn in the bundled font meanwhile.
- The filtered menu builds every row (Flutter's menu is as wide as its widest row, so its list can't be built lazily without a fixed width): about 300 rows open in a third of a second in a debug test. Fine for a font menu; a longer list would want a fixed width and a lazy list.
- `flutter test` draws a family it hasn't loaded in its test font, not in the fallback: tests assert the families asked for, and renders use the fonts the app bundles.

## Alternatives considered
- `ui()` and `code()` reading the preferences themselves: nothing would rebuild on a pick, and the phone shares those widgets.
- Each family's name drawn in its own font in the menu: hundreds of fonts loaded to open a menu.
- The picked fonts in the theme previews: a wide one cuts the pictures' text, and a tall one overflows their fixed rows.
