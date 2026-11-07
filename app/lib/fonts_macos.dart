import 'package:flutter/services.dart';

import 'package:nushi/fonts.dart';

/// The Mac's installed fonts, from NSFontManager
/// (`macos/Runner/MainFlutterWindow.swift`).
class MacFonts implements Fonts {
  const new();

  @override
  Future<List<String>?> monospaced() =>
      const MethodChannel('nushi/fonts').invokeListMethod<String>('monospaced');
}
