/// The fonts installed on the machine (ADR 0097): on the Mac, AppKit's
/// (`fonts_macos.dart`).
abstract interface class Fonts {
  /// The installed monospaced families' names, or null when there's no
  /// answer.
  Future<List<String>?> monospaced();
}
