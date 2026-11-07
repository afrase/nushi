import 'package:flutter/foundation.dart';

/// What ⌘V attaches from the clipboard beside its text (ADR 0091): on the
/// Mac, its pasteboard (`clipboard_files_macos.dart`).
abstract interface class ClipboardFiles {
  /// The clipboard's files (Finder's copy: file URLs only, not a copied
  /// web link).
  Future<List<String>> files();

  /// The clipboard's picture as PNG, if it holds one and no text (cells
  /// copied from Numbers carry a PDF of themselves).
  Future<Uint8List?> image();
}
