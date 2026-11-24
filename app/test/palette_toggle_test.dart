import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/open_file.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// One picker at a time (docs/design.md's Dialogs): the palette's key, or
// its menu item, opens it and closes it again; the file opener's key over
// the palette, or the palette's over the file opener, puts one in the
// other's place. On Linux through the app's Shortcuts alone.

/// The app on chat c; Linux's window and conventions on Linux.
Future<Daemon> _app(WidgetTester tester) {
  if (defaultTargetPlatform == TargetPlatform.linux) {
    native
      ..window = const LinuxWindow()
      ..conventions = linuxConventions;
  }
  return openApp(
    tester,
    FakeDaemon([chat('c', 'claude', 'Tidy the note list')]),
    size: const Size(1200, 700),
  );
}

/// How many palettes and file openers show.
(int, int) _open() => (
  find.byType(Palette).evaluate().length,
  find.byType(OpenFileBox).evaluate().length,
);

void main() {
  setUpAll(loadFonts);

  testWidgets("the palette's key opens it and closes it", (tester) async {
    final d = await _app(tester);
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (1, 0));
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (0, 0));
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (1, 0));
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets('three presses in one frame leave one palette at most', (
    tester,
  ) async {
    final d = await _app(tester);
    final command = switch (conventions.commandKey) {
      CommandKey.meta => LogicalKeyboardKey.metaLeft,
      CommandKey.control => LogicalKeyboardKey.controlLeft,
    };
    await tester.sendKeyDownEvent(command);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    }
    await tester.sendKeyUpEvent(command);
    await tester.pumpAndSettle();
    expect(find.byType(Palette).evaluate().length, lessThanOrEqualTo(1));
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("the menu bar's Command Palette… opens it and closes it", (
    tester,
  ) async {
    final d = await _app(tester);
    final item = viewItems(tester)
        .firstWhere((i) => i.label == 'Command Palette…');
    item.onSelected!();
    await tester.pumpAndSettle();
    expect(_open(), (1, 0));
    item.onSelected!();
    await tester.pumpAndSettle();
    expect(_open(), (0, 0));
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("the file opener's key over the palette puts it in the "
      "palette's place, and the palette's key over it the reverse", (
    tester,
  ) async {
    final d = await _app(tester);
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (1, 0));
    await press(tester, LogicalKeyboardKey.keyP, cmd: true);
    expect(_open(), (0, 1));
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (1, 0));
    await press(tester, LogicalKeyboardKey.keyP, cmd: true);
    expect(_open(), (0, 1));
    await press(tester, LogicalKeyboardKey.keyP, cmd: true);
    expect(_open(), (0, 0));
    await closeView(tester, d);
  }, variant: macAndLinux);

  testWidgets("the file opener's key over the palette, with no chat shown "
      'to open a file of, leaves the palette open', (tester) async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      native
        ..window = const LinuxWindow()
        ..conventions = linuxConventions;
    }
    final d = await openApp(
      tester,
      FakeDaemon([]),
      size: const Size(1200, 700),
    );
    await press(tester, LogicalKeyboardKey.keyK, cmd: true);
    expect(_open(), (1, 0));
    await press(tester, LogicalKeyboardKey.keyP, cmd: true);
    expect(_open(), (1, 0));
    await closeView(tester, d);
  }, variant: macAndLinux);
}
