import 'dart:convert';
import 'dart:io';

import 'package:nushi/app_log.dart';
import 'package:nushi/kept_trouble.dart';
import 'package:nushi/native.dart';

/// What makes the user's own files theirs only (ADR 0097): on the Mac,
/// libc's chmod through FFI (`file_mode_macos.dart`). The phone's web app
/// keeps no files and never asks.
abstract interface class FileModes {
  /// Sets [path]'s permissions to [mode] (0x180 is 0600, 0x1c0 0700), or
  /// throws a [FileSystemException].
  void setMode(String path, int mode);
}

/// Sets [path]'s permissions to [mode] ([Native.fileModes]).
void setMode(String path, int mode) => native.fileModes.setMode(path, mode);

/// Writes [file] whole or not at all, only the user's ([mode], 0600
/// unless said): to a file beside it, renamed over it, so a crash
/// mid-write can't leave half of it.
void writeWhole(File file, List<int> bytes, {int mode = 0x180}) {
  final tmp = File('${file.path}.tmp')..writeAsBytesSync(bytes, flush: true);
  setMode(tmp.path, mode);
  tmp.renameSync(file.path);
}

/// What [readKept] found in a file the app keeps: its JSON object
/// ([json]: empty when there's no file, or it was set aside), and whether
/// it was set aside.
typedef Kept = ({Map<String, Object?> json, bool setAside});

/// Reads [file], a JSON object the app keeps, by the daemon's rule
/// (`clearForWrite`, internal/store/aside.go): no file is the empty state;
/// one that doesn't parse as an object is renamed beside it to
/// `<name>.unreadable-<time>` and reads as empty, so the next save
/// replaces nothing unread; any other error (permissions, I/O, a set-aside
/// that fails) is thrown, and the caller saves nothing over the file while
/// it stands.
Kept readKept(File file) {
  final name = file.uri.pathSegments.last;
  final List<int> bytes;
  try {
    bytes = file.readAsBytesSync();
  } on PathNotFoundException {
    return (json: <String, Object?>{}, setAside: false);
  } on Object {
    noteKeptTrouble(name, KeptTroubleKind.unread);
    rethrow;
  }
  try {
    if (jsonDecode(utf8.decode(bytes)) case final Map<String, Object?> j) {
      return (json: j, setAside: false);
    }
  } on FormatException {
    // Set aside, below.
  }
  final aside = _asideName(file);
  try {
    file.renameSync(aside);
  } on Object {
    noteKeptTrouble(name, KeptTroubleKind.unread);
    rethrow;
  }
  noteKeptTrouble(name, KeptTroubleKind.setAside, aside: _base(aside));
  return (json: <String, Object?>{}, setAside: true);
}

/// Keeps a copy of [file] beside it as `<name>.unreadable-<time>`, for a
/// reader that drops some of what's in it (a record it can't read): the
/// next save writes the rest over the file, and nothing is lost.
/// The copy is only the user's (0600), as the file is.
void copyAside(File file) {
  final aside = _asideName(file);
  file.copySync(aside);
  setMode(aside, 0x180);
  noteKeptTrouble(
    _base(file.path),
    KeptTroubleKind.copiedAside,
    aside: _base(aside),
  );
}

/// [path]'s last part.
String _base(String path) => path.substring(path.lastIndexOf('/') + 1);

/// A free name for [file] set aside, logged: its name, then
/// `.unreadable-` and the local time to the microsecond, as the daemon's.
String _asideName(File file) {
  final t = DateTime.now();
  String two(int n) => '$n'.padLeft(2, '0');
  final at =
      '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}-'
      '${two(t.minute)}-${two(t.second)}.'
      '${'${t.millisecond * 1000 + t.microsecond}'.padLeft(6, '0')}';
  var aside = '${file.path}.unreadable-$at';
  for (
    var n = 2;
    FileSystemEntity.typeSync(aside) != FileSystemEntityType.notFound;
    n++
  ) {
    aside = '${file.path}.unreadable-$at-$n';
  }
  appLog.warn("set aside a file that doesn't read", {
    'file': _base(file.path),
    'as': _base(aside),
  });
  return aside;
}

/// Makes [dir] (and the folders it's in) unless it's there, [dir] only
/// the user's (0700).
void privateDir(Directory dir) {
  if (dir.existsSync()) return;
  dir.createSync(recursive: true);
  setMode(dir.path, 0x1c0);
}
