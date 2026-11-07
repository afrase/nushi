import 'dart:io';

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

/// Makes [dir] (and the folders it's in) unless it's there, [dir] only
/// the user's (0700).
void privateDir(Directory dir) {
  if (dir.existsSync()) return;
  dir.createSync(recursive: true);
  setMode(dir.path, 0x1c0);
}
