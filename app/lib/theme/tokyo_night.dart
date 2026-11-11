import 'package:flutter/widgets.dart';

import 'package:nushi/theme/terminal_colors.dart';
import 'package:nushi/theme/tokens.dart';

// Tokyo Night, enkia's palette (MIT) and folke's tokyonight.nvim, which
// names its colors (Apache-2.0; docs/development.md's Dependencies), on
// Nushi's tokens (ADR 0086): Night for the dark set and the VS Code
// theme's Light for the light one. Blue is the accent, links and what
// runs; yellow waits, green is done, red failed; magenta is a subagent's,
// teal a tool call's, orange inline code. The surfaces (ADR 0111): dark,
// bg_dark the window and code's surface, bg the panes, VS Code's selected
// row the cards, bg_highlight what's raised on them and fg_gutter the
// picked segment; light, the side bar's fill the window and code's
// surface, the editor's the panes and its current line's, a step lighter,
// the cards. Night's comment (2.8:1 on bg) is a grip's dots; code's
// comments are dark5. The soft fills behind a state are its ink mixed
// into the pane's, but for Night's failed one (tokyonight's diff.delete)
// and the accent's (bg_visual; Light's is its table ink, #C0CEFC). Light's
// inks are taken darker where they read under AA on a fill they sit on,
// keeping their hue (`tokens_test`).

/// Tokyo Night’s dark set: Night.
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
    Color(0xFF757CA3), // slate
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
    Capture.comment: CodeInk(Color(0xFF737AA2), italic: true),
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
);

/// Tokyo Night’s light set: Light.
const tokyoNightLight = Tokens(
  brightness: Brightness.light,
  window: Color(0xFFD6D8DF),
  base: Color(0xFFE6E7ED),
  raised: Color(0xFFDDDFE4),
  lifted: Color(0xFFD3D5DC),
  selected: Color(0xFFCCD0DC),
  text: Color(0xFF343B58),
  textSecondary: Color(0xFF40434F),
  textMuted: Color(0xFF4A5272),
  link: Color(0xFF2856A5),
  onAccent: Color(0xFFFFFFFF),
  fieldFill: Color(0xFFE6E7ED),
  fieldBorder: Color(0xFFC1C2C7),
  fieldBorderHover: Color(0xFF9DA0AB),
  grip: Color(0xFF888B94),
  accent: Color(0xFF2959AA),
  accentSoft: Color(0xFFC0CEFC),
  accentInk: Color(0xFF2856A5),
  running: Color(0xFF2856A5),
  needs: Color(0xFF7A5012),
  needsSoft: Color(0xFFD7D0C8),
  done: Color(0xFF385F0D),
  doneSoft: Color(0xFFCAD1C9),
  idle: Color(0xFF4A5272),
  crashed: Color(0xFF942F2F),
  crashedSoft: Color(0xFFD9CACF),
  shine: Color(0xFF5A607D),
  shineBand: Color(0xFF343B58),
  userBand: Color(0xFFC0CEFC),
  userBandText: Color(0xFF343B58),
  userBandMuted: Color(0xFF0F4B6E),
  userBandCode: Color(0x1F965027),
  userBandCodeBlock: Color(0xFFD7DDF3),
  agentText: Color(0xFF343B58),
  inlineCode: Color(0x1A965027),
  inlineCodeText: Color(0xFF79401F),
  codeBlock: Color(0xFFD6D8DF),
  toolAccent: Color(0xFF33635C),
  subagentTint: Color(0xFFD2CFE0),
  subagentAccent: Color(0xFF5A3E8E),
  findingsAccent: Color(0xFF7A5012),
  selectionBar: Color(0xFF343B58),
  selectionBarText: Color(0xFFE6E7ED),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  claude: Color(0xFFAE572B),
  ante: Color(0xFF93640A),
  ompPlug: Color(0xFFB95008),
  pi: Color(0xFF2B769E),
  pig: Color(0xFFC0435E),
  monogramText: Color(0xFFFFFFFF),
  hover: Color(0x19343B58),
  pressed: Color(0x2A343B58),
  avatars: [
    Color(0xFF2959AA), // blue
    Color(0xFF33635C), // teal
    Color(0xFF7B43BA), // violet
    Color(0xFF8F5E15), // amber
    Color(0xFF965027), // rust
    Color(0xFF8C4351), // magenta
    Color(0xFF5A607D), // slate
    Color(0xFF385F0D), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFF65359D)),
    Capture.declaration: CodeInk(Color(0xFF2959AA)),
    Capture.type: CodeInk(Color(0xFF006780)),
    Capture.string: CodeInk(Color(0xFF385F0D)),
    Capture.number: CodeInk(Color(0xFF904D26)),
    Capture.regexp: CodeInk(Color(0xFF3C6564)),
    Capture.constant: CodeInk(Color(0xFF904D26), italic: true),
    Capture.field: CodeInk(Color(0xFF33635C)),
    Capture.symbol: CodeInk(Color(0xFF0F4B6E)),
    Capture.parameter: CodeInk(Color(0xFF825513), italic: true),
    Capture.meta: CodeInk(Color(0xFF0F4B6E)),
    Capture.tag: CodeInk(Color(0xFF8C4351)),
    Capture.comment: CodeInk(Color(0xFF6C6E75), italic: true),
    Capture.docTag: CodeInk(Color(0xFF65359D), italic: true, bold: true),
  },
  terminal: TerminalColors(
    black: Color(0xFF343B58),
    red: Color(0xFF8C4351),
    green: Color(0xFF33635C),
    yellow: Color(0xFF8F5E15),
    blue: Color(0xFF2959AA),
    magenta: Color(0xFF7B43BA),
    cyan: Color(0xFF006C86),
    white: Color(0xFF707280),
    brightBlack: Color(0xFF343B58),
    brightRed: Color(0xFF8C4351),
    brightGreen: Color(0xFF33635C),
    brightYellow: Color(0xFF8F5E15),
    brightBlue: Color(0xFF2959AA),
    brightMagenta: Color(0xFF7B43BA),
    brightCyan: Color(0xFF006C86),
    brightWhite: Color(0xFF707280),
  ),
);
