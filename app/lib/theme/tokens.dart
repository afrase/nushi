import 'package:flutter/widgets.dart';

/// The kinds of code that take a color of their own, in diffs and code
/// blocks; `syntax.dart` says which highlight.js scopes are which.
enum Capture {
  keyword, // and literals (nil, true), self and this, built-ins, escapes
  declaration, // a function's, method's or class's name where it's declared
  type,
  string,
  number,
  regexp,
  constant,
  field, // instance and class variables, properties, keys
  symbol,
  parameter,
  meta, // annotations, decorators, attributes
  tag, // markup's tags and CSS selectors
  comment,
  docTag, // @param, @return in a comment
}

/// How a [Capture] looks.
@immutable
class CodeInk {
  const new(this.color, {this.italic = false, this.bold = false});

  final Color color;
  final bool italic;
  final bool bold;
}

/// The POC's Workbench colors for one brightness. Code's colors are
/// JetBrains' New UI Dark and Light schemes' (RubyMine's for symbols and
/// parameters, which the platform leaves plain).
@immutable
class Tokens {
  const new({
    required this.brightness,
    required this.base,
    required this.raised,
    required this.selected,
    required this.borderSubtle,
    required this.borderStrong,
    required this.focus,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.link,
    required this.onAccent,
    required this.accent,
    required this.accentSoft,
    required this.running,
    required this.needs,
    required this.needsSoft,
    required this.done,
    required this.idle,
    required this.crashed,
    required this.crashedSoft,
    required this.userBand,
    required this.userBandBorder,
    required this.userBandText,
    required this.userBandMuted,
    required this.userBandCode,
    required this.userBandCodeBlock,
    required this.agentText,
    required this.inlineCode,
    required this.codeBlock,
    required this.toolTint,
    required this.toolBorder,
    required this.toolAccent,
    required this.subagentTint,
    required this.subagentBorder,
    required this.subagentAccent,
    required this.selectionBar,
    required this.selectionBarText,
    required this.selectionBarBorder,
    required this.selectionBarDivider,
    required this.shadow,
    required this.scrim,
    required this.claude,
    required this.monogramText,
    required this.syntax,
  });

  final Brightness brightness;

  // Surfaces: the page, panels and bars, and a selected row.
  final Color base;
  final Color raised;
  final Color selected;

  final Color borderSubtle;
  final Color borderStrong;
  final Color focus;

  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color link;
  final Color onAccent;

  final Color accent;
  final Color accentSoft;

  // Status: a running chat, one that needs the user, done, idle, failed.
  final Color running;
  final Color needs;
  final Color needsSoft;
  final Color done;
  final Color idle;
  final Color crashed;
  final Color crashedSoft;

  // The transcript. A user message is a band across it (the chapter's
  // heading), with its marker (a relay's), its inline code and code
  // blocks; the agent's text and inline code; a tool call's row and a
  // subagent's line, each a tint with an accent for its icon; the bar
  // over a selection; and the scrim behind an image opened whole.
  final Color userBand;
  final Color userBandBorder;
  final Color userBandText;
  final Color userBandMuted;
  final Color userBandCode;
  final Color userBandCodeBlock;
  final Color agentText;
  final Color inlineCode;
  final Color codeBlock;
  final Color toolTint;
  final Color toolBorder;
  final Color toolAccent;
  final Color subagentTint;
  final Color subagentBorder;
  final Color subagentAccent;
  final Color selectionBar;
  final Color selectionBarText;
  final Color selectionBarBorder;
  final Color selectionBarDivider;
  final Color shadow;
  final Color scrim;

  // Claude's color, and the letter on an agent's monogram.
  final Color claude;
  final Color monogramText;

  /// Code's colors, in diffs and code blocks, by [Capture].
  final Map<Capture, CodeInk> syntax;

  /// How [c] looks.
  CodeInk ink(Capture c) => syntax[c]!;

  /// The tint of a row or button under the pointer.
  Color get hover => text.withValues(alpha: 0.06);

