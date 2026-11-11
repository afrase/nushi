import 'package:flutter/widgets.dart';

import 'package:nushi/theme/diff_colors.dart';
import 'package:nushi/theme/terminal_colors.dart';

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

/// Every color of one set of a theme, for one brightness: a widget's
/// colors come only from here. [light] and [dark] are the Nushi theme's,
/// the POC's Workbench colors; their code colors are JetBrains' New UI
/// Dark and Light schemes' (RubyMine's for symbols and parameters, which
/// the platform leaves plain).
@immutable
class Tokens {
  const new({
    required this.brightness,
    required this.base,
    required this.raised,
    required this.selected,
    required this.borderSubtle,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.link,
    required this.onAccent,
    required this.fieldFill,
    required this.fieldBorder,
    required this.fieldBorderHover,
    required this.grip,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.running,
    required this.needs,
    required this.needsSoft,
    required this.done,
    required this.doneSoft,
    required this.idle,
    required this.crashed,
    required this.crashedSoft,
    required this.shine,
    required this.shineBand,
    required this.userBand,
    required this.userBandBorder,
    required this.userBandText,
    required this.userBandMuted,
    required this.userBandCode,
    required this.userBandCodeBlock,
    required this.agentText,
    required this.inlineCode,
    required this.inlineCodeText,
    required this.codeBlock,
    required this.toolTint,
    required this.toolBorder,
    required this.toolAccent,
    required this.subagentTint,
    required this.subagentBorder,
    required this.subagentAccent,
    required this.findingsTint,
    required this.findingsBorder,
    required this.findingsAccent,
    required this.selectionBar,
    required this.selectionBarText,
    required this.selectionBarBorder,
    required this.selectionBarDivider,
    required this.shadow,
    required this.scrim,
    required this.claude,
    required this.ante,
    required this.ompPlug,
    required this.pi,
    required this.pig,
    required this.monogramText,
    required this.avatars,
    required this.syntax,
    this._window,
    this._lifted,
    this._segment,
    this._line,
    this._hover,
    this._pressed,
    this._quote,
    this._terminal,
    this._diff,
  });

  final Brightness brightness;

  // Surfaces (ADR 0111): things are told apart by their fill, a step at a
  // time. The window behind everything is [window]; a pane on it is
  // [base]; a card on a pane (and a menu, a dialog) is [raised]; a raised
  // bit on a card is [lifted]. The sidebar sits on [window] with no pane of
  // its own, its cards [raised]. [selected] is a selected row in a list.
  final Color base;
  final Color raised;
  final Color selected;

  /// The window's own background, behind the panes: the sidebar sits on it,
  /// and the gaps between panes show it. Unless a theme gives its own, a
  /// step off [base]: darker on a dark theme, a little of the text's color
  /// mixed in on a light one.
  Color get window =>
      _window ??
      (brightness == Brightness.dark
          ? Color.lerp(base, const Color(0xFF000000), 0.3)!
          : Color.lerp(base, text.withValues(alpha: 1), 0.08)!);
  final Color? _window;

  /// A raised bit on a card: a key's cap, a button on a card, a meter's
  /// track. Unless a theme gives its own, [raised] a step toward the text.
  Color get lifted =>
      _lifted ?? Color.lerp(raised, text.withValues(alpha: 1), 0.06)!;
  final Color? _lifted;

  /// The picked segment of a segmented control, raised from its [raised]
  /// track. Unless a theme gives its own: lighter than the track on a dark
  /// theme, the pane's own fill on a light one.
  Color get segment =>
      _segment ??
      (brightness == Brightness.dark
          ? Color.lerp(raised, text.withValues(alpha: 1), 0.105)!
          : base);
  final Color? _segment;

  /// A hairline: a divider inside a pane (under a header, between a pane
  /// and the one beside it) and around the composer. Never an outline
  /// around a card, which its fill tells apart. Unless a theme gives its
  /// own, the text's color, faint.
  Color get line =>
      _line ??
      text.withValues(alpha: brightness == Brightness.dark ? 0.07 : 0.09);
  final Color? _line;

  /// A grey mark that stands back from what it's on: the empty window's
  /// logo, a rail's dashes at rest, the part of a meter that counts for
  /// nothing. A pane's fill, a third of the way to the text's color.
  Color get faint => Color.lerp(base, text.withValues(alpha: 1), 0.3)!;

  // The outlines from before the surfaces told things apart (ADR 0111):
  // still around what later passes haven't reached, and right for a menu's
  // and a dialog's edge. New dividers are [line].
  final Color borderSubtle;
  final Color borderStrong;

  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color link;
  final Color onAccent;

