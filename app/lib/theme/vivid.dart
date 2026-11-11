import 'package:flutter/widgets.dart';

import 'package:nushi/theme/diff_colors.dart';
import 'package:nushi/theme/tokens.dart';

// Vivid: Nushi's palette a step bolder than its Clearer step (commit
// a95daedd, which the owner tried beside it): selection and the open
// chat clearly blue, the tool, subagent and findings tints and the user
// band plainly tinted, the status softs solid, borders and hover a step
// further. Inline code's orange is taken a step further from its chip
// than Nushi's, to hold AA on these stronger fills (`code_ink_test`). Its
// surfaces are Nushi's (ADR 0111), its light cards a shade lighter, where
// its stronger hover still leaves a row's text AA.

/// Vivid's light set.
const vividLight = Tokens(
  brightness: Brightness.light,
  window: Color(0xFFECEEF2),
  base: Color(0xFFFFFFFF),
  raised: Color(0xFFF7F8FA),
  lifted: Color(0xFFE6E8ED),
  segment: Color(0xFFFFFFFF),
  selected: Color(0xFFD6E0F3),
  borderSubtle: Color(0xFFDCDEE3),
  borderStrong: Color(0xFFB0B4C1),
  text: Color(0xFF1E1F22),
  textSecondary: Color(0xFF494B57),
  textMuted: Color(0xFF575B68),
  link: Color(0xFF2259D2),
  onAccent: Color(0xFFFFFFFF),
  fieldFill: Color(0xFFFFFFFF),
  fieldBorder: Color(0xFFB9BDC8),
  fieldBorderHover: Color(0xFF9498A5),
  grip: Color(0xFF8A8E9B),
  accent: Color(0xFF2365EA),
  accentSoft: Color(0xFFCADFFF),
  accentInk: Color(0xFF2259D2),
  running: Color(0xFF2259D2),
  needs: Color(0xFF8F5200),
  needsSoft: Color(0xFFFAE0B1),
  done: Color(0xFF1B7031),
  doneSoft: Color(0xFFC7EAD0),
  idle: Color(0xFF5D6170),
  crashed: Color(0xFFB62B39),
  crashedSoft: Color(0xFFFFD4D9),
  shine: Color(0xFF6E727E),
  shineBand: Color(0xFF1E1F22),
  userBand: Color(0xFFCDE0FF),
  userBandBorder: Color(0xFF93B2F2),
  userBandText: Color(0xFF142A5C),
  userBandMuted: Color(0xFF3A5594),
  userBandCode: Color(0x1A8D4100),
  userBandCodeBlock: Color(0xFFF5F8FE),
  agentText: Color(0xFF1E1F22),
  inlineCode: Color(0x1A8D4100),
  inlineCodeText: Color(0xFF7F3C03),
  codeBlock: Color(0xFFF0F2F5),
  toolTint: Color(0xFFC6EEE7),
  toolBorder: Color(0xFF8ACBC0),
  toolAccent: Color(0xFF0E8577),
  subagentTint: Color(0xFFE7DAFF),
  subagentBorder: Color(0xFFBEA8EE),
  subagentAccent: Color(0xFF4E1FA8),
  findingsTint: Color(0xFFF9E4C2),
  findingsBorder: Color(0xFFDCBA7B),
  findingsAccent: Color(0xFF8A5300),
  selectionBar: Color(0xFF26272B),
  selectionBarText: Color(0xFFE8E9EC),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  stop: Color(0xFFD0303F),
  onStop: Color(0xFFFFFFFF),
  claude: Color(0xFFB0582B),
  ante: Color(0xFF93640A),
  ompPlug: Color(0xFFC2540A),
  pi: Color(0xFF2F7DA6),
  pig: Color(0xFFC24A64),
  monogramText: Color(0xFFFFFFFF),
  avatars: [
    Color(0xFF2A5CC8), // blue
    Color(0xFF0E7A6D), // teal
    Color(0xFF6A3FC4), // violet
    Color(0xFF8A5300), // amber
    Color(0xFFA9512A), // rust
    Color(0xFFA23C83), // magenta
    Color(0xFF4E6D8C), // slate
    Color(0xFF4A7526), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFF0033B3)),
    Capture.declaration: CodeInk(Color(0xFF00627A)),
    Capture.type: CodeInk(Color(0xFF007E8A)),
    Capture.string: CodeInk(Color(0xFF067D17)),
    Capture.number: CodeInk(Color(0xFF1750EB)),
    Capture.regexp: CodeInk(Color(0xFF264EFF)),
    Capture.constant: CodeInk(Color(0xFF871094), italic: true),
    Capture.field: CodeInk(Color(0xFF871094)),
    Capture.symbol: CodeInk(Color(0xFF4E6D8C)),
    Capture.parameter: CodeInk(Color(0xFFC37522), italic: true),
    Capture.meta: CodeInk(Color(0xFF9E880D)),
    Capture.tag: CodeInk(Color(0xFF0033B3)),
    Capture.comment: CodeInk(Color(0xFF8C8C8C), italic: true),
    // JetBrains underlines it; nothing here can.
    Capture.docTag: CodeInk(Color(0xFF8C8C8C), italic: true, bold: true),
  },
  hover: Color.from(
    alpha: 0.12,
    red: 0x1E / 255,
    green: 0x1F / 255,
    blue: 0x22 / 255,
  ),
  pressed: Color.from(
    alpha: 0.19,
    red: 0x1E / 255,
    green: 0x1F / 255,
    blue: 0x22 / 255,
  ),
  diff: DiffColors.intelliJLight,
);

