import 'package:nushi/desktop.dart';
import 'package:url_launcher/url_launcher.dart';

/// Linux's file manager, through GIO's default app for a folder
/// (url_launcher), never `xdg-open`. Showing a file selected
/// (FileManager1 over D-Bus) and opening one as text come later (ADR
/// 0102): until then a file's folder opens, and Open as text does nothing.
class LinuxDesktop implements Desktop {
  const new();

  @override
  Future<void> reveal(String path) =>
      openFolder(Uri.file(path).resolve('.').toFilePath());

  @override
  Future<void> openFolder(String folder) => launchUrl(Uri.directory(folder));

  @override
  Future<void> openAsText(String path) async {}
}
