import 'package:flutter/widgets.dart';

import 'package:nushi/theme/terminal_colors.dart';
import 'package:nushi/theme/tokens.dart';

// Catppuccin's palette (MIT; docs/development.md's Dependencies), on
// Nushi's tokens (ADR 0086): Mocha for the dark set and Latte for the
// light one, its style guide's roles (mauve the accent, overlay2
// comments) and its terminal colors. The surfaces (ADR 0111): crust the
// window and base the panes in both; Mocha's cards a tone between base
// and surface0, which is what's raised on them; Latte's cards mantle.
// Latte's inks are taken darker where they read under AA on a fill they
// sit on, keeping their hue.

/// Catppuccin's dark set.
const catppuccinDark = Tokens(
  brightness: Brightness.dark,
  window: Color(0xFF11111B),
  base: Color(0xFF1E1E2E),
  raised: Color(0xFF28293B),
  lifted: Color(0xFF313244),
  segment: Color(0xFF3B3C50),
  selected: Color(0xFF383A4F),
  text: Color(0xFFCDD6F4),
  textSecondary: Color(0xFFBAC2DE),
  textMuted: Color(0xFFA6ADC8),
  link: Color(0xFF89B4FA),
  onAccent: Color(0xFF11111B),
  fieldFill: Color(0xFF262637),
  fieldBorder: Color(0xFF45475A),
  fieldBorderHover: Color(0xFF585B70),
  grip: Color(0xFF7F849C),
  accent: Color(0xFFCBA6F7),
  accentSoft: Color(0xFF3A3254),
  accentInk: Color(0xFFCBA6F7),
  running: Color(0xFF89B4FA),
  needs: Color(0xFFF9E2AF),
  needsSoft: Color(0xFF3E3A3A),
  done: Color(0xFFA6E3A1),
  doneSoft: Color(0xFF2F3D35),
  idle: Color(0xFFA6ADC8),
  crashed: Color(0xFFF38BA8),
  crashedSoft: Color(0xFF45303D),
  shine: Color(0xFF9399B2),
  shineBand: Color(0xFFCDD6F4),
  userBand: Color(0xFF2F3352),
  userBandText: Color(0xFFCDD6F4),
  userBandMuted: Color(0xFFB4BEFE),
  userBandCode: Color(0x24FAB387),
  userBandCodeBlock: Color(0xFF262840),
  agentText: Color(0xFFCDD6F4),
  inlineCode: Color(0x1FFAB387),
  inlineCodeText: Color(0xFFFAB387),
  codeBlock: Color(0xFF181825),
  toolAccent: Color(0xFF94E2D5),
  subagentTint: Color(0xFF33294A),
  subagentAccent: Color(0xFFCBA6F7),
  findingsAccent: Color(0xFFF9E2AF),
  selectionBar: Color(0xFF313244),
  selectionBarText: Color(0xFFCDD6F4),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  claude: Color(0xFFD98A5F),
  ante: Color(0xFFE5A426),
  ompPlug: Color(0xFFF97316),
  pi: Color(0xFF4D9ABF),
  pig: Color(0xFFFFA8B7),
  monogramText: Color(0xFF11111B),
  avatars: [
    Color(0xFF89B4FA), // blue
    Color(0xFF94E2D5), // teal
    Color(0xFFCBA6F7), // violet
    Color(0xFFF9E2AF), // amber
    Color(0xFFFAB387), // rust
    Color(0xFFF5C2E7), // magenta
    Color(0xFF9399B2), // slate
    Color(0xFFA6E3A1), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFFCBA6F7)),
    Capture.declaration: CodeInk(Color(0xFF89B4FA)),
    Capture.type: CodeInk(Color(0xFFF9E2AF)),
    Capture.string: CodeInk(Color(0xFFA6E3A1)),
    Capture.number: CodeInk(Color(0xFFFAB387)),
    Capture.regexp: CodeInk(Color(0xFFF5C2E7)),
    Capture.constant: CodeInk(Color(0xFFFAB387), italic: true),
    Capture.field: CodeInk(Color(0xFFB4BEFE)),
    Capture.symbol: CodeInk(Color(0xFFF2CDCD)),
    Capture.parameter: CodeInk(Color(0xFFEBA0AC), italic: true),
    Capture.meta: CodeInk(Color(0xFFF9E2AF)),
    Capture.tag: CodeInk(Color(0xFF89B4FA)),
    Capture.comment: CodeInk(Color(0xFF9399B2), italic: true),
    Capture.docTag: CodeInk(Color(0xFFCBA6F7), italic: true, bold: true),
  },
  terminal: TerminalColors(
    black: Color(0xFF45475A),
    red: Color(0xFFF38BA8),
    green: Color(0xFFA6E3A1),
    yellow: Color(0xFFF9E2AF),
    blue: Color(0xFF89B4FA),
    magenta: Color(0xFFF5C2E7),
    cyan: Color(0xFF94E2D5),
    white: Color(0xFFBAC2DE),
    brightBlack: Color(0xFF585B70),
    brightRed: Color(0xFFF38BA8),
    brightGreen: Color(0xFFA6E3A1),
    brightYellow: Color(0xFFF9E2AF),
    brightBlue: Color(0xFF89B4FA),
    brightMagenta: Color(0xFFF5C2E7),
    brightCyan: Color(0xFF94E2D5),
    brightWhite: Color(0xFFA6ADC8),
  ),
);