/// Vivid's dark set.
const vividDark = Tokens(
  brightness: Brightness.dark,
  window: Color(0xFF131417),
  base: Color(0xFF1B1C20),
  raised: Color(0xFF24262B),
  lifted: Color(0xFF2F3138),
  segment: Color(0xFF383B43),
  selected: Color(0xFF2C3951),
  borderSubtle: Color(0xFF494C52),
  borderStrong: Color(0xFF62666E),
  text: Color(0xFFDFE1E5),
  textSecondary: Color(0xFFB4B8BF),
  textMuted: Color(0xFFAAAEB6),
  link: Color(0xFF7BA9FF),
  onAccent: Color(0xFFFFFFFF),
  fieldFill: Color(0xFF313338),
  fieldBorder: Color(0xFF5E6269),
  fieldBorderHover: Color(0xFF7C8089),
  grip: Color(0xFF80848C),
  accent: Color(0xFF2365EA),
  accentSoft: Color(0xFF1D346B),
  accentInk: Color(0xFF7BA9FF),
  running: Color(0xFF7BA9FF),
  needs: Color(0xFFF1AE3E),
  needsSoft: Color(0xFF4A3507),
  done: Color(0xFF64CC6C),
  doneSoft: Color(0xFF1C422A),
  idle: Color(0xFFA2A6AE),
  crashed: Color(0xFFFF858F),
  crashedSoft: Color(0xFF581F28),
  shine: Color(0xFF9DA1AA),
  shineBand: Color(0xFFF4F6FA),
  userBand: Color(0xFF1E3665),
  userBandBorder: Color(0xFF405FAA),
  userBandText: Color(0xFFE8EEFB),
  userBandMuted: Color(0xFF9DB8F5),
  userBandCode: Color(0x1FF5AD66),
  userBandCodeBlock: Color(0xFF1A2338),
  agentText: Color(0xFFDFE1E5),
  inlineCode: Color(0x1FF5AD66),
  inlineCodeText: Color(0xFFFEB874),
  codeBlock: Color(0xFF151619),
  toolTint: Color(0xFF083C37),
  toolBorder: Color(0xFF206761),
  toolAccent: Color(0xFF3AA597),
  subagentTint: Color(0xFF342958),
  subagentBorder: Color(0xFF634F9C),
  subagentAccent: Color(0xFFD2BEFF),
  findingsTint: Color(0xFF3F3116),
  findingsBorder: Color(0xFF6C552C),
  findingsAccent: Color(0xFFE6B062),
  selectionBar: Color(0xFF26272B),
  selectionBarText: Color(0xFFE8E9EC),
  selectionBarBorder: Color(0x22FFFFFF),
  selectionBarDivider: Color(0x33FFFFFF),
  shadow: Color(0x33000000),
  scrim: Color(0xDD000000),
  stop: Color(0xFFD0303F),
  onStop: Color(0xFFFFFFFF),
  claude: Color(0xFFD98A5F),
  ante: Color(0xFFE5A426),
  ompPlug: Color(0xFFF97316),
  pi: Color(0xFF4D9ABF),
  pig: Color(0xFFFFA8B7),
  monogramText: Color(0xFF1E1F22),
  avatars: [
    Color(0xFF7AA3F9), // blue
    Color(0xFF4DB6A8), // teal
    Color(0xFFB79CF5), // violet
    Color(0xFFE6B062), // amber
    Color(0xFFE0956A), // rust
    Color(0xFFE48BC4), // magenta
    Color(0xFF9DB4C0), // slate
    Color(0xFF9CC572), // green
  ],
  syntax: {
    Capture.keyword: CodeInk(Color(0xFFCF8E6D)),
    Capture.declaration: CodeInk(Color(0xFF56A8F5)),
    Capture.type: CodeInk(Color(0xFF16BAAC)),
    Capture.string: CodeInk(Color(0xFF6AAB73)),
    Capture.number: CodeInk(Color(0xFF2AACB8)),
    Capture.regexp: CodeInk(Color(0xFF42C3D4)),
    Capture.constant: CodeInk(Color(0xFFC77DBB), italic: true),
    Capture.field: CodeInk(Color(0xFFC77DBB)),
    Capture.symbol: CodeInk(Color(0xFF89A6AF)),
    Capture.parameter: CodeInk(Color(0xFFD4B01D), italic: true),
    Capture.meta: CodeInk(Color(0xFFB3AE60)),
    Capture.tag: CodeInk(Color(0xFFD5B778)),
    Capture.comment: CodeInk(Color(0xFF7A7E85)),
    Capture.docTag: CodeInk(Color(0xFF67A37C)),
  },
  hover: Color.from(
    alpha: 0.1,
    red: 0xDF / 255,
    green: 0xE1 / 255,
    blue: 0xE5 / 255,
  ),
  pressed: Color.from(
    alpha: 0.17,
    red: 0xDF / 255,
    green: 0xE1 / 255,
    blue: 0xE5 / 255,
  ),
  diff: DiffColors.darcula,
);
