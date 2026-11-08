import 'package:flutter/services.dart';

import 'package:nushi/clipboard_files.dart';

/// GTK's clipboard for what Ctrl+V attaches
/// (`linux/runner/clipboard.cc`).
const _clipboard = MethodChannel('nushi/clipboard');

/// GTK's clipboard's files and picture: a file manager's copied files
/// (file URIs of this machine's only), and a picture as PNG when the
/// clipboard holds no text.
class LinuxClipboardFiles implements ClipboardFiles {
  const new();

  @override
  Future<List<String>> files() async =>
      await _clipboard.invokeListMethod<String>('files') ?? [];

  @override
  Future<Uint8List?> image() => _clipboard.invokeMethod<Uint8List>('image');
}
