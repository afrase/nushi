import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// The overlay scrollbar under a mouse, as on a Mac: in a 400×600 window,
/// a list of 200 rows of 40, so the thumb is 600 × 600/8000 tall at the
/// right edge.
void main() {
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);
  String? selected;

  Future<(ScrollController, TestGesture)> list(
    WidgetTester tester, {
    bool selectable = false,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(400, 600);
    addTearDown(tester.view.reset);
    final c = ScrollController();
    addTearDown(c.dispose);
    selected = null;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const NativeScroll(),
        home: _selectable(
          selectable,
          (s) => selected = s,
          ListView.builder(
            controller: c,
            itemExtent: 40,
            itemCount: 200,
            itemBuilder: (_, i) => Text('row $i'),
          ),
        ),
      ),
    );
    await tester.pump(); // the scrollbar's painter has the list's size
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(200, 300));
    addTearDown(mouse.removePointer);
    return (c, mouse);
  }

  ScrollbarPainter bar(WidgetTester tester) =>
      tester
              .widgetList<CustomPaint>(
                find.descendant(
                  of: find.byType(MacScrollbar),
                  matching: find.byType(CustomPaint),
                ),
              )
              .first
              .foregroundPainter!
          as ScrollbarPainter;

  double thickness(WidgetTester tester) => bar(tester).thickness;

  /// Moves the mouse near the right edge, which shows the thumb, wide.
  Future<void> near(WidgetTester tester, TestGesture mouse, double y) async {
    await mouse.moveTo(Offset(394, y));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('hidden until scrolled or approached; near, it widens', (
    tester,
  ) async {
    final (_, mouse) = await list(tester);
    final painter = bar(tester);
    expect(painter.fadeoutOpacityAnimation.value, 0);
    await near(tester, mouse, 20);
    expect(painter.fadeoutOpacityAnimation.value, 1);
    expect(thickness(tester), MacScrollbar.wide);
    await mouse.moveTo(const Offset(200, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(thickness(tester), MacScrollbar.thin);
    // It fades a moment after the pointer leaves.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(painter.fadeoutOpacityAnimation.value, 0);
  }, variant: mac);

  for (final selectable in [false, true]) {
    testWidgets('the mouse drags the thumb, and the list scrolls'
        '${selectable ? ' (selectable text, as the transcript)' : ''}', (
      tester,
    ) async {
      final (c, mouse) = await list(tester, selectable: selectable);
      await near(tester, mouse, 20);
      await mouse.down(const Offset(394, 20));
      await tester.pump();
      // Half the track's free length (596 less the thumb's 45): half the
      // list's.
      await mouse.moveBy(const Offset(0, 100));
      await tester.pump();
      await mouse.moveBy(const Offset(0, 176));
      await tester.pump();
      await mouse.up();
      await tester.pumpAndSettle();
      expect(
        c.offset,
        moreOrLessEquals(c.position.maxScrollExtent / 2, epsilon: 40),
      );
      expect(selected, isNull); // the drag selected no text
    }, variant: mac);
  }

  testWidgets('a click on the track pages towards it', (tester) async {
    final (c, mouse) = await list(tester);
    await near(tester, mouse, 500);
    await mouse.down(const Offset(394, 500));
    await mouse.up();
    await tester.pumpAndSettle();
    // A page is most of the window; the thumb doesn't jump to the click.
    expect(c.offset, greaterThan(400));
    expect(c.offset, lessThan(700));
  }, variant: mac);

  setUpAll(loadFonts);
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets(
      'thin while scrolling, wide on its track when near ($name)',
      (tester) => _looks(tester, tokens, name),
      variant: mac,
    );
  }
}

Widget _selectable(bool on, void Function(String) onSelected, Widget child) =>
    on
    ? SelectionArea(
        onSelectionChanged: (s) {
          if (s != null && s.plainText.isNotEmpty) onSelected(s.plainText);
        },
        child: child,
      )
    : child;

/// Two lists in the app's theme: the left one just scrolled (thin), the
/// right one with the pointer near its edge (wide, on its track).
Future<void> _looks(WidgetTester tester, Tokens tokens, String name) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(320, 200);
  addTearDown(tester.view.reset);
  final left = ScrollController();
  addTearDown(left.dispose);
  final theme = NushiTheme(tokens);
  Widget rows(ScrollController? c) => Expanded(
    child: ListView.builder(
      controller: c,
      itemExtent: 24,
      itemCount: 60,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Text('row $i', style: theme.ui(tokens.textSecondary)),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NativeScroll(),
      theme: theme.toThemeData(),
      home: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            rows(left),
            VerticalDivider(width: 1, color: tokens.borderSubtle),
            rows(null),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  left.jumpTo(200);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(200, 100));
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(const Offset(314, 30));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('goldens/scrollbar_$name.png'),
  );
}
