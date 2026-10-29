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
