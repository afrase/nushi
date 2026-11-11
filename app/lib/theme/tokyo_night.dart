import 'package:flutter/widgets.dart';

import 'package:nushi/theme/diff_colors.dart';
import 'package:nushi/theme/terminal_colors.dart';
import 'package:nushi/theme/tokens.dart';

// Tokyo Night as the tools that ship it draw it (ADR 0086): Night for the
// dark set and Day for the light one, both from folke's tokyonight.nvim
// (Apache-2.0; docs/development.md's Dependencies), whose colors kitty,
// Ghostty, WezTerm and iTerm2's schemes carry under those names. What
// the theme is known by is as published: the background (bg, the panes),
// the side bar's (bg_dark, the window and code's surface), the text of
// the transcript, code, diffs and the terminal (fg), comments, the
// selection (bg_visual), code's colors by tokyonight's own groups, its
// diff's fills and the terminal's sixteen. Code's and the terminal's
// colors are not held to Nushi's contrast floors (`published_colors_test`).
//
// Nushi's own roles pick from the same palette. Night: the cards are the
// VS Code theme's selected row (#202330, enkia's, MIT), what's raised on
// them bg_highlight, the picked segment fg_gutter, the muted text its
// #9AA5CE; blue is the accent, links and what runs, yellow waits, green
// is done, red failed, magenta a subagent's, teal a tool call's, orange
// inline code. Day reads under AA nearly everywhere but in its editor
// (fg is 4.52:1 on bg; nothing in it passes on bg_dark), so there Nushi's
// labels, links and state words are the palette's inks taken darker,
// hue and saturation kept, each the least that holds AA on every fill it
// sits on (`tokens_test`); the list is ADR 0086's. Where a darker ink of
// the palette passes, it is used as it is: fg is the accent's fill (white
// on blue is 4.0:1) and the blue chat color, green1 a tool call's mark,
// purple and blue5 chat colors.

