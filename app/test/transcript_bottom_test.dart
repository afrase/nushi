// The transcript above the composer (ADR 0026): the scrollbar runs the
// pane's height beside both, but the list ends above the turn line, so a
// selection dragged onto the composer scrolls it and its toolbar stays in
// sight.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/turn_status.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'long_chat.dart';
import 'paged_chat.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

Future<(Daemon, PagedChat)> _window(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
}) async {
  viewport(tester, size);
  showDetails.value = false;
  final c = chat('c', 'claude', 'A long chat');
  final paged = PagedChat(c, longChat('c', turns: 100));
  final fake = FakeDaemon([c])..answer = paged.answer;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await _settle(tester);
  return (d, paged);
}

Future<void> _settle(WidgetTester tester, [int n = 40]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

ScrollPosition _scroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

void main() {
  setUpAll(loadFonts);

  testWidgets('a selection dragged down onto the composer scrolls the list', (
    tester,
  ) async {
    final (d, _) = await _window(tester);
    final p = _scroll(tester);
    p.jumpTo(p.maxScrollExtent / 2);
    await _settle(tester, 4);
    final list = tester.getRect(find.byType(SelectionArea));
    final status = tester.getRect(find.byType(TurnStatus));
    final was = p.pixels;
    final mouse = await tester.startGesture(
      Offset(list.center.dx, list.top + 200),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await mouse.moveTo(Offset(list.center.dx, list.top + 260));
    await tester.pump();
    await mouse.moveTo(Offset(list.center.dx, status.top + 60));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(p.pixels, greaterThan(was + 100));
    // The list ends where the turn line starts.
    expect(list.bottom, status.top);
    await mouse.up();
    await _settle(tester, 4);
    await closeView(tester, d);
  }, variant: _mac);

  for (final width in [1700.0, 720.0]) {
    testWidgets('the selection toolbar stays above the turn line, $width '
        'wide', (tester) async {
      final (d, _) = await _window(tester, size: Size(width, 1000));
      final p = _scroll(tester);
      p.jumpTo(p.maxScrollExtent / 2);
      await _settle(tester, 4);
      final list = tester.getRect(find.byType(SelectionArea));
      final status = tester.getRect(find.byType(TurnStatus));
      final x = list.left + (list.width - 32) / 2;
      final mouse = await tester.startGesture(
        Offset(x, list.top + 3),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await mouse.moveTo(Offset(x, status.top - 3));
      await tester.pump();
      await mouse.up();
      await _settle(tester, 6);
      final bar = find.byType(SelectionToolbar);
      expect(bar, findsOneWidget);
      expect(tester.getRect(bar).bottom, lessThanOrEqualTo(status.top));
      expect(tester.getRect(bar).top, greaterThanOrEqualTo(list.top));
      await render(tester, find.byType(NushiApp), 'selection_toolbar_$width');
      await closeView(tester, d);
    }, variant: _mac);
  }
}
