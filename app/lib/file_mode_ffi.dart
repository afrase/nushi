import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

/// libc's chmod (Dart's files have none).
@Native<Int32 Function(Pointer<Uint8>, Uint16)>(symbol: 'chmod', isLeaf: true)
external int _chmod(Pointer<Uint8> path, int mode);

/// Sets [path]'s permissions to [mode] (0x180 is 0600, 0x1c0 0700).
void setMode(String path, int mode) {
  final c = Uint8List.fromList([...utf8.encode(path), 0]);
  if (_chmod(c.address, mode) != 0) {
    throw FileSystemException("can't make it private", path);
  }
}

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
