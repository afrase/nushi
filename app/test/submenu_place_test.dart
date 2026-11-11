import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

// The owner's report: under the composer, the model menu's More models
// opened wholly above its row, up and to the right of the menu, so the
// pointer left both on its way across. Flutter opens a submenu with no
// room under its row above it; macOS slides one up only as far as it must.
void main() {
  setUpAll(loadFonts);

  for (final (what, rows, window) in [
    ('plain', 8, const Size(800, 400)),
    ('filtered', 12, const Size(800, 700)),
  ]) {
    testWidgets('a $what submenu with no room under its row slides up '
        "beside it, to its menu's bottom", (tester) async {
      await _open(tester, Alignment.bottomLeft, rows, window: window);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final row = _row(tester, 'More');
      final menu = _panel(tester, find.text('More'));
      final sub = _panel(tester, find.text('Sub 2'));
      expect(sub.height, greaterThan(window.height - row.top)); // no room
      expect(sub.top, lessThan(row.top));
      expect(sub.bottom, greaterThanOrEqualTo(row.bottom));
      expect(sub.bottom, moreOrLessEquals(menu.bottom, epsilon: 0.01));
      expect(sub.left, moreOrLessEquals(row.right, epsilon: 1));
      expect(Offset.zero & window, _contains(sub));
    }, variant: _mac);

    testWidgets('a $what submenu with room under its row opens level with '
        'it, as it did', (tester) async {
      await _open(tester, Alignment.topLeft, rows, window: window);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final row = _row(tester, 'More');
      expect(tester.getRect(_firstOf(rows)).top, row.top);
      expect(
        _panel(tester, find.text('Sub 2')).left,
        moreOrLessEquals(row.right, epsilon: 1),
      );
    }, variant: _mac);

    testWidgets('a $what submenu is in its place the first frame it shows', (
      tester,
    ) async {
      await _open(tester, Alignment.bottomLeft, rows, window: window);
      await tester.tap(find.text('More'));
      // Flat while it's measured: nothing of it shows.
      await tester.pump();
      expect(_panel(tester, find.text('Sub 2')).height, 0);
      expect(tester.getSize(_clip(find.text('Sub 2'))), Size.zero);
      await render(tester, find.byType(MaterialApp), 'submenu_flat_$what');
      await tester.pump();
      final shown = _panel(tester, find.text('Sub 2'));
      expect(shown.height, greaterThan(200));
      expect(Offset.zero & window, _contains(shown));
      expect(shown.bottom, _panel(tester, find.text('More')).bottom);
      await tester.pumpAndSettle();
      expect(_panel(tester, find.text('Sub 2')), shown);
    }, variant: _mac);
  }

  testWidgets('typing in a slid-up submenu’s filter leaves the field where '
      'it is: the list’s bottom comes up', (tester) async {
    await _open(tester, Alignment.bottomLeft, 12, window: const Size(800, 700));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(TextField));
    final before = _panel(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'sub 1');
    await tester.pumpAndSettle();
    expect(find.text('Sub 2'), findsNothing);
    expect(find.text('Sub 11'), findsOneWidget);
    final after = _panel(tester, find.byType(TextField));
    expect(tester.getRect(find.byType(TextField)), field);
    expect(after.top, before.top);
    expect(after.bottom, lessThan(before.bottom - 100));
    // And back, where it opened.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(_panel(tester, find.byType(TextField)), before);
  }, variant: _mac);

  for (final (what, rows, window) in [
    ('plain', 10, const Size(800, 260)),
    ('filtered', 12, const Size(800, 400)),
  ]) {
    testWidgets('a $what submenu taller than the window fills it from the '
        'top', (tester) async {
      await _open(tester, Alignment.bottomLeft, rows, window: window);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final row = _row(tester, 'More');
      final sub = _panel(tester, _firstOf(rows));
      expect(sub.top, 8);
      expect(sub.bottom, window.height - 8);
      expect(sub.left, moreOrLessEquals(row.right, epsilon: 1));
      // From its top: nothing scrolled it while it was measured.
      final scroll = find.ancestor(
        of: _firstOf(rows),
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(scroll.first).position.pixels, 0);
    }, variant: _mac);
  }

  testWidgets('with no room on its right a submenu slides up on its row’s '
      'left, against it', (tester) async {
    // Rows too wide for the room right of the menu.
    await _open(tester, Alignment.bottomRight, 8, name: 'A longer row');
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    final row = _row(tester, 'More');
    final menu = _panel(tester, find.text('More'));
    final sub = _panel(tester, find.text('A longer row 2'));
    // Its box is as wide as its rows (Flutter's is the theme's least
    // width, with the panel at its start: a gap on this side).
    expect(sub.right, moreOrLessEquals(row.left, epsilon: 1));
    expect(sub.top, lessThan(row.top));
    expect(sub.bottom, greaterThanOrEqualTo(row.bottom));
    expect(sub.bottom, moreOrLessEquals(menu.bottom, epsilon: 0.01));
    expect(Offset.zero & _window, _contains(sub));
  }, variant: _mac);

  testWidgets('a submenu’s submenu slides up beside its own row', (
    tester,
  ) async {
    viewport(tester, _window);
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.bottomLeft,
          child: MenuField(
            entries: [
              MenuEntry('One', onPick: () {}),
              MenuEntry(
                'More',
                submenu: [
                  MenuEntry('Sub 1', onPick: () {}),
                  MenuEntry('Deeper', submenu: _subs(8, 'Deep')),
                  MenuEntry('Sub 2', onPick: () {}),
                ],
              ),
            ],
            label: const Text('open'),
          ),
        ),
      ),
    );
    for (final label in ['open', 'More', 'Deeper']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    final row = _row(tester, 'Deeper');
    final menu = _panel(tester, find.text('Deeper'));
    final sub = _panel(tester, find.text('Deep 2'));
    expect(sub.left, moreOrLessEquals(row.right, epsilon: 1));
    expect(sub.top, lessThan(row.top));
    expect(sub.bottom, moreOrLessEquals(menu.bottom, epsilon: 0.01));
    expect(Offset.zero & _window, _contains(sub));
  }, variant: _mac);

  testWidgets('a slid-up submenu opens under the pointer and takes the '
      'keys as before', (tester) async {
    String? picked;
    await _open(tester, Alignment.bottomLeft, 8, onPick: (p) => picked = p);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('Sub 2'), findsOneWidget);
    // Straight across from the row is the submenu.
    final row = _row(tester, 'More');
    final sub = _panel(tester, find.text('Sub 2'));
    expect(sub.contains(Offset(row.right + 20, row.center.dy)), isTrue);
    // → goes into it, at its first row; ← closes it, → opens it again, in
    // its place and at its first row; ↓ and Enter pick.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Sub 2'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_panel(tester, find.text('Sub 2')), sub);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, 'Sub 2');
    expect(find.text('More'), findsNothing); // closed
  }, variant: _mac);

  // The model menu under the composer, More models open, the whole window.
  for (final width in [720.0, 1700.0]) {
    testWidgets('More models beside its row at the window’s bottom, '
        '$width wide', (tester) async {
      final window = Size(width, 760);
      viewport(tester, window);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('nushi/fonts'),
            (_) async => <String>[],
          );
      paneWidths.value = {};
      final fake = FakeDaemon([chat('c', 'claude', 'Plant the beds')])
        ..answer = ((input) => switch (input) {
          GetChatRequest() => GetChatResponse(
            config: [
              ConfigOption(
                id: 'model',
                name: 'Model',
                category: 'model',
                current: 'm1',
                values: [
                  for (var i = 1; i <= 18; i++)
                    ConfigValue(value: 'm$i', name: 'Model $i'),
                ],
              ),
              ConfigOption(
                id: 'effort',
                name: 'Effort',
                category: 'thought_level',
                current: 'high',
                values: [
                  for (final e in ['Low', 'Medium', 'High'])
                    ConfigValue(value: e.toLowerCase(), name: e),
                ],
              ),
            ],
          ),
          _ => null,
        });
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Model, Effort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('More models'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final row = _row(tester, 'More models');
      final menu = _panel(tester, find.text('More models'));
      final sub = _panel(tester, find.byType(TextField).last);
      expect(sub.top, lessThan(row.top));
      expect(sub.bottom, moreOrLessEquals(menu.bottom, epsilon: 0.01));
      expect(Offset.zero & window, _contains(sub));
      // Beside the menu, on whichever side has the room.
      expect(
        sub.left >= row.right - 1 || sub.right <= row.left + 1,
        isTrue,
        reason: '$sub beside $row',
      );
      await render(
        tester,
        find.byType(NushiApp),
        'more_models_${width.toInt()}',
      );
      d.dispose();
    }, variant: _mac);
  }
}

