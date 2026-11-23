import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart' show dataDir;
import 'package:nushi/file_mode.dart';
import 'package:nushi/native.dart';
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

  /// What [load] read last, file by file: its name and text (or why it has
  /// none), so a save that changed nothing tells no one (every listener
  /// rebuilds the app's theme).
  List<(String, String)> _readAs = const [];

  /// Reads them all again. A file that read as a theme and now reads as
  /// none (a save that broke it, one caught half written) keeps its last
  /// good theme, with the new read's notes on its card: the window keeps
  /// its colors while the file is fixed.
  void load() {
    final read = _read();
    final as = [for (final (f, text) in read) (f.file, text)];
    if (listEquals(as, _readAs)) return;
    _readAs = as;
    final good = {for (final f in value) f.file: ?f.theme};
    value = [
      for (final (f, _) in read)
        if ((f.theme, good[f.file]) case (null, final kept?))
          ThemeFile(file: f.file, notes: f.notes, theme: kept)
        else
          f,
    ];
  }

  /// Each file read, and its text.
  List<(ThemeFile, String)> _read() {
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

  (ThemeFile, String) _readOne(File f, String name) {
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
        const note = 'Over ${themeFileLimit ~/ 1024} KB: not read.';
        return (ThemeFile(file: name, notes: const [note]), '\u0000$note');
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      return (readThemeFile(name, text), text);
    } on FileSystemException {
      const note = "Couldn't be read.";
      return (ThemeFile(file: name, notes: const [note]), '\u0000$note');
    }
  }

  static String _name(File f) => shownText(f.uri.pathSegments.last);

  /// Reads them again whenever one changes, comes or goes (a moment after,
  /// so an editor's save is read once, whole); the folder is made if it
  /// isn't there. A watch that ends or fails is let go, so the next
  /// [make] or [reveal] starts another.
  void watch() {
    if (_watching != null) return;
    try {
      privateDir(dir);
      _watching = dir.watch().listen(
        (_) {
          _soon?.cancel();
          // design: a file watch's settling, not motion
          _soon = Timer(const Duration(milliseconds: 150), load);
        },
        onError: (Object _) => _lost(),
        onDone: _lost,
      );
    } on FileSystemException {
      // No folder to watch: the themes read at launch stay.
    }
  }

  void _lost() {
    unawaited(_watching?.cancel());
    _watching = null;
  }

  /// Stops [watch]ing.
  Future<void> stop() async {
    _soon?.cancel();
    await _watching?.cancel();
    _watching = null;
  }

  /// Writes a new theme file with every token of [from], named after it
  /// ("Nord 2"), picks it (it looks the same) and shows it in Finder, to
  /// be edited. Throws a [ThemeFilesError] when it can't.
  Future<void> make(ColorTheme from) async {
    _folder();
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
    try {
      writeWhole(file, utf8.encode(writeThemeFile(from, name)));
    } on FileSystemException catch (e) {
      throw ThemeFilesError("Couldn't make $name.json", e);
    }
    load();
    colorTheme.value = '${ColorTheme.customPrefix}$name';
    await native.desktop.reveal(file.path);
  }

  /// Opens the folder in Finder, made first if it isn't there. Throws a
  /// [ThemeFilesError] when it can't be made.
  Future<void> reveal() async {
    _folder();
    await native.desktop.openFolder(dir.path);
  }

  /// Makes the folder if it isn't there and watches it again if the watch
  /// was lost: what the user is about to edit reloads.
  void _folder() {
    try {
      privateDir(dir);
    } on FileSystemException catch (e) {
      throw ThemeFilesError("Couldn't make the themes folder", e);
    }
    watch();
  }

  /// Shows the theme file [file] (a name [value] lists) in Finder.
  Future<void> revealFile(String file) async {
    if (_paths[file] case final path?) await native.desktop.reveal(path);
  }

  /// None read and none watched, as at launch (tests).
  @visibleForTesting
  Future<void> forget() async {
    await stop();
    _readAs = const [];
    value = const [];
  }
}

/// Why a theme file or the themes folder couldn't be written, in words a
/// toast shows.
class ThemeFilesError implements Exception {
  const new(this.what, this.cause);

  final String what;
  final FileSystemException cause;

  @override
  String toString() => '$what: ${cause.osError?.message ?? cause.message}.';
}
