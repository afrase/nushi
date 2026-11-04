import 'package:nushi/theme/themes.dart';
import 'package:nushi/theme/tokens.dart';

/// Every built-in theme's light and dark set, each named ("Nord, dark"):
/// the token tests hold each to their floors, so a built-in can't ship
/// under AA (ADR 0086).
final List<(String, Tokens)> everySet = [
  for (final c in builtInThemes)
    for (final t in [c.light, c.dark]) ('${c.name}, ${t.brightness.name}', t),
];
