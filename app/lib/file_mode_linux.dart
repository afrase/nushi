import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:nushi/file_mode.dart';

/// libc's chmod (Dart's files have none), Linux's 32-bit mode_t.
@Native<Int32 Function(Pointer<Uint8>, Uint32)>(symbol: 'chmod', isLeaf: true)
external int _chmod(Pointer<Uint8> path, int mode);

/// Linux's file permissions, through libc's chmod.
class LinuxFileModes implements FileModes {
  const new();

  @override
  void setMode(String path, int mode) {
    final c = Uint8List.fromList([...utf8.encode(path), 0]);
    if (_chmod(c.address, mode) != 0) {
      throw FileSystemException("can't make it private", path);
    }
  }
}
