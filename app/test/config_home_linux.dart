import 'dart:convert';
import 'dart:ffi';

@Native<Pointer<Uint8> Function(Size)>(symbol: 'malloc', isLeaf: true)
external Pointer<Uint8> _malloc(int size);

@Native<Void Function(Pointer<Void>)>(symbol: 'free', isLeaf: true)
external void _free(Pointer<Void> p);

@Native<Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32)>(
  symbol: 'setenv',
  isLeaf: true,
)
external int _setenv(Pointer<Uint8> name, Pointer<Uint8> value, int replace);

/// Sets the test process's `XDG_CONFIG_HOME` to [path] in libc's
/// environment, which the libraries it loads read (Dart's
/// `Platform.environment` keeps what it started with): enchant makes its
/// folder there when a dictionary opens (ADR 0104), and a test writes only
/// in a temp folder. Called before any test, as GLib reads it once.
void configHomeAt(String path) {
  final name = _cString('XDG_CONFIG_HOME');
  final value = _cString(path);
  try {
    if (_setenv(name, value, 1) != 0) {
      throw StateError('setenv XDG_CONFIG_HOME failed');
    }
  } finally {
    _free(name.cast());
    _free(value.cast());
  }
}

/// [s] as a NUL-terminated UTF-8 string in memory from malloc.
Pointer<Uint8> _cString(String s) {
  final bytes = utf8.encode(s);
  final p = _malloc(bytes.length + 1);
  p.asTypedList(bytes.length + 1)
    ..setAll(0, bytes)
    ..[bytes.length] = 0;
  return p;
}