/// Catppuccin's light set.
const catppuccinLight = Tokens(
  brightness: Brightness.light,
  window: Color(0xFFDCE0E8),
  base: Color(0xFFEFF1F5),
  raised: Color(0xFFE6E9EF),
  selected: Color(0xFFD5D9E1),
  text: Color(0xFF4C4F69),
  textSecondary: Color(0xFF54576E),
  textMuted: Color(0xFF54576D),
  link: Color(0xFF1454D2),
  onAccent: Color(0xFFFFFFFF),
  fieldFill: Color(0xFFEFF1F5),
  fieldBorder: Color(0xFFCCD0DA),
  fieldBorderHover: Color(0xFFACB0BE),
  grip: Color(0xFF8C8FA1),
  accent: Color(0xFF8839EF),
  accentSoft: Color(0xFFE2D2FF),
  accentInk: Color(0xFF7A2FD6),
  running: Color(0xFF1454D2),
  needs: Color(0xFF865202),
  needsSoft: Color(0xFFF5E6CF),
  done: Color(0xFF226D08),
  doneSoft: Color(0xFFD9ECD6),
  idle: Color(0xFF6C6F85),
  crashed: Color(0xFFBE0633),
  crashedSoft: Color(0xFFF6D9DF),
  shine: Color(0xFF7C7F93),
  shineBand: Color(0xFF4C4F69),
  userBand: Color(0xFFDCE2F6),
  userBandText: Color(0xFF4C4F69),
  userBandMuted: Color(0xFF3D55A8),
  userBandCode: Color(0x1FFE640B),
  userBandCodeBlock: Color(0xFFE8ECF8),
  agentText: Color(0xFF4C4F69),
  inlineCode: Color(0x1AFE640B),
  inlineCodeText: Color(0xFF963A03),
  codeBlock: Color(0xFFDFE3EA),
  toolAccent: Color(0xFF137A80),
  subagentTint: Color(0xFFE9E0F8),
  subagentAccent: Color(0xFF6D27C7),
  findingsAccent: Color(0xFF8A560A),
  selectionBar: Color(0xFF4C4F69),
  selectionBarText: Color(0xFFEFF1F5),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  claude: Color(0xFFB0582B),
  ante: Color(0xFF93640A),
  ompPlug: Color(0xFFB95008),
  pi: Color(0xFF2B769E),
  pig: Color(0xFFC24A64),
  monogramText: Color(0xFFFFFFFF),
  hover: Color(0x1C4C4F69),
  pressed: Color(0x2A4C4F69),
  avatars: [
    Color(0xFF1A5AD8), // blue
    Color(0xFF137A80), // teal
    Color(0xFF7A2FD6), // violet
    Color(0xFF8F5A0C), // amber
    Color(0xFFC14A0A), // rust
    Color(0xFFB43D97), // magenta
    Color(0xFF6C6F85), // slate
    Color(0xFF2F7A1F), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFF8635ED)),
    Capture.declaration: CodeInk(Color(0xFF135CEB)),
    Capture.type: CodeInk(Color(0xFF955B04)),
    Capture.string: CodeInk(Color(0xFF2C7808)),
    Capture.number: CodeInk(Color(0xFFB04805)),
    Capture.regexp: CodeInk(Color(0xFFAE3A8F)),
    Capture.constant: CodeInk(Color(0xFFB04805), italic: true),
    Capture.field: CodeInk(Color(0xFF485DD3)),
    Capture.symbol: CodeInk(Color(0xFFAD4848)),
    Capture.parameter: CodeInk(Color(0xFFCC1A39), italic: true),
    Capture.meta: CodeInk(Color(0xFF955B04)),
    Capture.tag: CodeInk(Color(0xFF135CEB)),
    Capture.comment: CodeInk(Color(0xFF7C7F93), italic: true),
    Capture.docTag: CodeInk(Color(0xFF8839EF), italic: true, bold: true),
  },
  terminal: TerminalColors(
    black: Color(0xFF5C5F77),
    red: Color(0xFFD20F39),
    green: Color(0xFF3D9D25),
    yellow: Color(0xFFC27A02),
    blue: Color(0xFF1E66F5),
    magenta: Color(0xFFD35FB4),
    cyan: Color(0xFF179299),
    white: Color(0xFFACB0BE),
    brightBlack: Color(0xFF6C6F85),
    brightRed: Color(0xFFD20F39),
    brightGreen: Color(0xFF3D9D25),
    brightYellow: Color(0xFFC27A02),
    brightBlue: Color(0xFF1E66F5),
    brightMagenta: Color(0xFFD35FB4),
    brightCyan: Color(0xFF179299),
    brightWhite: Color(0xFFBCC0CC),
  ),
);
