// Settings › Keyboard shortcuts' caps (ADR 0146): a group's caps in one
// lane so its buttons and second keys line up, a second key under the name
// where it has no room beside it, the caps and the search growing with the
// text, and a pointed-at row tinting its cap.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show Tap;
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'shortcuts_harness.dart';

void main() {
  setUpAll(loadFonts);

  group('the caps', () {
    testWidgets('a row under the pointer tints its cap too, so in light the '
        'cap never turns paler than its row', (tester) async {
      final d = await shortcutsPage(tester, tokens: Tokens.light);
      Color? fill() => tester
          .widget<Tap>(
            find.descendant(of: keyOf('openFile'), matching: find.byType(Tap)),
          )
          .fill;
      expect(fill(), Tokens.light.lifted);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getTopLeft(rowOf('openFile')));
      await mouse.moveTo(tester.getCenter(inRow('openFile', 'Open file')));
      await tester.pumpAndSettle();
      expect(fill(), Color.alphaBlend(Tokens.light.hover, Tokens.light.lifted));
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(fill(), Tokens.light.lifted);
      await mouse.removePointer();
      d.dispose();
    }, variant: onMac);

    testWidgets('larger text makes the caps and the search taller, so the '
        'words keep their room', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final d = await shortcutsPage(tester);
      expect(tester.getSize(keyOf('find')).height, 28);
      expect(
        tester.getSize(find.byKey(const ValueKey('shortcuts-search'))).height,
        30,
      );
      await tapIt(tester, keyOf('find'));
      expect(tester.getSize(keyOf('find')).height, 28);
      expect(tester.takeException(), isNull);
      await pressKey(tester, LogicalKeyboardKey.escape);
      d.dispose();
    }, variant: onMac);

    testWidgets("on Linux a group's buttons and second keys line up however "
        'long each key is', (tester) async {
      shortcutsOnLinux();
      final d = await shortcutsPage(tester);
      final ids = ['palette', 'reloadPage', 'find', 'previousTab', 'nextTab'];
      final lefts = {for (final id in ids) tester.getTopLeft(clearOf(id)).dx};
      expect(lefts, hasLength(1), reason: '$lefts');
      final seconds = {
        for (final id in ['palette', 'previousTab', 'nextTab'])
          tester.getTopRight(find.byKey(ValueKey('shortcut-second-$id'))).dx,
      };
      expect(seconds, hasLength(1), reason: '$seconds');
      expect(expectCapsAtEdge(tester), greaterThan(20));
      d.dispose();
    }, variant: onMac);

    testWidgets('narrow on Linux, a second key that has no room beside the '
        "name goes under it, and isn't left out", (tester) async {
      shortcutsOnLinux();
      final d = await shortcutsPage(tester, size: const Size(560, 2600));
      Finder second(String id) => find.byKey(ValueKey('shortcut-second-$id'));
      for (final id in ['palette', 'previousTab', 'nextTab']) {
        expect(second(id), findsOne, reason: id);
        expect(
          tester.getRect(second(id)).right,
          lessThan(tester.getRect(clearOf(id)).left),
          reason: id,
        );
      }
      final name = tester.getRect(inRow('previousTab', 'Previous tab'));
      expect(
        tester.getRect(second('previousTab')).top,
        greaterThanOrEqualTo(name.bottom - 1),
      );
      // Its key stays on the name's line.
      expect(
        tester.getRect(keyOf('previousTab')).center.dy,
        moreOrLessEquals(name.center.dy, epsilon: 1),
      );
      // Under, it starts where the name does.
      expect(
        tester.getRect(second('previousTab')).left,
        moreOrLessEquals(name.left, epsilon: 0.5),
      );
      expect(tester.takeException(), isNull);
      d.dispose();
    }, variant: onMac);
  });
}
