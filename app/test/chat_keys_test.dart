import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';

/// Two folders' chats and an archived one: the sidebar lists nushi's
/// (b, then a: the newest first), then site's (c), the archived (z) in
/// its collapsed group.
final List<Chat> _chats = [
  chat('a', 'claude', 'Fix the login redirect', age: 2),
  chat('b', 'codex', 'Bump the API version', age: 1),
  chat('c', 'claude', 'Release notes', folder: '/Users/me/site', age: 3),
  chat('z', 'claude', 'Old work')..archived = true,
];

Future<Daemon> _app(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1200, 700);
  addTearDown(tester.view.reset);
  final d = await FakeDaemon(_chats).connect(tester);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('holding ⌘ alone numbers the chats, the archived left out', (
    tester,
  ) async {
    await _app(tester);
    expect(chatOrder(tester.daemonOf()).map((c) => c.id), ['b', 'a', 'c']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('⌘1'), findsNothing); // not yet: a shortcut, maybe
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('⌘1'), findsOneWidget);
    expect(find.text('⌘3'), findsOneWidget);
    expect(find.text('⌘4'), findsNothing); // z is archived
    // Top to bottom: b's row above a's above c's.
    final y = [
      for (final n in [1, 2, 3]) tester.getCenter(find.text('⌘$n')).dy,
    ];
    expect(y, orderedEquals([...y]..sort()));
    expect(
      tester.getCenter(find.text('⌘1')).dy,
      closeTo(tester.getCenter(find.text('Bump the API version')).dy, 3),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text('⌘1'), findsNothing);
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('a quick shortcut doesn’t show the numbers', (tester) async {
    await _app(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('⌘1'), findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    tester.daemonOf().dispose();
  }, variant: macOS);

  testWidgets('⌘1–⌘9 open a chat; ⌘[ and ⌘] step through them, wrapping', (
    tester,
  ) async {
    final d = await _app(tester);
    await _press(tester, LogicalKeyboardKey.digit2);
    expect(d.selectedId, 'a');
    await _press(tester, LogicalKeyboardKey.digit9); // no ninth: stays
    expect(d.selectedId, 'a');
    await _press(tester, LogicalKeyboardKey.bracketRight);
    expect(d.selectedId, 'c');
    await _press(tester, LogicalKeyboardKey.bracketRight); // wraps
    expect(d.selectedId, 'b');
    await _press(tester, LogicalKeyboardKey.bracketLeft); // and back
    expect(d.selectedId, 'c');
    await _press(tester, LogicalKeyboardKey.digit1);
    expect(d.selectedId, 'b');
    d.dispose();
  }, variant: macOS);

  testWidgets('from the Jira view too, which takes ⌥⌘ for its lists', (
    tester,
  ) async {
    final d = await _app(tester);
    d.showJira(open: true);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.digit3);
    expect(d.selectedId, 'c');
    expect(d.jiraOpen, isFalse);
    d.dispose();
  }, variant: macOS);
}

extension on WidgetTester {
  Daemon daemonOf() => widget<NushiApp>(find.byType(NushiApp)).daemon;
}
