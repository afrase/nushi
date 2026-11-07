import 'dart:io';

import 'package:nushi/desktop.dart';

/// The Mac's Finder and default apps, through `open`.
class MacDesktop implements Desktop {
  const new();

  @override
  Future<void> reveal(String path) => _open(['-R', path]);

  @override
  Future<void> openFolder(String folder) => _open([folder]);

  @override
  Future<void> openAsText(String path) => _open(['-t', path]);

  static Future<void> _open(List<String> args) =>
      Process.run('/usr/bin/open', args);
}
