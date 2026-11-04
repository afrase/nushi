// The transcript above the composer (ADR 0026): the scrollbar runs the
// pane's height beside both, but the list ends above the turn line, so a
// selection dragged onto the composer scrolls it, its toolbar stays in
// sight, and the thumb dragged up through a page keeps what's read still.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/scrollbar.dart';
import 'package:nushi/transcript_pages.dart';
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

Element _firstShown(WidgetTester tester) {
  final top = tester.getRect(find.byType(SelectionArea)).top;
  return find
      .byType(ItemView)
      .evaluate()
      .firstWhere(
        (e) =>
            tester.getRect(find.byElementPredicate((x) => x == e)).top >= top,
      );
}

double _topOf(WidgetTester tester, Element e) =>
    tester.getRect(find.byElementPredicate((x) => x == e)).top;

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

  testWidgets('the thumb dragged up as a page lands keeps what shows', (
    tester,
  ) async {
    final (d, paged) = await _window(tester, size: const Size(1400, 900));
    final hold = paged.hold = Completer<void>();
    final p = _scroll(tester);
    p.jumpTo(p.viewportDimension * 0.6);
    await tester.pump();
    await tester.pump();
    expect(paged.pages, isNotEmpty); // on its way, held
    p.jumpTo(p.viewportDimension * 0.9);
    await tester.pump();
    final bar = find
        .descendant(
          of: find.byType(OverBottom),
          matching: find.byType(MacScrollbar),
        )
        .first;
    final box = tester.getRect(bar);
    final painter =
        tester
                .widgetList<CustomPaint>(
                  find.descendant(of: bar, matching: find.byType(CustomPaint)),
                )
                .first
                .foregroundPainter!
            as ScrollbarPainter;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: box.center);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(Offset(box.right - 4, box.top + 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    Offset? on;
    for (var y = 0.0; y < box.height && on == null; y++) {
      if (painter.hitTestOnlyThumbInteractive(
        Offset(box.width - 6, y),
        PointerDeviceKind.mouse,
      )) {
        on = box.topLeft + Offset(box.width - 6, y + 2);
      }
    }
    await mouse.moveTo(on!);
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.down(on);
    await tester.pump();
    final seen = _firstShown(tester);
    // What the drag scrolls (a layout's correction doesn't notify).
    var px = p.pixels;
    var user = 0.0;
    void moved() {
      user += p.pixels - px;
      px = p.pixels;
    }

    p.addListener(moved);
    for (var i = 0; i < 10; i++) {
      if (i == 4) {
        paged.hold = null;
        hold.complete();
        await tester.pump();
        await tester.pump();
      }
      final top = _topOf(tester, seen);
      px = p.pixels;
      user = 0;
      await mouse.moveBy(const Offset(0, -0.5));
      await tester.pump();
      // What shows moves down by what the drag scrolled up, a few pixels.
      final by = _topOf(tester, seen) - top;
      expect(by, inInclusiveRange(0, 40), reason: 'move $i');
      expect(by + user, closeTo(0, 1), reason: 'move $i');
    }
    p.removeListener(moved);
    expect(_chat(d).older, lessThan(1000));
    await mouse.up();
    await _settle(tester, 20);
    await closeView(tester, d);
  }, variant: _mac);
}

ChatState _chat(Daemon d) => d.chats['c']!;
