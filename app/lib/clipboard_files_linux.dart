import 'package:flutter/foundation.dart';

import 'package:nushi/clipboard_files.dart';

/// GTK's clipboard for what Ctrl+V attaches, not read yet: the runner's
/// `nushi/clipboard` (`linux/runner/clipboard.cc`) answers it later
/// (ADR 0102). Until then a paste attaches only its text.
class LinuxClipboardFiles implements ClipboardFiles {
  const new();

  @override
  Future<List<String>> files() async => const [];

  @override
  Future<Uint8List?> image() async => null;
}