  // Controls (`controls.dart`): a field's box (a menu's value, a button's
  // outline), darker under the pointer, readable on the page and on a
  // raised panel or dialog alike; a drag grip's dots.
  final Color fieldFill;
  final Color fieldBorder;
  final Color fieldBorderHover;
  final Color grip;

  // The accent: [accent] fills (a primary button, a switch that's on),
  // [accentSoft] behind it; [accentInk] where the accent is text or an
  // icon, or the focus ring: [accent] is too dark for that on the dark
  // theme's surfaces (3.34:1 on base, 2.97 on raised). [accentInk] passes
  // AA in both: light 6.13 on base, 5.57 on raised, 5.27 on the window,
  // 4.81 on selected, 4.64 on accentSoft; dark 6.92, 6.16, 7.49, 4.76,
  // 4.91 (`tokens_test`).
  final Color accent;
  final Color accentSoft;
  final Color accentInk;

  /// The ring a focused control wears.
  Color get focus => accentInk;

  // Status: a running chat, one that needs the user, done, idle, failed.
  final Color running;
  final Color needs;
  final Color needsSoft;
  final Color done;
  final Color doneSoft; // behind words that say it went well
  final Color idle;
  final Color crashed;
  final Color crashedSoft;

  // What's still going (a running call's title, "Thinking…"): its text,
  // and the band that sweeps across it (motion.dart's Shine). Dark, a light
  // band over a muted grey; light, a dark band over a lighter grey.
  final Color shine;
  final Color shineBand;

  // The transcript. A user message is a bubble (a band across a phone's),
  // with its marker (a relay's), its inline code and code blocks; the
  // agent's text and inline code; code's own surface ([codeBlock]); a tool
  // call's icon ([toolAccent]; its row is a card, [raised]) and a
  // subagent's row, a tint with an accent for its name; a review's
  // findings, their accent (the card's icon, a row's file and line); the
  // bar over a selection; and the scrim behind an image opened whole.
  // [toolTint], the three borders and [findingsTint] are from before the
  // surfaces told things apart (ADR 0111): the transcript no longer draws
  // them, and what still does (the pull request's rows, the cleanup
  // dialog, Settings' theme preview) loses them in its own pass.
  final Color userBand;
  final Color userBandBorder;
  final Color userBandText;
  final Color userBandMuted;
  final Color userBandCode;
  final Color userBandCodeBlock;
  final Color agentText;

  // Inline code, in the agent's text, the user's band, a finding and the
  // composer, orange as Slack draws it: [inlineCodeText] on its chip,
  // [inlineCode] (or [userBandCode] in the band), a tint of the ink.
  // AA on every fill it sits on (`code_ink_test`): light 4.59 at worst, on
  // the findings card under the pointer, 4.80 on raised hovered, 4.93
  // selected, 5.05 in the band, 6.20 on base; dark 4.67 on the findings
  // card under the pointer, 5.13 on raised hovered, 4.85 selected, 5.18 in
  // the band, 7.04 on base.
  final Color inlineCode;
  final Color inlineCodeText;

  /// Behind code: a code block, a tool call's output, a diff in the
  /// transcript. Sunk, about the window's tone: a step off the pane and off
  /// a card, since it sits on both (`tokens_test`).
  final Color codeBlock;
  final Color toolTint;
  final Color toolBorder;
  final Color toolAccent;
  final Color subagentTint;
  final Color subagentBorder;
  final Color subagentAccent;
  final Color findingsTint;
  final Color findingsBorder;
  final Color findingsAccent;
  final Color selectionBar;
  final Color selectionBarText;
  final Color selectionBarBorder;
  final Color selectionBarDivider;
  final Color shadow;
  final Color scrim;

  /// The shadow under what floats over the window (a menu, a dialog, a
  /// popover, a toast; ADR 0111): [shadow] on a light theme, twice as deep
  /// on a dark one, where a soft shadow is lost on the dark behind it.
  Color get floatShadow => brightness == Brightness.dark
      ? shadow.withValues(alpha: (shadow.a * 2).clamp(0, 1))
      : shadow;

  // The agents' marks' colors, from their own logos (`agent_mark.dart`,
  // docs/user/agent-marks.md): Claude's, Anthropic's own; Ante's ghost,
  // its gradient's gold; oh-my-pi's plug (its π is white, so the text's
  // color); Pi's, the blue of its middle piece; PiG's pig, its pink. The
  // dark ones are the logos' own, the light ones darker shades of them;
  // each is at least 3:1 on base, raised, selected and the window, where
  // the sidebar's rows are (`agent_mark_test`).
  // Codex's Blossom has none: OpenAI draws it black or white. Then the
  // letter on an agent's monogram.
  final Color claude;
  final Color ante;
  final Color ompPlug;
  final Color pi;
  final Color pig;
  final Color monogramText;

