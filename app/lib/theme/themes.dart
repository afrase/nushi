import 'package:flutter/widgets.dart';

import 'package:nushi/theme/catppuccin.dart';
import 'package:nushi/theme/nord.dart';
import 'package:nushi/theme/solarized.dart';
import 'package:nushi/theme/tokens.dart';
import 'package:nushi/theme/tokyo_night.dart';
import 'package:nushi/theme/vivid.dart';

/// A color theme (ADR 0086): a named palette, a dark and a light set of
/// [Tokens]. The appearance picks which of the two shows; the theme picks
/// the palette. [id] is what's remembered: a built-in's own, or `custom:`
/// and a theme file's name for one of the user's.
@immutable
class ColorTheme {
  const new({
    required this.id,
    required this.name,
    required this.dark,
    required this.light,
    this.darkName,
    this.lightName,
  });

  final String id;
  final String name;
  final Tokens dark;
  final Tokens light;

  /// What each set is known as where the palette names its variants
  /// (Tokyo Night's light one is Tokyo Night Day): the picker says it
  /// beside Dark and Light.
  final String? darkName;
  final String? lightName;

  /// The set for [brightness].
  Tokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Whether it's one of the user's, from a theme file.
  bool get custom => id.startsWith(customPrefix);

  /// What a custom theme's [id] starts with.
  static const customPrefix = 'custom:';
}

/// Nushi's own palette, the default.
const nushiTheme = ColorTheme(
  id: 'nushi',
  name: 'Nushi',
  dark: Tokens.dark,
  light: Tokens.light,
);

/// The themes that come with the app, Nushi's first.
const List<ColorTheme> builtInThemes = [
  nushiTheme,
  ColorTheme(id: 'vivid', name: 'Vivid', dark: vividDark, light: vividLight),
  ColorTheme(
    id: 'solarized',
    name: 'Solarized',
    dark: solarizedDark,
    light: solarizedLight,
  ),
  ColorTheme(id: 'nord', name: 'Nord', dark: nordDark, light: nordLight),
  ColorTheme(
    id: 'catppuccin',
    name: 'Catppuccin',
    dark: catppuccinDark,
    light: catppuccinLight,
    darkName: 'Catppuccin Mocha',
    lightName: 'Catppuccin Latte',
  ),
  ColorTheme(
    id: 'tokyo-night',
    name: 'Tokyo Night',
    dark: tokyoNightDark,
    light: tokyoNightLight,
    darkName: 'Tokyo Night',
    lightName: 'Tokyo Night Day',
  ),
];

/// The built-in theme [id] names, if any.
ColorTheme? builtInTheme(String id) {
  for (final t in builtInThemes) {
    if (t.id == id) return t;
  }
  return null;
}
