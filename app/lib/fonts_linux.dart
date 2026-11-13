import 'dart:io';

import 'package:nushi/fonts.dart';

/// Runs a program with arguments, as `Process.run` does.
typedef RunProcess = Future<ProcessResult> Function(
  String program,
  List<String> arguments,
);

/// Linux's installed fonts, as fontconfig lists them (`fc-list`, ADR
/// 0104): every family, or those whose glyphs are all one width.
class LinuxFonts implements Fonts {
  /// Running `fc-list` with [run].
  const new({this.run = Process.run});

  final RunProcess run;

  @override
  Future<List<String>?> monospaced() => _list(':spacing=mono');

  @override
  Future<List<String>?> families() => _list(':');

  /// No one name: the interface font is the desktop's own setting.
  @override
  String? get system => null;

  /// The families of the fonts matching [pattern] (`:` is every font);
  /// no answer without `fc-list` or when it fails.
  Future<List<String>?> _list(String pattern) async {
    final ProcessResult r;
    try {
      r = await run('fc-list', [pattern, 'family']);
    } on ProcessException {
      return null;
    }
    if (r.exitCode != 0) return null;
    return familiesOf('${r.stdout}');
  }
}

/// The families in `fc-list family`'s [output], sorted, each once: a
/// line is one font's names, separated by commas (the first is the one it
/// goes by), a backslash escaping the character after it.
List<String> familiesOf(String output) {
  final families = <String>{};
  for (final line in output.split('\n')) {
    final name = StringBuffer();
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == r'\' && i + 1 < line.length) {
        name.write(line[++i]);
      } else if (c == ',') {
        break;
      } else {
        name.write(c);
      }
    }
    final family = name.toString().trim();
    if (family.isNotEmpty) families.add(family);
  }
  return families.toList()..sort();
}
