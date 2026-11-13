/// The fonts installed on the machine (ADR 0097): on the Mac, AppKit's
/// (`fonts_macos.dart`); on Linux, fontconfig's (`fonts_linux.dart`).
abstract interface class Fonts {
  /// The installed monospaced families' names, or null when there's no
  /// answer.
  Future<List<String>?> monospaced();

  /// Every installed family's name, or null when there's no answer.
  Future<List<String>?> families();

  /// The family name the system's own interface font goes by, where it
  /// has one a name reaches (the Mac's); null elsewhere.
  String? get system;
}

/// The longest a font family's name may be.
const _longestFamily = 100;

/// Control and format characters, unassigned and private-use ones, and
/// the line and paragraph separators: nothing a family's name has.
final _unprintable = RegExp(r'[\p{C}\p{Zl}\p{Zp}]', unicode: true);

/// Whether [name] may be a font family's name. The system's list and a
/// stored setting are both someone else's text (ADR 0114): a name is one
/// line of at most 100 printable characters, with no space at either end,
/// and anything else is no name. A name is only ever shown and handed to
/// the text engine as a family to look for; no file is opened by it.
bool isFamilyName(String name) =>
    name.isNotEmpty &&
    name.length <= _longestFamily &&
    name.trim() == name &&
    !_unprintable.hasMatch(name);

/// [names] as a font menu lists them: the ones that can be names
/// ([isFamilyName]), each once, without the system's private families
/// (their names start with a dot) and without [but] (the bundled one,
/// which the menu lists first), in order whatever their case.
List<String> listedFamilies(Iterable<String>? names, {String? but}) {
  final listed = {
    for (final n in names ?? const <String>[])
      if (isFamilyName(n) && !n.startsWith('.') && n != but) n,
  }.toList();
  return listed..sort((a, b) {
    final byLetters = a.toLowerCase().compareTo(b.toLowerCase());
    return byLetters != 0 ? byLetters : a.compareTo(b);
  });
}
