// Settings › Keyboard shortcuts' rows (ADR 0146): one line each, the key
// a cap at the group's edge that never moves, No key under the pointer or
// the focus, Reset on a changed row, a click on the row that listens, Tab
// through each, a line under the name for a clash, a refusal or a note,
// narrow and on Linux; and goldens of a group in each state.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show KeyCapButton, Tap;
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/shortcut_row.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'shortcuts_harness.dart';

void main() {
  setUpAll(loadFonts);

  group('layout', () {
    for (final width in [1000.0, 720.0]) {
      testWidgets('No key, Reset and Take it move neither the key nor the '
          'buttons, ${width.toInt()} wide', (tester) async {
        final d = await shortcutsPage(tester, size: Size(width, 2600));
        Rect at(Finder f) => tester.getRect(f);
        await tester.ensureVisible(rowOf('pin'));
        await tester.pumpAndSettle();
        // The key's right edge and its line: a cap hugs its key.
        (double, double) edge() =>
            (at(keyOf('pin')).right, at(keyOf('pin')).top);
        final key = edge();
        final clear = at(clearOf('pin'));
        final row = at(rowOf('pin'));
        await clickShown(tester, clearOf('pin'));
        expect(edge(), key);
        expect(at(rowOf('pin')), row);
        final reset = at(resetOf('pin'));
        expect(reset.right, lessThan(clear.left));
        await tapIt(tester, resetOf('pin'));
        expect(edge(), key);
        expect(at(clearOf('pin')), clear);
        expect(at(rowOf('pin')), row);
        // A clash: its line and buttons come under the name; the key stays.
        await recordKey(tester, 'pin', LogicalKeyboardKey.backslash, [metaKey]);
        expect(edge(), key);
        expect(at(rowOf('pin')).top, row.top);
        expect(at(takeOf('pin')).top, greaterThan(at(keyOf('pin')).bottom));
        await tapIt(tester, takeOf('pin'));
        expect(edge(), key);
        expect(at(resetOf('pin')), reset);
        expect(at(rowOf('pin')), row);
        expect(expectCapsAtEdge(tester), greaterThan(30));
        expect(tester.takeException(), isNull);
        d.dispose();
      }, variant: onMac);
    }

    testWidgets('a row is one line, about 36 high, with no line kept empty '
        'under its name', (tester) async {
      final d = await shortcutsPage(tester);
      expect(tester.getSize(rowOf('find')).height, 36);
      expect(tester.getSize(keyOf('find')).height, KeyCapButton.height);
      // A short key's cap isn't a crumb.
      expect(tester.getSize(keyOf('find')).width, KeyCapButton.minWidth);
      // A line under the name makes it taller, and goes with it.
      await recordKey(tester, 'find', LogicalKeyboardKey.keyC, [metaKey]);
      expect(tester.getSize(rowOf('find')).height, greaterThan(36));
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(tester.getSize(rowOf('find')).height, 36);
      d.dispose();
    }, variant: onMac);

    testWidgets('a field listening goes on listening, its ring and all, as '
        'the window narrows and widens', (tester) async {
      final d = await shortcutsPage(tester);
      await tapIt(tester, keyOf('pin'));
      for (final width in [720.0, 1000.0, 720.0]) {
        await tester.binding.setSurfaceSize(Size(width, 2600));
        await tester.pumpAndSettle();
        expect(keyShows(tester, 'pin'), 'Press keys…', reason: '$width');
        expect(shortcutRecording.value, isTrue, reason: '$width');
      }
      await pressKey(tester, LogicalKeyboardKey.keyS, [metaKey, altKey]);
      expect(savedKeys(), {'pin': 'Alt+Cmd+S'});
      expect(shortcutRecording.value, isFalse);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-pin');
      // Started with a click, the key taken shows no ring: only the
      // chosen key's fill, not a cap that still listens.
      expect(ringOf(tester, 'pin'), 0);
      expect(isChosen(tester, 'pin'), isTrue);
      // A Tab away and back, the keyboard's focus shows it.
      await pressKey(tester, LogicalKeyboardKey.tab);
      await pressKey(tester, LogicalKeyboardKey.tab, [shiftKey]);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-pin');
      expect(ringOf(tester, 'pin'), 2);
      d.dispose();
    }, variant: onMac);

    testWidgets('narrow on Linux, a long key stays whole at its 12 points, '
        'the name beside it; a clash fits under it', (tester) async {
      shortcutsOnLinux();
      shortcutKeys.value = {'newChat': 'Alt+Shift+Cmd+PageDown'};
      // In the app, where Settings leaves the page least room.
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
        size: const Size(720, 900),
      );
      final cap = tester.getRect(keyOf('newChat'));
      final words = find.descendant(
        of: keyOf('newChat'),
        matching: find.text('Ctrl+Alt+Shift+Page Down', findRichText: true),
      );
      // Never scaled: drawn at its own size, inside its cap.
      expect(
        find.descendant(of: keyOf('newChat'), matching: find.byType(FittedBox)),
        findsNothing,
      );
      expect(tester.getRect(words).width, lessThanOrEqualTo(cap.width - 16));
      expect(tester.widget<RichText>(words).text.style?.fontSize, 12);
      // The name keeps its room left of the buttons.
      expect(
        tester.getRect(inRow('newChat', 'New chat')).right,
        lessThan(tester.getRect(resetOf('newChat')).left),
      );
      expect(cap.right, tester.getRect(keyOf('settings')).right);
      await recordKey(tester, 'newChat', LogicalKeyboardKey.keyS, [ctrlKey]);
      expect(takeOf('newChat'), findsOne);
      expect(tester.getRect(keyOf('newChat')).right, cap.right);
      expect(
        tester.getRect(takeOf('newChat')).right,
        lessThanOrEqualTo(tester.getRect(rowOf('newChat')).right),
      );
      expect(tester.takeException(), isNull);
      d.dispose();
    }, variant: onMac);

    testWidgets("where a clash's line and its buttons don't fit side by side, "
        'the buttons go under it, at its right end', (tester) async {
      final d = await shortcutsPage(tester, size: const Size(560, 2600));
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.bracketRight, [
        shiftKey,
        metaKey,
      ]);
      final line = tester.getRect(
        inRow('sidebar', "⇧⌘] is Next tab's second key"),
      );
      final take = tester.getRect(takeOf('sidebar'));
      final cancel = tester.getRect(
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      expect(take.top, greaterThan(line.bottom));
      expect(cancel.right, tester.getRect(keyOf('sidebar')).right);
      // No key isn't there while the clash is offered, its room kept.
      expect(clearOf('sidebar'), findsNothing);
      expect(tester.takeException(), isNull);
      // Wide, side by side.
      await tester.binding.setSurfaceSize(const Size(1000, 2600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(takeOf('sidebar')).center.dy,
        moreOrLessEquals(
          tester
              .getRect(inRow('sidebar', "⇧⌘] is Next tab's second key"))
              .center
              .dy,
          epsilon: 1,
        ),
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('on Linux a chosen Ctrl+Alt+R notes the shell keeps it; reset, '
        'the note goes and the key stays put', (tester) async {
      shortcutsOnLinux();
      final d = await shortcutsPage(tester);
      final key = tester.getRect(keyOf('pin')).right;
      // Ctrl+R is Reload page's there.
      await recordKey(tester, 'pin', LogicalKeyboardKey.keyR, [
        ctrlKey,
        altKey,
      ]);
      expect(savedKeys(), {'pin': 'Alt+Cmd+R'});
      expect(
        inkOf(tester, 'pin', 'A focused terminal keeps it for the shell'),
        Tokens.dark.textMuted,
      );
      expect(tester.getRect(keyOf('pin')).right, key);
      await tapIt(tester, resetOf('pin'));
      expect(
        inRow('pin', 'A focused terminal keeps it for the shell'),
        findsNothing,
      );
      expect(tester.getRect(keyOf('pin')).right, key);
      expect(tester.getSize(rowOf('pin')).height, 36);
      d.dispose();
    }, variant: onMac);
  });

  group('the row', () {
    testWidgets('No key shows only under the pointer or with the focus in its '
        'row; Reset shows all the time on a changed row', (tester) async {
      final d = await shortcutsPage(tester);
      expect(clearShown(tester, 'pin'), isFalse);
      expect(resetOf('pin'), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(inRow('pin', 'Pin chat')));
      await tester.pumpAndSettle();
      expect(clearShown(tester, 'pin'), isTrue);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(clearShown(tester, 'pin'), isFalse);
      // Hidden, it isn't hit: a click there goes to the row (it listens).
      await tester.tapAt(tester.getCenter(clearOf('pin')));
      await tester.pumpAndSettle();
      expect(savedKeys(), isEmpty);
      expect(keyShows(tester, 'pin'), 'Press keys…');
      await pressKey(tester, LogicalKeyboardKey.keyJ, [metaKey, altKey]);
      // Changed: Reset stays, the cap wears the accent's soft fill.
      expect(isChosen(tester, 'pin'), isTrue);
      expect(isChosen(tester, 'find'), isFalse);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(resetOf('pin'), findsOne);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: resetOf('pin'), matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        1,
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('a click anywhere on the row makes its key listen', (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      await tester.tap(inRow('pin', 'Pin chat'));
      await tester.pumpAndSettle();
      expect(keyShows(tester, 'pin'), 'Press keys…');
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-pin');
      await pressKey(tester, LogicalKeyboardKey.escape);
      d.dispose();
    }, variant: onMac);

    testWidgets('no key reads None on an outline with no fill', (tester) async {
      final d = await shortcutsPage(tester);
      shortcutKeys.value = {'pin': ''};
      await tester.pumpAndSettle();
      expect(keyShows(tester, 'pin'), 'None');
      expect(
        tester
            .widget<Tap>(
              find.descendant(of: keyOf('pin'), matching: find.byType(Tap)),
            )
            .fill,
        isNull,
      );
      expect(ringOf(tester, 'pin'), 1);
      d.dispose();
    }, variant: onMac);

    testWidgets("Tab reaches each key and its row's buttons in order, and No "
        'key shows once it has the focus', (tester) async {
      final d = await shortcutsPage(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      shortcutKeys.value = {'openFile': 'Alt+Cmd+O'};
      await tester.pumpAndSettle();
      // From the search field, every stop in the page's order: none of
      // the nav's between them.
      await tester.tap(find.byKey(const ValueKey('shortcuts-search')));
      await tester.pumpAndSettle();
      final order = <String?>[focusedShortcut()];
      for (var i = 0; i < 7; i++) {
        await pressKey(tester, LogicalKeyboardKey.tab);
        final k = focusedShortcut();
        order.add(k);
        // No key shows while it has the focus.
        if (k != null && k.startsWith('shortcut-clear-')) {
          expect(clearShown(tester, k.substring(15)), isTrue, reason: k);
        }
      }
      expect(order, [
        'shortcuts-search',
        'shortcut-clear-settings',
        'shortcut-key-settings',
        'shortcut-clear-newChat',
        'shortcut-key-newChat',
        'shortcut-reset-openFile',
        'shortcut-clear-openFile',
        'shortcut-key-openFile',
      ]);
      d.dispose();
    }, variant: onMac);

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

    testWidgets("a fixed key's row has no hover, hand or focus", (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      final quit = find.byKey(const ValueKey('shortcut-fixed-Quit'));
      expect(
        find.descendant(of: quit, matching: find.byType(Tap)),
        findsNothing,
      );
      expect(tester.widget<ShortcutRow>(quit).onTap, isNull);
      d.dispose();
    }, variant: onMac);
  });

  // The File group in each state a row has: an edited row beside a clash;
  // a refusal; and a chosen key, no key, a saved key not used and a row
  // listening.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final state in ['pending', 'refused', 'states']) {
      testWidgets('golden, $state, $name', (tester) async {
        final d = await shortcutsPage(tester, tokens: tokens);
        switch (state) {
          case 'pending':
            shortcutKeys.value = {'newChat': 'Shift+Cmd+N'};
            await tester.pumpAndSettle();
            await recordKey(tester, 'closeTab', LogicalKeyboardKey.keyS, [
              metaKey,
            ]);
          case 'refused':
            await recordKey(tester, 'closeTab', LogicalKeyboardKey.keyC, [
              metaKey,
            ]);
          default:
            shortcutKeys.value = {
              'newChat': 'Shift+Cmd+N',
              'openFile': '',
              'save': 'Cmd+C',
            };
            await tester.pumpAndSettle();
            await tapIt(tester, keyOf('closeTab'));
        }
        // The pointer and the focus away, as a golden is looked at; a row
        // listening keeps it.
        if (state != 'states') FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await expectLater(
          find.ancestor(
            of: rowOf('closeTab'),
            matching: find.byType(SettingsGroup),
          ),
          matchesGoldenFile('goldens/settings_shortcuts_${state}_$name.png'),
        );
        d.dispose();
      }, variant: onMac);
    }
  }
}
