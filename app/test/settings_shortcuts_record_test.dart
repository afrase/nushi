// Settings › Keyboard shortcuts (ADR 0146): recording a key: a click or
// Enter listens, Esc stops it, what a keyboard reports is saved as it
// comes, a held key's repeats run nothing, and the menu bar is quiet
// while a field listens.
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'shortcuts_harness.dart';

/// Counts the app's requests to quit, and cancels each.
class _ExitAsks with WidgetsBindingObserver {
  int count = 0;

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    count++;
    return AppExitResponse.cancel;
  }
}

void main() {
  setUpAll(loadFonts);

  group('recording', () {
    testWidgets('a click listens, and the keys pressed are saved', (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      await tapIt(tester, keyOf('sidebar'));
      expect(keyShows(tester, 'sidebar'), 'Press keys…');
      expect(shortcutRecording.value, isTrue);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-sidebar',
      );
      // A modifier alone waits.
      await tester.sendKeyDownEvent(metaKey);
      await tester.sendKeyDownEvent(altKey);
      await tester.pumpAndSettle();
      expect(keyShows(tester, 'sidebar'), 'Press keys…');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(altKey);
      await tester.sendKeyUpEvent(metaKey);
      await tester.pumpAndSettle();
      expect(savedKeys(), {'sidebar': 'Alt+Cmd+S'});
      expect(keyShows(tester, 'sidebar'), '⌥⌘S');
      expect(shortcutRecording.value, isFalse);
      expect(isChosen(tester, 'sidebar'), isTrue);
      d.dispose();
    }, variant: onMac);

    testWidgets('⇧⌘} as a keyboard reports it is saved as ⇧⌘], and is '
        "Next tab's own second key, so no clash", (tester) async {
      final d = await shortcutsPage(tester);
      await recordKey(tester, 'nextTab', LogicalKeyboardKey.braceRight, [
        shiftKey,
        metaKey,
      ], PhysicalKeyboardKey.bracketRight);
      expect(savedKeys(), {'nextTab': 'Shift+Cmd+]'});
      expect(keyShows(tester, 'nextTab'), '⇧⌘]');
      d.dispose();
    }, variant: onMac);

    testWidgets("a French keyboard's shifted symbols are saved as they come, "
        'not as the US keys that make them', (tester) async {
      final d = await shortcutsPage(tester);
      // ⇧⌘ on ù reports %, which is not ⇧⌘5 there; on its , key, ?.
      await recordKey(tester, 'pin', LogicalKeyboardKey.percent, [
        shiftKey,
        metaKey,
      ], PhysicalKeyboardKey.quote);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.question, [
        shiftKey,
        metaKey,
      ], PhysicalKeyboardKey.keyM);
      expect(savedKeys(), {'pin': 'Shift+Cmd+%', 'sidebar': 'Shift+Cmd+?'});
      expect(keyShows(tester, 'pin'), '⇧⌘%');
      d.dispose();
    }, variant: onMac);

    testWidgets('Esc while listening stops it, not Settings; a second Esc '
        'closes Settings', (tester) async {
      final d = await shortcutsPage(tester);
      final before = shortcutKeys.value;
      await tapIt(tester, keyOf('find'));
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsNothing);
      expect(shortcutKeys.value, same(before));
      expect(keyShows(tester, 'find'), '⌘F');
      expect(shortcutRecording.value, isFalse);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsOne);
      d.dispose();
    }, variant: onMac);

    testWidgets("started with Enter, Enter's repeat and lifting don't end "
        'it', (tester) async {
      final d = await shortcutsPage(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      focusOf(tester, 'settings').requestFocus();
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-settings',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(keyShows(tester, 'settings'), 'Press keys…');
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(keyShows(tester, 'settings'), 'Press keys…');
      expect(savedKeys(), isEmpty);
      await pressKey(tester, LogicalKeyboardKey.escape);
      d.dispose();
    }, variant: onMac);

    testWidgets("the menu bar's keys go while a field listens and come "
        'back after; closing Settings mid-record throws nothing', (
      tester,
    ) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      PlatformMenuItem reload() =>
          viewItems(tester).firstWhere((m) => m.label == 'Reload Page');
      expect(reload().shortcut, isNotNull);
      await tapIt(tester, keyOf('reloadPage'));
      expect(reload().shortcut, isNull);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(reload().shortcut, isNotNull);
      expect(d.settingsOpen, isNotNull);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(d.settingsOpen, isNull);
      // Again, and Settings shut by a click on the dim.
      d.openSettings(section: SettingsSection.shortcuts);
      await tester.pumpAndSettle();
      await tapIt(tester, keyOf('reloadPage'));
      expect(reload().shortcut, isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(d.settingsOpen, isNull);
      expect(shortcutRecording.value, isFalse);
      expect(reload().shortcut, isNotNull);
      d.dispose();
    }, variant: onMac);

    testWidgets("a held key's repeats after it's taken stay the page's, so "
        "the menu bar, its keys back, doesn't run them", (tester) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      // ⌘D is Pin chat's: a clash, the focus goes to Cancel; ⌥⌘S is
      // taken. Either way the menu has its keys again before the repeats.
      for (final (key, holding) in [
        (LogicalKeyboardKey.keyD, [metaKey]),
        (LogicalKeyboardKey.keyS, [altKey, metaKey]),
      ]) {
        await tapIt(tester, keyOf('sidebar'));
        for (final k in holding) {
          await tester.sendKeyDownEvent(k);
        }
        expect(await tester.sendKeyDownEvent(key), isTrue);
        await tester.pumpAndSettle();
        expect(shortcutRecording.value, isFalse);
        expect(await tester.sendKeyRepeatEvent(key), isTrue);
        expect(await tester.sendKeyRepeatEvent(key), isTrue);
        expect(await tester.sendKeyUpEvent(key), isTrue);
        for (final k in holding.reversed) {
          await tester.sendKeyUpEvent(k);
        }
        await tester.pumpAndSettle();
        if (find.text('Cancel').evaluate().isNotEmpty) {
          await tapIt(tester, find.text('Cancel'));
        }
      }
      expect(d.settingsOpen, isNotNull);
      expect(savedKeys(), {'sidebar': 'Alt+Cmd+S'});
      d.dispose();
    }, variant: onMac);

    testWidgets('on Linux AltGr alone is held, not taken', (tester) async {
      shortcutsOnLinux();
      final d = await shortcutsPage(tester);
      await tapIt(tester, keyOf('sidebar'));
      await tester.sendKeyDownEvent(ctrlKey);
      // GTK's ISO_Level3_Shift, the right Alt key.
      const altRight = PhysicalKeyboardKey.altRight;
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altGraph,
        physicalKey: altRight,
      );
      await tester.pumpAndSettle();
      expect(shortcutRecording.value, isTrue);
      expect(keyShows(tester, 'sidebar'), 'Press keys…');
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.altGraph,
        physicalKey: altRight,
      );
      await tester.sendKeyUpEvent(ctrlKey);
      await tester.pumpAndSettle();
      expect(shortcutRecording.value, isFalse);
      expect(savedKeys(), {'sidebar': 'Cmd+F6'});
      d.dispose();
    }, variant: onMac);

    testWidgets("on Linux a refused Ctrl+Q's repeats don't quit; lifted, it "
        'quits again', (tester) async {
      shortcutsOnLinux();
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      final exits = _ExitAsks();
      tester.binding.addObserver(exits);
      addTearDown(() => tester.binding.removeObserver(exits));
      await tapIt(tester, keyOf('sidebar'));
      await tester.sendKeyDownEvent(ctrlKey);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: rowOf('sidebar'),
          matching: find.textContaining('It quits Nushi', findRichText: true),
        ),
        findsOne,
      );
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      expect(exits.count, 0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(ctrlKey);
      await tester.pumpAndSettle();
      expect(exits.count, 1);
      d.dispose();
    }, variant: onMac);

    testWidgets("the Settings key's repeats, just recorded or in a clash, "
        "don't shut Settings; lifted, it does", (tester) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      // ⌥⌘. recorded on the Settings row, then pressed on Sidebar's: a
      // clash, the focus on Cancel.
      for (final (id, key, holding) in [
        ('settings', LogicalKeyboardKey.period, [altKey, metaKey]),
        ('sidebar', LogicalKeyboardKey.period, [altKey, metaKey]),
      ]) {
        await tapIt(tester, keyOf(id));
        for (final k in holding) {
          await tester.sendKeyDownEvent(k);
        }
        await tester.sendKeyDownEvent(key);
        await tester.pumpAndSettle();
        expect(shortcutRecording.value, isFalse);
        // Each repeat on its own: two toggles would open it again.
        for (var i = 0; i < 2; i++) {
          await tester.sendKeyRepeatEvent(key);
          await tester.pumpAndSettle();
          expect(d.settingsOpen, isNotNull, reason: id);
        }
        await tester.sendKeyUpEvent(key);
        for (final k in holding.reversed) {
          await tester.sendKeyUpEvent(k);
        }
        await tester.pumpAndSettle();
      }
      expect(savedKeys(), {'settings': 'Alt+Cmd+.'});
      expect(takeOf('sidebar'), findsOne);
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      await pressKey(tester, LogicalKeyboardKey.period, [altKey, metaKey]);
      expect(d.settingsOpen, isNull);
      d.dispose();
    }, variant: onMac);
  });
}
