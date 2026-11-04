import 'package:flutter/widgets.dart';

/// A diff's colors (`diff_view`'s theme, but for its syntax, which is the
/// theme's `Capture` inks), a theme's (`Tokens.diff`).
@immutable
class DiffColors {
  const new({
    required this.background,
    required this.text,
    required this.gutterBackground,
    required this.gutterText,
    required this.gutterTextChanged,
    required this.insertedLine,
    required this.insertedWord,
    required this.deletedLine,
    required this.deletedWord,
    required this.modifiedLine,
    required this.modifiedWord,
    required this.ribbonInserted,
    required this.ribbonDeleted,
    required this.ribbonModified,
    required this.dividerBackground,
    required this.selection,
    required this.selectionOverCap,
    required this.foldPlaceholderBackground,
    required this.foldPlaceholderText,
    required this.loadingBar,
    required this.hoverAffordance,
  });

  /// A theme's diff drawn from its own surfaces, inks and status colors:
  /// what a theme gets unless it gives its own. Deleted lines stay grey, as
  /// JetBrains draws them.
  factory derived({
    required Brightness brightness,
    required Color base,
    required Color raised,
    required Color selected,
    required Color text,
    required Color textSecondary,
    required Color textMuted,
    required Color accent,
    required Color accentInk,
    required Color done,
    required Color needs,
  }) {
    final dark = brightness == Brightness.dark;
    Color mix(Color c, double a) =>
        Color.alphaBlend(c.withValues(alpha: a), base);
    final gutter = dark ? base : raised;
    return DiffColors(
      background: base,
      text: text,
      gutterBackground: gutter,
      gutterText: textMuted,
      gutterTextChanged: textSecondary,
      insertedLine: mix(done, dark ? 0.16 : 0.12),
      insertedWord: mix(done, dark ? 0.32 : 0.28),
      deletedLine: mix(textMuted, 0.12),
      deletedWord: mix(textMuted, 0.24),
      modifiedLine: mix(accentInk, dark ? 0.14 : 0.1),
      modifiedWord: mix(accentInk, dark ? 0.3 : 0.24),
      ribbonInserted: mix(done, 0.22),
      ribbonDeleted: mix(textMuted, 0.18),
      ribbonModified: mix(accentInk, 0.2),
      dividerBackground: gutter,
      selection: accent.withValues(alpha: dark ? 0.4 : 0.33),
      selectionOverCap: needs.withValues(alpha: dark ? 0.4 : 0.33),
      foldPlaceholderBackground: dark ? raised : selected,
      foldPlaceholderText: textMuted,
      loadingBar: selected,
      hoverAffordance: accentInk,
    );
  }

  final Color background;
  final Color text;
  final Color gutterBackground;
  final Color gutterText;
  final Color gutterTextChanged;
  final Color insertedLine;
  final Color insertedWord;
  final Color deletedLine;
  final Color deletedWord;
  final Color modifiedLine;
  final Color modifiedWord;
  final Color ribbonInserted;
  final Color ribbonDeleted;
  final Color ribbonModified;
  final Color dividerBackground;
  final Color selection;
  final Color selectionOverCap;
  final Color foldPlaceholderBackground;
  final Color foldPlaceholderText;
  final Color loadingBar;
  final Color hoverAffordance;

  /// `diff_view`'s IntelliJ Light, the Nushi theme's.
  static const intelliJLight = DiffColors(
    background: Color(0xFFFFFFFF),
    text: Color(0xFF080808),
    gutterBackground: Color(0xFFF7F8FA),
    gutterText: Color(0xFF8C8C8C),
    gutterTextChanged: Color(0xFF4A4A4A),
    insertedLine: Color(0xFFE3F5E3),
    insertedWord: Color(0xFFB8E6B8),
    deletedLine: Color(0xFFEDEDED),
    deletedWord: Color(0xFFD6D6D6),
    modifiedLine: Color(0xFFE6EEFC),
    modifiedWord: Color(0xFFC2D6FA),
    ribbonInserted: Color(0xFFD2EFD2),
    ribbonDeleted: Color(0xFFE2E2E2),
    ribbonModified: Color(0xFFD6E3FA),
    dividerBackground: Color(0xFFF7F8FA),
    selection: Color(0x553D7EFF),
    selectionOverCap: Color(0x55E8A33D),
    foldPlaceholderBackground: Color(0xFFF0F2F5),
    foldPlaceholderText: Color(0xFF6F737A),
    loadingBar: Color(0xFFE6E8EB),
    hoverAffordance: Color(0xFF3574F0),
  );

  /// `diff_view`'s Darcula, the Nushi theme's.
  static const darcula = DiffColors(
    background: Color(0xFF1E1F22),
    text: Color(0xFFBCBEC4),
    gutterBackground: Color(0xFF1E1F22),
    gutterText: Color(0xFF6F737A),
    gutterTextChanged: Color(0xFFA1A3AB),
    insertedLine: Color(0xFF2A3A2C),
    insertedWord: Color(0xFF3B5B3E),
    deletedLine: Color(0xFF34363B),
    deletedWord: Color(0xFF4A4D55),
    modifiedLine: Color(0xFF26324A),
    modifiedWord: Color(0xFF34486E),
    ribbonInserted: Color(0xFF2E4632),
    ribbonDeleted: Color(0xFF3C3F45),
    ribbonModified: Color(0xFF2C3B57),
    dividerBackground: Color(0xFF1E1F22),
    selection: Color(0x663D7EFF),
    selectionOverCap: Color(0x66E8A33D),
    foldPlaceholderBackground: Color(0xFF2B2D30),
    foldPlaceholderText: Color(0xFF8C8F96),
    loadingBar: Color(0xFF2B2D30),
    hoverAffordance: Color(0xFF548AF7),
  );
}
