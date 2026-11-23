import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What the preview's tests share (preview_*_test.dart): the app on a chat
// with its Files pane, and what's in that pane.

/// The app on [fake]'s chat `c`, its details hidden, at [size] in
/// [brightness] (the system's unless given), settled; then [file] in the
/// Files pane's preview when given, settled again.
Future<Daemon> previewApp(
  WidgetTester tester,
  FakeDaemon fake, {
  Size size = const Size(1700, 900),
  Brightness? brightness,
  String? file,
}) async {
  showDetails.value = false;
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  if (file == null) return d;
  d.chats['c']!.openInFiles(file);
  await tester.pumpAndSettle();
  return d;
}

/// What [f] finds in the Files pane.
Finder inPane(Finder f) =>
    find.descendant(of: find.byType(FilesPane), matching: f);
