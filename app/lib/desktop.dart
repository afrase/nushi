/// The system's file manager and default apps, for a file the user asks
/// to see (ADR 0097): on the Mac, Finder and Launch Services
/// (`desktop_macos.dart`).
abstract interface class Desktop {
  /// Shows [path] selected in its folder.
  Future<void> reveal(String path);

  /// Opens [folder].
  Future<void> openFolder(String folder);

  /// Opens [path] in the default text editor, as text whatever its type.
  Future<void> openAsText(String path);
}
