import 'package:flutter/services.dart';

import 'package:nushi/clipboard_files.dart';

/// The Mac's clipboard for what ⌘V attaches
/// (`macos/Runner/Clipboard.swift`).
const _clipboard = MethodChannel('nushi/clipboard');

/// The Mac's pasteboard's files and picture.
class MacClipboardFiles implements ClipboardFiles {
  const new();

  @override
  Future<List<String>> files() async =>
      await _clipboard.invokeListMethod<String>('files') ?? [];

  @override
  Future<Uint8List?> image() => _clipboard.invokeMethod<Uint8List>('image');
}
