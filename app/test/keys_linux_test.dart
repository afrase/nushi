import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The app's keys on Linux (ADR 0102): held with Control where the Mac's
// take ⌘. Tests pair Linux's conventions and window with its platform, as a
// Linux machine runs them.

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

void _onLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow();

/// Presses [key] with [holding] held down, and settles unless [settle] is
/// false (a turn's clock runs).
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [LogicalKeyboardKey.controlLeft],
  bool settle = true,
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// The app on Linux on three chats, [select] shown, [width] wide.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  String select = 'a',
  double width = 1200,
}) async {
  _onLinux();
  viewport(tester, Size(width, 760));
  showDetails.value = false;
  final fake = FakeDaemon([
    chat('a', 'claude', 'Fix the login redirect', age: 2),
    chat('b', 'codex', 'Bump the API version', age: 1),
    chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 3),
  ]);
  final d = await fake.connect(tester);
  d.select(select);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return (d, fake);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('Ctrl+K opens the palette and ⌘K doesn’t; Ctrl+1 and '
      'Ctrl+Page Down switch chats', (tester) async {
    final (d, _) = await _app(tester);
    await _press(tester, LogicalKeyboardKey.keyK, [
      LogicalKeyboardKey.metaLeft,
    ]);
    expect(find.byType(Palette), findsNothing);
    await _press(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(Palette), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final order = [for (final c in chatOrder(d)) c.id];
    await _press(tester, LogicalKeyboardKey.digit1);
    expect(d.selectedId, order[0]);
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(d.selectedId, order[1]);
    await _press(tester, LogicalKeyboardKey.pageUp);
    expect(d.selectedId, order[0]);
    await _press(tester, LogicalKeyboardKey.digit3);
    expect(d.selectedId, order[2]);
    // ⌘ and a digit is nothing of the app's here.
    await _press(tester, LogicalKeyboardKey.digit1, [
      LogicalKeyboardKey.metaLeft,
    ]);
    expect(d.selectedId, order[2]);
    await closeView(tester, d);
  }, variant: _linux);
}
