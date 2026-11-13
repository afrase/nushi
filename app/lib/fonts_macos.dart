import 'package:flutter/services.dart';

import 'package:nushi/fonts.dart';

/// The Mac's installed fonts, from NSFontManager
/// (`macos/Runner/MainFlutterWindow.swift`).
class MacFonts implements Fonts {
  const new();

  static const _channel = MethodChannel('nushi/fonts');

  @override
  Future<List<String>?> monospaced() =>
      _channel.invokeListMethod<String>('monospaced');

  @override
  Future<List<String>?> families() =>
      _channel.invokeListMethod<String>('families');

  /// The name AppKit's interface font (San Francisco) answers to: it's in
  /// no family list, and no other name reaches it.
  @override
  String get system => '.AppleSystemUIFont';
}
