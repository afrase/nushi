import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:nushi/fnv.dart';

// What a project's tile shows when it isn't the repository's own icon
// (ADR 0112): what the user set in Change tile…, else initials on a color
// worked out from the folder.

/// How many colors a tile can have: the theme's `Tokens.avatars`, named as
/// a chat's colors are (`ChatColor`).
const tileColorCount = 8;

/// What the user set for a project's tile in Change tile…: a [mark] (an
/// emoji, or one or two characters; '' for none) and a [color] (a
/// `ChatColor`'s name; '' for none). Either wins over the repository's
/// icon. Kept by folder in `projectTiles`: the user's data, never a hex,
/// so each theme draws the color its own way.
class TileLook {
  const new({this.mark = '', this.color = ''});

  /// [saved] as `app.json` has it; null when it isn't one, or sets
  /// nothing.
  static TileLook? read(Object? saved) {
    if (saved is! Map) return null;
    final look = TileLook(
      mark: switch (saved['mark']) {
        final String m => tileMark(m),
        _ => '',
      },
      color: switch (saved['color']) {
        final String c => c,
        _ => '',
      },
    );
    return look.isEmpty ? null : look;
  }

  final String mark;
  final String color;

  /// Whether it sets nothing: the tile is then the repository's icon or
  /// the initials.
  bool get isEmpty => mark.isEmpty && color.isEmpty;

  Map<String, Object?> toJson() => {
    if (mark.isNotEmpty) 'mark': mark,
    if (color.isNotEmpty) 'color': color,
  };
}

/// [text] as a tile's mark: trimmed, its first two characters as a reader
/// counts them (an emoji of several code points is one).
String tileMark(String text) => text.trim().characters.take(2).toString();

/// A project's initials for its tile, from its folder's [name]: the first
/// letters of its first two words ("lumen-docs" is LD, "nushiPoc" NP), or
/// a one-word name's first two ("lumen" is LU). '?' for a name with no
/// letter or digit.
String tileInitials(String name) {
  final words = [
    for (final w in name.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)))
      // A capital after a small letter starts a word too.
      ...w.split(RegExp(r'(?<=\p{Ll})(?=\p{Lu})', unicode: true)),
  ].where((w) => w.isNotEmpty).toList();
  final letters = switch (words) {
    [] => '?',
    [final one] => one.characters.take(2).toString(),
    [final a, final b, ...] => '${a.characters.first}${b.characters.first}',
  };
  return letters.toUpperCase();
}

/// The color of each of [folders]' tiles, as a place in the theme's eight:
/// the one the user [chosen] (by folder), else one given in the order the
/// projects joined the sidebar ([folders] is in that order), so a
/// project's color stays as others come and wherever it's dragged, and
/// changes only if one that joined before it is removed. Each takes the
/// color its path names if no project before it has it, else the next
/// one free; past eight projects, the one fewest have. So up to eight
/// projects are all told apart, neighbours in the rail or not.
Map<String, int> tileColors(
  List<String> folders, {
  Map<String, int> chosen = const {},
}) {
  final used = List.filled(tileColorCount, 0);
  for (final folder in folders) {
    if (chosen[folder] case final c?) used[c % tileColorCount]++;
  }
  final out = <String, int>{};
  for (final folder in folders) {
    if (chosen[folder] case final c?) {
      out[folder] = c % tileColorCount;
      continue;
    }
    final own = fnv1a(folder.codeUnits) % tileColorCount;
    var color = own;
    for (var step = 1; step < tileColorCount; step++) {
      final next = (own + step) % tileColorCount;
      if (used[next] < used[color]) color = next;
    }
    used[color]++;
    out[folder] = color;
  }
  return out;
}