  /// People's colors (a Jira assignee's avatar), each under
  /// [monogramText]'s initials; also a chat's color as a mark (a swatch,
  /// the chip at its row's end), which `ChatColor` takes by position. As a
  /// mark each must hold 3:1 on what a row can be: the window (the
  /// sidebar's rows), [hover] on it, raised, [hover] on that, [selected],
  /// [accentSoft] (the open chat) and base (the phone's list). Worst of the
  /// eight: light 4.49 on the window, 3.78 hovered, 4.75 on raised, 3.99
  /// hovered, 4.10 selected, 3.96 open, 5.22 on base; dark 7.40, 6.28,
  /// 6.08, 5.00, 4.71, 4.85, 6.84 (`chat_colors_test`, which also holds a
  /// row's text to AA on each).
  final List<Color> avatars;

  /// Code's colors, in diffs and code blocks, by [Capture].
  final Map<Capture, CodeInk> syntax;

  /// How [c] looks.
  CodeInk ink(Capture c) => syntax[c]!;

  /// The tint of a row or button under the pointer: the text's, lighter on
  /// the dark theme, where every row's text and status color must still
  /// read AA on it (`tokens_test`), unless a theme gives its own.
  Color get hover =>
      _hover ??
      text.withValues(alpha: brightness == Brightness.dark ? 0.075 : 0.09);
  final Color? _hover;

  /// The tint of a row or button while the pointer is down on it: a click
  /// shows before what it does is done.
  Color get pressed =>
      _pressed ??
      text.withValues(alpha: brightness == Brightness.dark ? 0.14 : 0.16);
  final Color? _pressed;

  /// Behind quoted text (a Markdown quote, the selection a reply quotes):
  /// a soft fill in the place of a bar down its side (ADR 0111). A tint of
  /// the text's color, so it shows on whatever the quote sits on (the
  /// pane, a message's bubble, a card), unless a theme gives its own.
  Color get quote => _quote ?? text.withValues(alpha: 0.07);
  final Color? _quote;

  /// A gold mark beside [claude]'s orange (Context's System prompt, as
  /// Claude's rail colors it): [needs] on a dark theme; on a light one,
  /// whose [needs] and [claude] are both darkened to brown to read as
  /// text, [ante]'s gold at half lightness, a swatch's, not a text's.
  Color get gold => brightness == Brightness.dark
      ? needs
      : HSLColor.fromColor(ante).withLightness(0.5).toColor();

  /// The terminal's ANSI colors: VS Code's unless a theme gives its own.
  TerminalColors get terminal =>
      _terminal ??
      (brightness == Brightness.dark
          ? TerminalColors.vsCodeDark
          : TerminalColors.vsCodeLight);
  final TerminalColors? _terminal;

  /// A diff's colors: drawn from the surfaces and status colors unless a
  /// theme gives its own (Nushi's are `diff_view`'s).
  DiffColors get diff =>
      _diff ??
      DiffColors.derived(
        brightness: brightness,
        base: base,
        raised: raised,
        selected: selected,
        text: text,
        textSecondary: textSecondary,
        textMuted: textMuted,
        accent: accent,
        accentInk: accentInk,
        done: done,
        needs: needs,
      );
  final DiffColors? _diff;

  /// The accent's fill while a primary button is pressed: a shade darker.
  Color get accentPressed => Color.alphaBlend(const Color(0x2E000000), accent);