/// Tokyo Night’s dark set: Night (tokyonight.nvim's `night`).
const tokyoNightDark = Tokens(
  brightness: Brightness.dark,
  window: Color(0xFF16161E),
  base: Color(0xFF1A1B26),
  raised: Color(0xFF202330),
  lifted: Color(0xFF292E42),
  segment: Color(0xFF3B4261),
  selected: Color(0xFF2E344B),
  text: Color(0xFFC0CAF5),
  textSecondary: Color(0xFFA9B1D6),
  textMuted: Color(0xFF9AA5CE),
  link: Color(0xFF7AA2F7),
  onAccent: Color(0xFF16161E),
  fieldFill: Color(0xFF14141B),
  fieldBorder: Color(0xFF3B4261),
  fieldBorderHover: Color(0xFF545C7E),
  grip: Color(0xFF565F89),
  accent: Color(0xFF7AA2F7),
  accentSoft: Color(0xFF283457),
  accentInk: Color(0xFF7AA2F7),
  running: Color(0xFF7AA2F7),
  needs: Color(0xFFE0AF68),
  needsSoft: Color(0xFF423933),
  done: Color(0xFF9ECE6A),
  doneSoft: Color(0xFF323B32),
  idle: Color(0xFF9AA5CE),
  crashed: Color(0xFFF7768E),
  crashedSoft: Color(0xFF4A272F),
  shine: Color(0xFF8690B8),
  shineBand: Color(0xFFC0CAF5),
  userBand: Color(0xFF283457),
  userBandText: Color(0xFFC0CAF5),
  userBandMuted: Color(0xFFA9B1D6),
  userBandCode: Color(0x24FF9E64),
  userBandCodeBlock: Color(0xFF21283F),
  agentText: Color(0xFFC0CAF5),
  inlineCode: Color(0x1FFF9E64),
  inlineCodeText: Color(0xFFFF9E64),
  codeBlock: Color(0xFF16161E),
  toolAccent: Color(0xFF1ABC9C),
  subagentTint: Color(0xFF37324C),
  subagentAccent: Color(0xFFBB9AF7),
  findingsAccent: Color(0xFFE0AF68),
  selectionBar: Color(0xFF292E42),
  selectionBarText: Color(0xFFC0CAF5),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  claude: Color(0xFFD98759),
  ante: Color(0xFFE5A426),
  ompPlug: Color(0xFFF97316),
  pi: Color(0xFF4D9ABF),
  pig: Color(0xFFFFA8B7),
  monogramText: Color(0xFF16161E),
  avatars: [
    Color(0xFF7AA2F7), // blue
    Color(0xFF1ABC9C), // teal
    Color(0xFFBB9AF7), // violet
    Color(0xFFE0AF68), // amber
    Color(0xFFFF9E64), // rust
    Color(0xFFF7768E), // magenta
    Color(0xFF9AA5CE), // slate
    Color(0xFF9ECE6A), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFFBB9AF7)),
    Capture.declaration: CodeInk(Color(0xFF7AA2F7)),
    Capture.type: CodeInk(Color(0xFF2AC3DE)),
    Capture.string: CodeInk(Color(0xFF9ECE6A)),
    Capture.number: CodeInk(Color(0xFFFF9E64)),
    Capture.regexp: CodeInk(Color(0xFFB4F9F8)),
    Capture.constant: CodeInk(Color(0xFFFF9E64), italic: true),
    Capture.field: CodeInk(Color(0xFF73DACA)),
    Capture.symbol: CodeInk(Color(0xFF89DDFF)),
    Capture.parameter: CodeInk(Color(0xFFE0AF68), italic: true),
    Capture.meta: CodeInk(Color(0xFF7DCFFF)),
    Capture.tag: CodeInk(Color(0xFFF7768E)),
    Capture.comment: CodeInk(Color(0xFF565F89), italic: true),
    Capture.docTag: CodeInk(Color(0xFFBB9AF7), italic: true, bold: true),
  },
  terminal: TerminalColors(
    black: Color(0xFF15161E),
    red: Color(0xFFF7768E),
    green: Color(0xFF9ECE6A),
    yellow: Color(0xFFE0AF68),
    blue: Color(0xFF7AA2F7),
    magenta: Color(0xFFBB9AF7),
    cyan: Color(0xFF7DCFFF),
    white: Color(0xFFA9B1D6),
    brightBlack: Color(0xFF414868),
    brightRed: Color(0xFFFF899D),
    brightGreen: Color(0xFF9FE044),
    brightYellow: Color(0xFFFABA4A),
    brightBlue: Color(0xFF8DB0FF),
    brightMagenta: Color(0xFFC7A9FF),
    brightCyan: Color(0xFFA4DAFF),
    brightWhite: Color(0xFFC0CAF5),
  ),
  diff: DiffColors(
    background: Color(0xFF1A1B26),
    text: Color(0xFFC0CAF5),
    gutterBackground: Color(0xFF1A1B26),
    gutterText: Color(0xFF737AA2),
    gutterTextChanged: Color(0xFFA9B1D6),
    insertedLine: Color(0xFF243E4A),
    insertedWord: Color(0xFF2F5F6C),
    deletedLine: Color(0xFF4A272F),
    deletedWord: Color(0xFF63343C),
    modifiedLine: Color(0xFF1F2231),
    modifiedWord: Color(0xFF394B70),
    ribbonInserted: Color(0xFF284B58),
    ribbonDeleted: Color(0xFF542C34),
    ribbonModified: Color(0xFF29324A),
    dividerBackground: Color(0xFF1A1B26),
    selection: Color(0x663D59A1),
    selectionOverCap: Color(0x66E0AF68),
    foldPlaceholderBackground: Color(0xFF292E42),
    foldPlaceholderText: Color(0xFF737AA2),
    loadingBar: Color(0xFF292E42),
    hoverAffordance: Color(0xFF7AA2F7),
  ),
);

