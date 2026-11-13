import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';

import 'harness.dart';

void main() {
  testWidgets('a long menu filters as you type; arrows and Enter pick', (
    tester,
  ) async {
    String? picked;
    final names = ['apple', 'banana', 'cherry', 'date', 'elderberry', 'fig'];
    await tester.pumpWidget(
      themed(
        MenuField(
          entries: [
            for (final n in names)
              for (final c in ['red', 'green'])
                MenuEntry('$c $n', onPick: () => picked = '$c $n'),
          ],
          label: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget); // 12 rows: filtered

    await tester.enterText(find.byType(TextField), 'erry');
    await tester.pump();
    expect(find.textContaining('cherry'), findsNWidgets(2));
    expect(find.textContaining('apple'), findsNothing);

    // red cherry, green cherry, red elderberry, ...: the second one down.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, 'green cherry');
    expect(find.text('Filter'), findsNothing); // closed

    // Escape clears the field first, then closes.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fig');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining('apple'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsNothing);
  });

  // Deep review 2026-11-13, 16: a right-click on an inTap row (the
  // composer's Add files or photos) ran its pick and kept the menu open,
  // and swallowed the next Enter on it.
  testWidgets('a row picked in the tap is picked by a primary press, not '
      'a right-click; Enter still picks it after one', (tester) async {
    var picks = 0;
    await tester.pumpWidget(
      themed(
        Center(
          child: MenuIcon(
            Icons.add,
            tooltip: 'Add',
            entries: [
              MenuEntry('Add files', inTap: true, onPick: () => picks++),
              MenuEntry('Mention a file', onPick: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add files'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(picks, 0);
    expect(find.text('Add files'), findsOne, reason: 'the menu stays open');

    Focus.of(tester.element(find.text('Add files'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picks, 1);
    expect(find.text('Add files'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add files'));
    await tester.pumpAndSettle();
    expect(picks, 2);
  });

  // A list of hundreds (the installed fonts) opened at its top, the current
  // one out of sight a long scroll away.
  testWidgets('a long menu opens on its current row, and at its top with '
      'none or the first current', (tester) async {
    viewport(tester, const Size(800, 600));
    Future<void> open(int? current) async {
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: MenuField(
              key: ValueKey(current),
              entries: [
                for (var i = 0; i < 300; i++)
                  MenuEntry('Row $i', checked: i == current, onPick: () {}),
              ],
              label: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder row(int i) => find.ancestor(
      of: find.text('Row $i', findRichText: true),
      matching: find.byType(MenuItemButton),
    );
    Rect list() => tester.getRect(
      find.ancestor(of: row(0), matching: find.byType(Scrollable)).first,
    );

    await open(250);
    final shown = tester.getRect(row(250));
    expect(shown.top, greaterThan(list().top));
    expect(shown.bottom, lessThan(list().bottom));
    // About the middle of the list, rows on either side of it.
    expect(shown.center.dy, moreOrLessEquals(list().center.dy, epsilon: 16));
    expect(
      find.descendant(of: row(250), matching: find.byIcon(Icons.check)),
      findsOne,
    );
    // Enter still picks it, and the arrows go on from it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(row(251)).bottom, lessThanOrEqualTo(list().bottom));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    for (final current in [null, 0]) {
      await open(current);
      expect(
        tester.getRect(row(0)).top,
        moreOrLessEquals(list().top),
        reason: '$current',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  // The owner's report: a panel widget's ⋯ at the window's right opened
  // its menu off to one side. Flutter pushes a menu with no room on its
  // opener's right back to the window's edge; a trailing button's ends
  // under it, as macOS and Claude draw one.
  for (final (where, alignment, inset) in [
    ("a panel's side in from the window's right", Alignment.topRight, 16.0),
    ('with room on its right', Alignment.topCenter, 0.0),
  ]) {
    testWidgets("a trailing button's menu opens under it, $where, ending at "
        'its right edge', (tester) async {
      final (opener, menu) = await _opened(
        tester,
        alignment,
        inset: inset,
        trailing: true,
      );
      expect(menu.top, moreOrLessEquals(opener.bottom, epsilon: 2));
      expect(menu.right, moreOrLessEquals(opener.right, epsilon: 1));
      expect(Offset.zero & _window, _contains(menu));
    });
  }

  testWidgets('any other menu opens as it did: from its left edge with '
      'room', (tester) async {
    final (opener, menu) = await _opened(tester, Alignment.topCenter);
    expect(menu.left, moreOrLessEquals(opener.left, epsilon: 1));
  });

  testWidgets('any other menu opens as it did: without room, back in from '
      "the window's edge", (tester) async {
    final (opener, menu) = await _opened(tester, Alignment.topRight, inset: 16);
    expect(menu.right, moreOrLessEquals(_window.width, epsilon: 1));
    expect(menu.top, moreOrLessEquals(opener.bottom, epsilon: 2));
  });
}

const _window = Size(800, 400);

/// A ⋯ at [alignment] in the window, [inset] in from its side, its menu
/// opened ([trailing]: in [TrailingMenus]): its rect and the menu's.
Future<(Rect, Rect)> _opened(
  WidgetTester tester,
  Alignment alignment, {
  double inset = 0,
  bool trailing = false,
}) async {
  viewport(tester, _window);
  final icon = MenuIcon(
    Icons.more_horiz,
    tooltip: 'More',
    entries: [
      MenuEntry('Open on GitHub', onPick: () {}),
      MenuEntry('Unlink', onPick: () {}),
    ],
  );
  await tester.pumpWidget(
    themed(
      Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: trailing ? TrailingMenus(child: icon) : icon,
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();
  return (tester.getRect(find.byType(IconTap)), menuRect(tester));
}

/// The open menu's rect: its rows, and round them the panel's padding.
Rect menuRect(WidgetTester tester) => tester
    .getRect(find.byType(MenuItemButton).first)
    .expandToInclude(tester.getRect(find.byType(MenuItemButton).last))
    .inflate(5);

Matcher _contains(Rect r) =>
    predicate<Rect>((outer) => outer.intersect(r) == r, 'contains $r');