  static const light = Tokens(
    brightness: Brightness.light,
    window: Color(0xFFECEEF2),
    base: Color(0xFFFFFFFF),
    raised: Color(0xFFF3F4F7),
    lifted: Color(0xFFE6E8ED),
    segment: Color(0xFFFFFFFF),
    line: Color(0x17141824),
    selected: Color(0xFFE1E4EB),
    borderSubtle: Color(0xFFE2E4E9),
    borderStrong: Color(0xFFBBBFCB),
    text: Color(0xFF1E1F22),
    textSecondary: Color(0xFF494B57),
    textMuted: Color(0xFF5A5E6B),
    link: Color(0xFF2259D2),
    onAccent: Color(0xFFFFFFFF),
    fieldFill: Color(0xFFFFFFFF),
    fieldBorder: Color(0xFFC5C9D2),
    fieldBorderHover: Color(0xFF9FA3AF),
    grip: Color(0xFF8A8E9B),
    accent: Color(0xFF2365EA),
    accentSoft: Color(0xFFD2E1FC),
    accentInk: Color(0xFF2259D2),
    running: Color(0xFF2259D2),
    needs: Color(0xFF8F5200),
    needsSoft: Color(0xFFFAE8C8),
    done: Color(0xFF1B7031),
    doneSoft: Color(0xFFD6EDDC),
    idle: Color(0xFF5D6170),
    crashed: Color(0xFFB62B39),
    crashedSoft: Color(0xFFFFDEE2),
    shine: Color(0xFF6E727E),
    shineBand: Color(0xFF1E1F22),
    userBand: Color(0xFFDAE8FF),
    userBandBorder: Color(0xFFA5BEF1),
    userBandText: Color(0xFF142A5C),
    userBandMuted: Color(0xFF3A5594),
    userBandCode: Color(0x1A8D4100),
    userBandCodeBlock: Color(0xFFF5F8FE),
    agentText: Color(0xFF1E1F22),
    inlineCode: Color(0x1A8D4100),
    inlineCodeText: Color(0xFF8D4100),
    codeBlock: Color(0xFFECEEF2),
    toolTint: Color(0xFFDAF2EE),
    toolBorder: Color(0xFFA5D6CE),
    toolAccent: Color(0xFF0E8577),
    subagentTint: Color(0xFFEDE4FE),
    subagentBorder: Color(0xFFC9B7F1),
    subagentAccent: Color(0xFF4E1FA8),
    findingsTint: Color(0xFFFAEDD7),
    findingsBorder: Color(0xFFE5CA98),
    findingsAccent: Color(0xFF8A5300),
    selectionBar: Color(0xFF26272B),
    selectionBarText: Color(0xFFE8E9EC),
    selectionBarBorder: Color(0x22FFFFFF),
    selectionBarDivider: Color(0x33FFFFFF),
    shadow: Color(0x33000000),
    scrim: Color(0xDD000000),
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
    diff: DiffColors.intelliJLight,
  );

  static const dark = Tokens(
    brightness: Brightness.dark,
    window: Color(0xFF131417),
    base: Color(0xFF1B1C20),
    raised: Color(0xFF24262B),
    lifted: Color(0xFF2F3138),
    segment: Color(0xFF383B43),
    line: Color(0x12FFFFFF),
    selected: Color(0xFF36383E),
    borderSubtle: Color(0xFF41444A),
    borderStrong: Color(0xFF585C64),
    text: Color(0xFFDFE1E5),
    textSecondary: Color(0xFFB4B8BF),
    textMuted: Color(0xFFA5A9B1),
    link: Color(0xFF77A4FF),
    onAccent: Color(0xFFFFFFFF),
    fieldFill: Color(0xFF313338),
    fieldBorder: Color(0xFF55585F),
    fieldBorderHover: Color(0xFF71747C),
    grip: Color(0xFF80848C),
    accent: Color(0xFF2365EA),
    accentSoft: Color(0xFF23355D),
    accentInk: Color(0xFF77A4FF),
    running: Color(0xFF77A4FF),
    needs: Color(0xFFE9AC4C),
    needsSoft: Color(0xFF43351A),
    done: Color(0xFF6CC271),
    doneSoft: Color(0xFF263D2E),
    idle: Color(0xFFA2A6AE),
    crashed: Color(0xFFFF7F89),
    crashedSoft: Color(0xFF4C242A),
    shine: Color(0xFF9DA1AA),
    shineBand: Color(0xFFF4F6FA),
    userBand: Color(0xFF233457),
    userBandBorder: Color(0xFF3A5491),
    userBandText: Color(0xFFE8EEFB),
    userBandMuted: Color(0xFF9DB8F5),
    userBandCode: Color(0x1FF5AD66),
    userBandCodeBlock: Color(0xFF1A2338),
    agentText: Color(0xFFDFE1E5),
    inlineCode: Color(0x1FF5AD66),
    inlineCodeText: Color(0xFFF5AD66),
    codeBlock: Color(0xFF151619),
    toolTint: Color(0xFF193431),
    toolBorder: Color(0xFF2B5753),
    toolAccent: Color(0xFF3AA597),
    subagentTint: Color(0xFF2E2749),
    subagentBorder: Color(0xFF564684),
    subagentAccent: Color(0xFFD2BEFF),
    findingsTint: Color(0xFF342C1D),
    findingsBorder: Color(0xFF5C4C2F),
    findingsAccent: Color(0xFFE6B062),
    selectionBar: Color(0xFF26272B),
    selectionBarText: Color(0xFFE8E9EC),
    selectionBarBorder: Color(0x22FFFFFF),
    selectionBarDivider: Color(0x33FFFFFF),
    shadow: Color(0x33000000),
    scrim: Color(0xDD000000),
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
    diff: DiffColors.darcula,
  );
}