/// Tokyo Night’s light set: Day (tokyonight.nvim's `day`).
const tokyoNightLight = Tokens(
  brightness: Brightness.light,
  window: Color(0xFFD0D5E3),
  base: Color(0xFFE1E2E7),
  raised: Color(0xFFD8DCE5),
  lifted: Color(0xFFC1C9DF),
  selected: Color(0xFFC4C8DA),
  text: Color(0xFF294890),
  textSecondary: Color(0xFF404D7F),
  textMuted: Color(0xFF494E6C),
  link: Color(0xFF114DA0),
  onAccent: Color(0xFFE1E2E7),
  fieldFill: Color(0xFFE1E2E7),
  fieldBorder: Color(0xFFA8AECB),
  fieldBorderHover: Color(0xFF8990B3),
  grip: Color(0xFF848CB5),
  accent: Color(0xFF3760BF),
  accentSoft: Color(0xFFB7C1E3),
  accentInk: Color(0xFF114DA0),
  running: Color(0xFF114DA0),
  needs: Color(0xFF634C2C),
  needsSoft: Color(0xFFD2CDC9),
  done: Color(0xFF41562A),
  doneSoft: Color(0xFFC8CEC8),
  idle: Color(0xFF494E6C),
  crashed: Color(0xFF912C2C),
  crashedSoft: Color(0xFFDABABE),
  shine: Color(0xFF68709A),
  shineBand: Color(0xFF294890),
  userBand: Color(0xFFB7C1E3),
  userBandText: Color(0xFF294890),
  userBandMuted: Color(0xFF3A4673),
  userBandCode: Color(0x1AB15C00),
  userBandCodeBlock: Color(0xFFCCD2E5),
  agentText: Color(0xFF3760BF),
  inlineCode: Color(0x1AB15C00),
  inlineCodeText: Color(0xFF723B00),
  codeBlock: Color(0xFFD0D5E3),
  toolAccent: Color(0xFF387068),
  subagentTint: Color(0xFFD7CEE8),
  subagentAccent: Color(0xFF63399E),
  findingsAccent: Color(0xFF634C2C),
  selectionBar: Color(0xFF294890),
  selectionBarText: Color(0xFFE1E2E7),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  claude: Color(0xFFA75329),
  ante: Color(0xFF8F610A),
  ompPlug: Color(0xFFB14C09),
  pi: Color(0xFF2B7196),
  pig: Color(0xFFB93E59),
  monogramText: Color(0xFFE1E2E7),
  hover: Color(0x1C294890),
  pressed: Color(0x2D294890),
  avatars: [
    Color(0xFF3760BF), // blue
    Color(0xFF006A83), // teal
    Color(0xFF7847BD), // violet
    Color(0xFF84653A), // amber
    Color(0xFFA45500), // rust
    Color(0xFFD10065), // magenta
    Color(0xFF616891), // slate
    Color(0xFF577338), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFF9854F1)),
    Capture.declaration: CodeInk(Color(0xFF2E7DE9)),
    Capture.type: CodeInk(Color(0xFF188092)),
    Capture.string: CodeInk(Color(0xFF587539)),
    Capture.number: CodeInk(Color(0xFFB15C00)),
    Capture.regexp: CodeInk(Color(0xFF2E5857)),
    Capture.constant: CodeInk(Color(0xFFB15C00), italic: true),
    Capture.field: CodeInk(Color(0xFF387068)),
    Capture.symbol: CodeInk(Color(0xFF006A83)),
    Capture.parameter: CodeInk(Color(0xFF8C6C3E), italic: true),
    Capture.meta: CodeInk(Color(0xFF007197)),
    Capture.tag: CodeInk(Color(0xFFF52A65)),
    Capture.comment: CodeInk(Color(0xFF848CB5), italic: true),
    Capture.docTag: CodeInk(Color(0xFF9854F1), italic: true, bold: true),
  },
  terminal: TerminalColors(
    foreground: Color(0xFF3760BF),
    black: Color(0xFFB4B5B9),
    red: Color(0xFFF52A65),
    green: Color(0xFF587539),
    yellow: Color(0xFF8C6C3E),
    blue: Color(0xFF2E7DE9),
    magenta: Color(0xFF9854F1),
    cyan: Color(0xFF007197),
    white: Color(0xFF6172B0),
    brightBlack: Color(0xFFA1A6C5),
    brightRed: Color(0xFFFF4774),
    brightGreen: Color(0xFF5C8524),
    brightYellow: Color(0xFFA27629),
    brightBlue: Color(0xFF358AFF),
    brightMagenta: Color(0xFFA463FF),
    brightCyan: Color(0xFF007EA8),
    brightWhite: Color(0xFF3760BF),
  ),
  diff: DiffColors(
    background: Color(0xFFE1E2E7),
    text: Color(0xFF3760BF),
    gutterBackground: Color(0xFFE1E2E7),
    gutterText: Color(0xFF68709A),
    gutterTextChanged: Color(0xFF3760BF),
    insertedLine: Color(0xFFB7CED5),
    insertedWord: Color(0xFF8EBBC4),
    deletedLine: Color(0xFFDABABE),
    deletedWord: Color(0xFFD2A3A9),
    modifiedLine: Color(0xFFD5D9E4),
    modifiedWord: Color(0xFF92A6D5),
    ribbonInserted: Color(0xFFA7C6CE),
    ribbonDeleted: Color(0xFFD7B1B6),
    ribbonModified: Color(0xFFBAC5DE),
    dividerBackground: Color(0xFFE1E2E7),
    selection: Color(0x667890DD),
    selectionOverCap: Color(0x668C6C3E),
    foldPlaceholderBackground: Color(0xFFC4C8DA),
    foldPlaceholderText: Color(0xFF494E6C),
    loadingBar: Color(0xFFC4C8DA),
    hoverAffordance: Color(0xFF114DA0),
  ),
);