const _window = Size(800, 400);

List<MenuEntry> _subs(int n, String name, [ValueChanged<String>? onPick]) => [
  for (var i = 1; i <= n; i++)
    MenuEntry('$name $i', onPick: () => onPick?.call('$name $i')),
];

/// A menu field at [alignment] in the [window], its menu open: two rows,
/// then More, a submenu of [rows] rows called [name] 1, 2… (past ten it
/// has the filter).
Future<void> _open(
  WidgetTester tester,
  Alignment alignment,
  int rows, {
  Size window = _window,
  String name = 'Sub',
  ValueChanged<String>? onPick,
}) async {
  viewport(tester, window);
  await tester.pumpWidget(
    themed(
      Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: MenuField(
            entries: [
              MenuEntry('One', onPick: () {}),
              MenuEntry('Two', onPick: () {}),
              MenuEntry('More', submenu: _subs(rows, name, onPick)),
            ],
            label: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The first thing in the open submenu of [rows] rows: its filter field
/// past ten, else its first row.
Finder _firstOf(int rows) => rows > 10
    ? find.byType(TextField)
    : find.ancestor(
        of: find.text('Sub 1'),
        matching: find.byType(MenuItemButton),
      );

/// The row that opens the submenu named [label].
Rect _row(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(SubmenuButton))
      .first, // the nearest: a submenu's rows are in its button
);

/// The panel of the open menu [inside] is in, as drawn.
Rect _panel(WidgetTester tester, Finder inside) => tester.getRect(
  find
      .ancestor(
        of: inside,
        matching: find.byWidgetPredicate(
          (w) => w is Material && w.type == MaterialType.canvas,
        ),
      )
      .first,
);

/// What clips the open menu [inside] is in to the size Flutter gives it.
Finder _clip(Finder inside) =>
    find.ancestor(of: inside, matching: find.byType(UnconstrainedBox)).first;

Matcher _contains(Rect r) =>
    predicate<Rect>((outer) => outer.intersect(r) == r, 'contains $r');
