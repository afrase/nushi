import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart' show dataDir;
import 'package:nushi/file_mode.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/theme/theme_file.dart';

/// The user's themes (ADR 0086), a JSON file each in the data folder's
/// `themes`: read at launch ([ThemeFiles.load]) and again when one changes
/// ([ThemeFiles.watch]).
final themeFiles = ThemeFiles(Directory('$dataDir/themes'));

/// The theme [colorTheme] names, of the built-ins and the user's: Nushi's
/// when it names none there is (a file taken away; it's back with the
/// file).
ColorTheme pickedTheme() {
  final id = colorTheme.value;
  for (final f in themeFiles.value) {
    if (f.theme case final t? when t.id == id) return t;
  }
  return builtInTheme(id) ?? nushiTheme;
}

/// How a folder is shown in Finder (a test's records it).
@visibleForTesting
Future<void> Function(List<String> args) openInFinder = (args) =>
    Process.run('/usr/bin/open', args);

/// The theme files in [dir], each read: at most [_most], in name order. A
/// file is untrusted input: only a regular file (no link, no pipe), at
/// most [themeFileLimit] bytes read, parsed strictly and never run.
class ThemeFiles extends ValueNotifier<List<ThemeFile>> {
  new(this.dir) : super(const []);

  final Directory dir;

  static const _most = 50;

  StreamSubscription<FileSystemEvent>? _watching;
  Timer? _soon;

  /// Each file's path, by the name it's shown as.
  final _paths = <String, String>{};

  /// Reads them all again.
  void load() => value = _read();

  List<ThemeFile> _read() {
    _paths.clear();
    final List<File> files;
    try {
      if (!dir.existsSync()) return const [];
      files = [
        for (final e in dir.listSync(followLinks: false))
          if (e is File &&
              e.path.endsWith('.json') &&
              FileSystemEntity.typeSync(e.path, followLinks: false) ==
                  FileSystemEntityType.file)
            e,
      ]..sort((a, b) => a.path.compareTo(b.path));
    } on FileSystemException {
      return const [];
    }
    return [
      for (final f in files.take(_most))
        if (_name(f) case final name) _readOne(f, name),
    ];
  }

  ThemeFile _readOne(File f, String name) {
    _paths[name] = f.path;
    try {
      // At most one byte past the limit: a file that grew since it was
      // listed is still read only so far.
      final raf = f.openSync();
      final List<int> bytes;
      try {
        bytes = raf.readSync(themeFileLimit + 1);
      } finally {
        raf.closeSync();
      }
      if (bytes.length > themeFileLimit) {
        return ThemeFile(
          file: name,
          notes: const ['Over ${themeFileLimit ~/ 1024} KB: not read.'],
        );
      }
      return readThemeFile(name, utf8.decode(bytes, allowMalformed: true));
    } on FileSystemException {
      return ThemeFile(file: name, notes: const ["Couldn't be read."]);
    }
  }

  static String _name(File f) => shownText(f.uri.pathSegments.last);

  /// Reads them again whenever one changes, comes or goes (a moment after,
  /// so an editor's save is read once, whole); the folder is made if it
  /// isn't there.
  void watch() {
    if (_watching != null) return;
    try {
      privateDir(dir);
      _watching = dir.watch().listen((_) {
        _soon?.cancel();
        _soon = Timer(const Duration(milliseconds: 150), load);
      }, onError: (Object _) {});
    } on FileSystemException {
      // No folder to watch: the themes read at launch stay.
    }
  }

  /// Stops [watch]ing.
  Future<void> stop() async {
    _soon?.cancel();
    await _watching?.cancel();
    _watching = null;
  }

  /// Writes a new theme file with every token of [from], named after it
  /// ("Nord 2"), picks it (it looks the same) and shows it in Finder, to
  /// be edited.
  Future<void> make(ColorTheme from) async {
    privateDir(dir);
    final taken = {for (final f in value) f.file.toLowerCase()};
    final stem = from.name.replaceAll(RegExp('[^A-Za-z0-9 _-]'), '').trim();
    final base = stem.isEmpty ? 'Theme' : stem;
    var name = base;
    for (
      var n = 2;
      taken.contains('${name.toLowerCase()}.json') ||
          File('${dir.path}/$name.json').existsSync();
      n++
    ) {
      name = '$base $n';
    }
    final file = File('${dir.path}/$name.json');
    writeWhole(file, utf8.encode(writeThemeFile(from, name)));
    load();
    colorTheme.value = '${ColorTheme.customPrefix}$name';
    await openInFinder(['-R', file.path]);
  }

  /// Opens the folder in Finder, made first if it isn't there.
  Future<void> reveal() async {
    privateDir(dir);
    await openInFinder([dir.path]);
  }

  /// Shows the theme file [file] (a name [value] lists) in Finder.
  Future<void> revealFile(String file) async {
    if (_paths[file] case final path?) await openInFinder(['-R', path]);
  }

  /// None read and none watched, as at launch (tests).
  @visibleForTesting
  Future<void> forget() async {
    await stop();
    value = const [];
  }
}
