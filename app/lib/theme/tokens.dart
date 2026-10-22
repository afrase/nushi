import 'package:flutter/widgets.dart';

/// The POC's Workbench colors for one brightness.
@immutable
class Tokens {
  const Tokens({
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
    required this.claude,
    required this.monogramText,
    required this.keyword,
    required this.function,
    required this.string,
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

  // The agent's monogram.
  final Color claude;
  final Color monogramText;

  // Syntax colors in code blocks.
  final Color keyword;
  final Color function;
  final Color string;

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
    claude: Color(0xFFB0582B),
    monogramText: Color(0xFFFFFFFF),
    keyword: Color(0xFF0033B3),
    function: Color(0xFF00627A),
    string: Color(0xFF067D17),
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
    claude: Color(0xFFD98A5F),
    monogramText: Color(0xFF1E1F22),
    keyword: Color(0xFFCF8E6D),
    function: Color(0xFF56A8F5),
    string: Color(0xFF6AAB73),
  );
}
