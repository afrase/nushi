import 'package:flutter/widgets.dart';

/// A terminal's sixteen ANSI colors, a theme's (`Tokens.terminal`); its
/// text, background and cursor are the theme's text and base.
@immutable
class TerminalColors {
  const new({
    required this.black,
    required this.red,
    required this.green,
    required this.yellow,
    required this.blue,
    required this.magenta,
    required this.cyan,
    required this.white,
    required this.brightBlack,
    required this.brightRed,
    required this.brightGreen,
    required this.brightYellow,
    required this.brightBlue,
    required this.brightMagenta,
    required this.brightCyan,
    required this.brightWhite,
  });

  final Color black;
  final Color red;
  final Color green;
  final Color yellow;
  final Color blue;
  final Color magenta;
  final Color cyan;
  final Color white;
  final Color brightBlack;
  final Color brightRed;
  final Color brightGreen;
  final Color brightYellow;
  final Color brightBlue;
  final Color brightMagenta;
  final Color brightCyan;
  final Color brightWhite;

  /// VS Code's light terminal palette, the Nushi theme's.
  static const vsCodeLight = TerminalColors(
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF00BC00),
    yellow: Color(0xFF949800),
    blue: Color(0xFF0451A5),
    magenta: Color(0xFFBC05BC),
    cyan: Color(0xFF0598BC),
    white: Color(0xFF555555),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFCD3131),
    brightGreen: Color(0xFF14CE14),
    brightYellow: Color(0xFFB5BA00),
    brightBlue: Color(0xFF0451A5),
    brightMagenta: Color(0xFFBC05BC),
    brightCyan: Color(0xFF0598BC),
    brightWhite: Color(0xFFA5A5A5),
  );

  /// VS Code's dark terminal palette, the Nushi theme's.
  static const vsCodeDark = TerminalColors(
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFE5E5E5),
  );
}