  static const light = Tokens(
    brightness: Brightness.light,
    base: Color(0xFFFFFFFF),
    raised: Color(0xFFF7F8FA),
    selected: Color(0xFFE9EBF0),
    borderSubtle: Color(0xFFEBECF0),
    borderStrong: Color(0xFFC9CCD6),
    focus: Color(0xFF2F6AE0),
    text: Color(0xFF1E1F22),
    textSecondary: Color(0xFF494B57),
    textMuted: Color(0xFF5D6170),
    link: Color(0xFF2A5CC8),
    onAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF2F6AE0),
    accentSoft: Color(0xFFE5EDFC),
    running: Color(0xFF2A5CC8),
    needs: Color(0xFF8F5200),
    needsSoft: Color(0xFFFBF0DC),
    done: Color(0xFF1B7031),
    idle: Color(0xFF5D6170),
    crashed: Color(0xFFB62B39),
    crashedSoft: Color(0xFFFCE8EA),
    userBand: Color(0xFFE5EDFC),
    userBandBorder: Color(0xFFB8CCF4),
    userBandText: Color(0xFF142A5C),
    userBandMuted: Color(0xFF3A5594),
    userBandCode: Color(0x14142A5C),
    userBandCodeBlock: Color(0xFFF5F8FE),
    agentText: Color(0xFF1E1F22),
    inlineCode: Color(0x121E1F22),
    codeBlock: Color(0xFFF7F8FA),
    toolTint: Color(0xFFEAF6F4),
    toolBorder: Color(0xFFBFE0DA),
    toolAccent: Color(0xFF0E8577),
    subagentTint: Color(0xFFF1ECFC),
    subagentBorder: Color(0xFFD6C9F5),
    subagentAccent: Color(0xFF4E1FA8),
    selectionBar: Color(0xFF26272B),
    selectionBarText: Color(0xFFE8E9EC),
    selectionBarBorder: Color(0x22FFFFFF),
    selectionBarDivider: Color(0x33FFFFFF),
    shadow: Color(0x33000000),
    scrim: Color(0xDD000000),
    claude: Color(0xFFB0582B),
    monogramText: Color(0xFFFFFFFF),
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
  );

  static const dark = Tokens(
    brightness: Brightness.dark,
    base: Color(0xFF1E1F22),
    raised: Color(0xFF2B2D30),
    selected: Color(0xFF33353A),
    borderSubtle: Color(0xFF393B40),
    borderStrong: Color(0xFF4E5157),
    focus: Color(0xFF2F6AE0),
    text: Color(0xFFDFE1E5),
    textSecondary: Color(0xFFB4B8BF),
    textMuted: Color(0xFFA2A6AE),
    link: Color(0xFF7AA3F9),
    onAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF2F6AE0),
    accentSoft: Color(0xFF26334F),
    running: Color(0xFF7AA3F9),
    needs: Color(0xFFE9AC4C),
    needsSoft: Color(0xFF3A3121),
    done: Color(0xFF6CC271),
    idle: Color(0xFFA2A6AE),
    crashed: Color(0xFFFA7681),
    crashedSoft: Color(0xFF3F2427),
    userBand: Color(0xFF233049),
    userBandBorder: Color(0xFF34497A),
    userBandText: Color(0xFFE8EEFB),
    userBandMuted: Color(0xFF9DB8F5),
    userBandCode: Color(0x14E8EEFB),
    userBandCodeBlock: Color(0xFF1A2338),
    agentText: Color(0xFFDFE1E5),
    inlineCode: Color(0x12DFE1E5),
    codeBlock: Color(0xFF2B2D30),
    toolTint: Color(0xFF1E2D2B),
    toolBorder: Color(0xFF2F4A47),
    toolAccent: Color(0xFF3AA597),
    subagentTint: Color(0xFF29243D),
    subagentBorder: Color(0xFF4B3F70),
    subagentAccent: Color(0xFFD2BEFF),
    selectionBar: Color(0xFF26272B),
    selectionBarText: Color(0xFFE8E9EC),
    selectionBarBorder: Color(0x22FFFFFF),
    selectionBarDivider: Color(0x33FFFFFF),
    shadow: Color(0x33000000),
    scrim: Color(0xDD000000),
    claude: Color(0xFFD98A5F),
    monogramText: Color(0xFF1E1F22),
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
  );
}
