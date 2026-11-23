// Settings › Keyboard shortcuts (ADR 0146): the keys refused and why, a
// key another action has offered with Take it, and saved keys that
// aren't used.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'shortcuts_harness.dart';

void main() {
  setUpAll(loadFonts);

  group('refusals', () {
    testWidgets('a key needs ⌘, ⌃ or ⌥, but F5', (tester) async {
      final d = await shortcutsPage(tester);
      // The line names the key pressed: the field still shows the row's.
      for (final (key, holding, label) in [
        (LogicalKeyboardKey.keyJ, <LogicalKeyboardKey>[], 'J'),
        (LogicalKeyboardKey.keyJ, [shiftKey], '⇧J'),
        (LogicalKeyboardKey.tab, <LogicalKeyboardKey>[], '⇥'),
      ]) {
        await recordKey(tester, 'pin', key, holding);
        expect(inRow('pin', '$label: Hold ⌘, ⌃ or ⌥ with it'), findsOne);
        expect(
          inkOf(tester, 'pin', '$label: Hold ⌘, ⌃ or ⌥ with it'),
          Tokens.dark.crashed,
        );
        expect(savedKeys(), isEmpty);
      }
      await recordKey(tester, 'pin', LogicalKeyboardKey.f5);
      expect(savedKeys(), {'pin': 'F5'});
      expect(
        find.descendant(
          of: rowOf('pin'),
          matching: find.textContaining('Hold ⌘'),
        ),
        findsNothing,
      );
      d.dispose();
    }, variant: onMac);

    testWidgets("the system's, a field's and a message box's keys are "
        "refused with why; a fixed key too; a row's own default isn't", (
      tester,
    ) async {
      final d = await shortcutsInApp(tester);
      for (final (key, holding, why) in [
        (LogicalKeyboardKey.keyQ, [metaKey], '⌘Q: macOS keeps it'),
        (LogicalKeyboardKey.digit4, [shiftKey, metaKey], '⇧⌘4: macOS keeps it'),
        (LogicalKeyboardKey.keyC, [metaKey], '⌘C: A text field keeps it'),
        (LogicalKeyboardKey.keyA, [ctrlKey], '⌃A: A text field keeps it'),
        (
          LogicalKeyboardKey.enter,
          [altKey, metaKey],
          '⌥⌘⏎: The composer keeps it',
        ),
        // A fixed key's reason names it already.
        (LogicalKeyboardKey.digit1, [metaKey], '⌘1 opens a chat'),
      ]) {
        await recordKey(tester, 'pin', key, holding);
        expect(inRow('pin', why), findsOne, reason: why);
        expect(savedKeys(), isEmpty, reason: why);
        expect(keyShows(tester, 'pin'), '⌘D');
      }
      // ⌥Z types Ω elsewhere, but is Wrap lines' own.
      shortcutKeys.value = {'wrap': 'Alt+Cmd+W', 'previousChat': 'Alt+Cmd+P'};
      await tester.pumpAndSettle();
      await recordKey(tester, 'wrap', LogicalKeyboardKey.keyZ, [altKey]);
      await recordKey(tester, 'previousChat', LogicalKeyboardKey.arrowUp, [
        altKey,
        metaKey,
      ]);
      expect(savedKeys(), isEmpty);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyZ, [altKey]);
      expect(inRow('sidebar', '⌥Z: ⌥ and a key types a character'), findsOne);
      // Esc drops the refusal, and Settings stays.
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(
        inRow('sidebar', '⌥Z: ⌥ and a key types a character'),
        findsNothing,
      );
      expect(d.settingsOpen, isNotNull);
      d.dispose();
    }, variant: onMac);
  });

  group('clashes', () {
    testWidgets("another binding's key is offered to take: Cancel changes "
        'nothing, Take it leaves the other with none', (tester) async {
      final d = await shortcutsInApp(tester);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      expect(inRow('sidebar', 'Pin chat has ⌘D'), findsOne);
      expect(takeOf('sidebar'), findsOne);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-cancel');
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      expect(savedKeys(), isEmpty);
      expect(takeOf('sidebar'), findsNothing);
      // Esc cancels too, not Settings.
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(takeOf('sidebar'), findsNothing);
      expect(d.settingsOpen, isNotNull);
      expect(savedKeys(), isEmpty);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      await tapIt(tester, find.byKey(const ValueKey('shortcut-take-sidebar')));
      expect(savedKeys(), {'sidebar': 'Cmd+D', 'pin': ''});
      expect(keyShows(tester, 'sidebar'), '⌘D');
      expect(keyShows(tester, 'pin'), 'None');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-sidebar',
      );
      d.dispose();
    }, variant: onMac);

    testWidgets("⇧⌘] for another binding is Next tab's second key: taken, "
        'it goes', (tester) async {
      final d = await shortcutsPage(tester);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.bracketRight, [
        shiftKey,
        metaKey,
      ]);
      expect(inRow('sidebar', "⇧⌘] is Next tab's second key"), findsOne);
      await tapIt(tester, find.byKey(const ValueKey('shortcut-take-sidebar')));
      expect(savedKeys(), {'sidebar': 'Shift+Cmd+]'});
      expect(keyShows(tester, 'nextTab'), '⌃⇥');
      d.dispose();
    }, variant: onMac);

    testWidgets('reset on a row whose default another took offers to take '
        'it back', (tester) async {
      final d = await shortcutsPage(tester);
      shortcutKeys.value = {'pin': 'Cmd+J', 'sidebar': 'Cmd+D'};
      await tester.pumpAndSettle();
      await tapIt(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
      expect(inRow('pin', 'Show or hide sidebar has ⌘D'), findsOne);
      await tapIt(tester, find.byKey(const ValueKey('shortcut-take-pin')));
      expect(savedKeys(), {'sidebar': ''});
      expect(keyShows(tester, 'pin'), '⌘D');
      d.dispose();
    }, variant: onMac);

    testWidgets('a row with nothing saved whose default another holds has '
        'Reset, which offers to take it back', (tester) async {
      final d = await shortcutsPage(tester);
      shortcutKeys.value = {'sidebar': 'Cmd+D'};
      await tester.pumpAndSettle();
      expect(inRow('pin', "Not used: ⌘D is Show or hide sidebar's"), findsOne);
      await tapIt(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
      expect(inRow('pin', 'Show or hide sidebar has ⌘D'), findsOne);
      await tapIt(tester, find.byKey(const ValueKey('shortcut-take-pin')));
      expect(savedKeys(), {'sidebar': ''});
      expect(keyShows(tester, 'pin'), '⌘D');
      d.dispose();
    }, variant: onMac);

    testWidgets("saved keys that clash or are refused say they aren't used", (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      shortcutKeys.value = {'sidebar': 'Cmd+K', 'pin': 'Cmd+C'};
      await tester.pumpAndSettle();
      expect(keyShows(tester, 'palette'), 'None');
      expect(resetOf('palette'), findsOne);
      expect(
        inkOf(tester, 'palette', "Not used: ⌘K is Show or hide sidebar's"),
        Tokens.dark.needs,
      );
      expect(keyShows(tester, 'pin'), '⌘D');
      expect(resetOf('pin'), findsOne);
      expect(
        inkOf(tester, 'pin', "Your ⌘C isn't used: A text field keeps it"),
        Tokens.dark.needs,
      );
      d.dispose();
    }, variant: onMac);
  });
}
