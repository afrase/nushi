// Settings › Keyboard shortcuts (ADR 0146): the rows by group, recording
// a key, refusals, clashes and Take it, clear and reset, Reset all, the
// menu bar quiet while a field listens, controls that never move, and
// goldens (its renders: settings_shortcuts_renders_test.dart).
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart' show Button;
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'shortcuts_harness.dart';

/// [id]'s field's focus.
FocusNode _node(WidgetTester tester, String id) => tester
    .widgetList<Focus>(
      find.descendant(of: keyOf(id), matching: find.byType(Focus)),
    )
    .map((f) => f.focusNode)
    .firstWhere((n) => n?.debugLabel == 'shortcut-$id')!;

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

  testWidgets("the rows, by group, in the menus' order, and the fixed keys "
      'last', (tester) async {
    final d = await shortcutsPage(tester);
    final groups = {
      for (final g in tester.widgetList<SettingsGroup>(
        find.byType(SettingsGroup),
      ))
        g.title!: [
          for (final r in g.children)
            switch (r) {
              final SettingsRow r => r.label,
              final w =>
                tester
                    .widget<SettingsRow>(
                      find.descendant(
                        of: find.byWidget(w),
                        matching: find.byType(SettingsRow),
                      ),
                    )
                    .label,
            },
        ],
    };
    expect(groups, {
      'Nushi': ['Settings'],
      'File': ['New chat', 'Open file', 'Close tab', 'Save', 'Open location'],
      'View': [
        'Command palette',
        'Reload page',
        'Find',
        'Chat tab',
        'Changes tab',
        'Pull request tab',
        'Previous tab',
        'Next tab',
        'Show or hide sidebar',
        'Files pane',
        'File tree',
        'Wrap lines',
        'Jira',
        'GitHub',
        'Back',
        'Forward',
        'Previous chat',
        'Next chat',
      ],
      'Chat': ['Side chat', 'Pin chat', 'Next typo'],
      'Other': ['Terminal'],
      'Second keys': ['Previous tab', 'Next tab', 'Command palette'],
      'Fixed': ['Stop', 'Rewind', 'Open chat 1–9', 'Terminal 1–9', 'Quit'],
    });
    expect(inRow('sidebar', r'⌘\'), findsOne);
    expect(find.text('⌘1–⌘9'), findsOne);
    expect(find.text('⌥⌘1–⌥⌘9'), findsOne);
    expect(find.text('⌘Q'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets("the second keys are listed, and read Off once their action's "
      'key is changed', (tester) async {
    final d = await shortcutsPage(tester);
    Finder second(String label, String text) => find.descendant(
      of: find.byKey(ValueKey('shortcut-second-$label')),
      matching: find.text(text),
    );
    expect(second('Next tab', '⇧⌘]'), findsOne);
    expect(second('Previous tab', '⇧⌘['), findsOne);
    expect(second('Command palette', '⇧⌘P'), findsOne);
    shortcutKeys.value = {'nextTab': 'Alt+Cmd+N'};
    await tester.pumpAndSettle();
    expect(second('Next tab', 'Off'), findsOne);
    expect(second('Previous tab', '⇧⌘['), findsOne);
    // ⇧⌘} held by another binding is ⇧⌘], so that second key goes too.
    shortcutKeys.value = {'sidebar': 'Shift+Cmd+}'};
    await tester.pumpAndSettle();
    expect(second('Next tab', 'Off'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets('the second keys in Linux words', (tester) async {
    shortcutsOnLinux();
    final d = await shortcutsPage(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shortcut-second-Command palette')),
        matching: find.text('Ctrl+Shift+P'),
      ),
      findsOne,
    );
    d.dispose();
  });

  test('every action with a key has a name on the page, but Quit', () {
    for (final a in Act.values) {
      if ((a.key ?? a.shows) == null || a.keyText != null) continue;
      expect(
        shortcutName(a),
        a == Act.quit ? isNull : isNotNull,
        reason: a.name,
      );
    }
  });

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
      expect(inRow('sidebar', 'Edited'), findsOne);
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
      _node(tester, 'settings').requestFocus();
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
      expect(inRow('sidebar', 'In use'), findsOne);
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      await pressKey(tester, LogicalKeyboardKey.period, [altKey, metaKey]);
      expect(d.settingsOpen, isNull);
      d.dispose();
    }, variant: onMac);
  });

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
        expect(inRow('pin', 'Not allowed'), findsOne);
        expect(savedKeys(), isEmpty);
      }
      await recordKey(tester, 'pin', LogicalKeyboardKey.f5);
      expect(savedKeys(), {'pin': 'F5'});
      expect(inRow('pin', 'Not allowed'), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets("the system's, a field's and a message box's keys are "
        "refused with why; a fixed key too; a row's own default isn't", (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
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
      expect(inRow('sidebar', 'Not allowed'), findsNothing);
      expect(find.text('closed'), findsNothing);
      d.dispose();
    }, variant: onMac);
  });

  group('clashes', () {
    testWidgets("another binding's key is offered to take: Cancel changes "
        'nothing, Take it leaves the other with none', (tester) async {
      final d = await shortcutsPage(tester);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      expect(inRow('sidebar', 'Pin chat has ⌘D'), findsOne);
      expect(inRow('sidebar', 'In use'), findsOne);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-cancel');
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      expect(savedKeys(), isEmpty);
      expect(inRow('sidebar', 'In use'), findsNothing);
      // Esc cancels too, not Settings.
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(inRow('sidebar', 'In use'), findsNothing);
      expect(find.text('closed'), findsNothing);
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
      expect(inRow('pin', "⌘D is Show or hide sidebar's"), findsOne);
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
      expect(inRow('palette', 'Not used'), findsOne);
      expect(inRow('palette', "⌘K is Show or hide sidebar's"), findsOne);
      expect(keyShows(tester, 'pin'), '⌘D');
      expect(inRow('pin', 'Not used'), findsOne);
      expect(
        inRow('pin', "Your ⌘C isn't used: A text field keeps it"),
        findsOne,
      );
      d.dispose();
    }, variant: onMac);
  });

  group('clear and reset', () {
    testWidgets('Clear leaves none, and the menu item loses its key; Reset '
        'brings the default back', (tester) async {
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      PlatformMenuItem reload() =>
          viewItems(tester).firstWhere((m) => m.label == 'Reload Page');
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-clear-reloadPage')),
      );
      expect(keyShows(tester, 'reloadPage'), 'None');
      expect(savedKeys(), {'reloadPage': ''});
      expect(reload().shortcut, isNull);
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-reset-reloadPage')),
      );
      expect(keyShows(tester, 'reloadPage'), '⌘R');
      expect(savedKeys(), isEmpty);
      expect(reload().shortcut, isNotNull);
      d.dispose();
    }, variant: onMac);

    testWidgets("from the keyboard, Clear leaves the focus on its row's "
        'field', (tester) async {
      final d = await shortcutsPage(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tapIt(tester, keyOf('sidebar'));
      await pressKey(tester, LogicalKeyboardKey.escape);
      // Back a step from the field: its row's Clear.
      await pressKey(tester, LogicalKeyboardKey.tab, [shiftKey]);
      await pressKey(tester, LogicalKeyboardKey.space);
      expect(savedKeys(), {'sidebar': ''});
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-sidebar',
      );
      d.dispose();
    }, variant: onMac);
  });

  group('reset all', () {
    testWidgets('asks first; Reset all keeps a name this app does not know; '
        'off with only those', (tester) async {
      final d = await shortcutsPage(tester);
      Button button() => tester.widget<Button>(
        find.byKey(const ValueKey('shortcuts-reset-all')),
      );
      shortcutKeys.value = {'later': 'Cmd+J'};
      await tester.pumpAndSettle();
      expect(button().onPressed, isNull);
      shortcutKeys.value = {'later': 'Cmd+J', 'pin': 'Cmd+J'};
      await tester.pumpAndSettle();
      await tapIt(tester, find.byKey(const ValueKey('shortcuts-reset-all')));
      expect(find.text('Reset all keys?'), findsOne);
      await tapIt(tester, find.text('Cancel'));
      expect(savedKeys(), {'later': 'Cmd+J', 'pin': 'Cmd+J'});
      await tapIt(tester, find.byKey(const ValueKey('shortcuts-reset-all')));
      await tapIt(tester, find.text('Reset all'));
      expect(savedKeys(), {'later': 'Cmd+J'});
      expect(button().onPressed, isNull);
      d.dispose();
    }, variant: onMac);

    testWidgets('from the keyboard, Reset all leaves the focus on the first '
        "row's field, with its ring", (tester) async {
      final d = await shortcutsPage(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      shortcutKeys.value = {'pin': 'Cmd+J'};
      await tester.pumpAndSettle();
      final first = rebindable.first.id!;
      Focus.of(tester.element(find.text('Reset all to defaults')))
          .requestFocus();
      await tester.pumpAndSettle();
      await pressKey(tester, LogicalKeyboardKey.enter);
      expect(find.text('Reset all keys?'), findsOne);
      // Cancel has the focus first; Reset all is after it.
      await pressKey(tester, LogicalKeyboardKey.tab);
      await pressKey(tester, LogicalKeyboardKey.enter);
      expect(savedKeys(), isEmpty);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-$first');
      final ring = tester
          .widgetList<Container>(
            find.descendant(of: keyOf(first), matching: find.byType(Container)),
          )
          .map((c) => c.foregroundDecoration)
          .whereType<BoxDecoration>()
          .single;
      expect((ring.border! as Border).top.width, 2);
      d.dispose();
    }, variant: onMac);
  });

  group('layout', () {
    for (final width in [1000.0, 720.0]) {
      testWidgets('Clear, Reset and Take it move neither the field nor the '
          'controls left, ${width.toInt()} wide', (tester) async {
        final d = await shortcutsPage(tester, size: Size(width, 2600));
        Rect at(Finder f) => tester.getRect(f);
        await tester.ensureVisible(rowOf('pin'));
        await tester.pumpAndSettle();
        final field = at(keyOf('pin'));
        final clear = at(find.byKey(const ValueKey('shortcut-clear-pin')));
        final row = at(rowOf('pin'));
        await tapIt(tester, find.byKey(const ValueKey('shortcut-clear-pin')));
        expect(at(keyOf('pin')), field);
        expect(at(rowOf('pin')), row);
        final reset = at(find.byKey(const ValueKey('shortcut-reset-pin')));
        await tapIt(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
        expect(at(keyOf('pin')), field);
        expect(at(find.byKey(const ValueKey('shortcut-clear-pin'))), clear);
        expect(at(rowOf('pin')), row);
        // A clash: its buttons come and go beside a field that stays.
        await recordKey(tester, 'pin', LogicalKeyboardKey.backslash, [metaKey]);
        expect(at(keyOf('pin')), field);
        expect(at(rowOf('pin')), row);
        await tapIt(tester, find.byKey(const ValueKey('shortcut-take-pin')));
        expect(at(keyOf('pin')), field);
        expect(at(find.byKey(const ValueKey('shortcut-reset-pin'))), reset);
        expect(at(rowOf('pin')), row);
        expectControlsAtEdge(tester);
        expect(tester.takeException(), isNull);
        d.dispose();
      }, variant: onMac);
    }

    testWidgets('a field listening goes on listening, its ring and all, as '
        'the window narrows past where the rows stack and back', (
      tester,
    ) async {
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
      final ring = tester
          .widgetList<Container>(
            find.descendant(of: keyOf('pin'), matching: find.byType(Container)),
          )
          .map((c) => c.foregroundDecoration)
          .whereType<BoxDecoration>()
          .single;
      expect((ring.border! as Border).top.width, 2);
      d.dispose();
    }, variant: onMac);

    testWidgets('narrow on Linux, a long key is shown at a readable size, in '
        "a field as wide as every row's; a clash fits beside it", (
      tester,
    ) async {
      shortcutsOnLinux();
      shortcutKeys.value = {'newChat': 'Alt+Shift+Cmd+PageDown'};
      // In the app, where Settings leaves the page least room.
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
        size: const Size(720, 900),
      );
      final other = tester.getRect(keyOf('settings'));
      final field = tester.getRect(keyOf('newChat'));
      expect(field.width, 168);
      expect(other.left, field.left);
      expect(other.width, field.width);
      final fit = tester.renderObject<RenderBox>(
        find.descendant(of: keyOf('newChat'), matching: find.byType(FittedBox)),
      );
      final words = tester.renderObject<RenderBox>(
        find.descendant(
          of: keyOf('newChat'),
          matching: find.text('Ctrl+Alt+Shift+Page Down', findRichText: true),
        ),
      );
      // At least 10 of its 12 points.
      expect(fit.size.width / words.size.width, greaterThanOrEqualTo(10 / 12));
      await recordKey(tester, 'newChat', LogicalKeyboardKey.keyS, [ctrlKey]);
      expect(find.byKey(const ValueKey('shortcut-take-newChat')), findsOne);
      expect(tester.getRect(keyOf('newChat')).left, field.left);
      expect(tester.getRect(keyOf('newChat')).width, field.width);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('shortcut-take-newChat')))
            .right,
        lessThanOrEqualTo(tester.getRect(rowOf('newChat')).right),
      );
      expect(tester.takeException(), isNull);
      d.dispose();
    }, variant: onMac);

    testWidgets('on Linux a chosen Ctrl+Alt+R notes the shell keeps it; reset, '
        'the note goes and nothing moves', (tester) async {
      shortcutsOnLinux();
      final d = await shortcutsPage(tester);
      final field = tester.getRect(keyOf('pin'));
      final row = tester.getRect(rowOf('pin'));
      // Ctrl+R is Reload page's there.
      await recordKey(tester, 'pin', LogicalKeyboardKey.keyR, [
        ctrlKey,
        altKey,
      ]);
      expect(savedKeys(), {'pin': 'Alt+Cmd+R'});
      expect(
        inRow('pin', 'A focused terminal keeps it for the shell'),
        findsOne,
      );
      await tapIt(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
      expect(
        inRow('pin', 'A focused terminal keeps it for the shell'),
        findsNothing,
      );
      expect(tester.getRect(keyOf('pin')), field);
      expect(tester.getRect(rowOf('pin')), row);
      d.dispose();
    }, variant: onMac);
  });

  // A group with an edited row and a clash, and one with a refusal.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final state in ['pending', 'refused']) {
      testWidgets('golden, $state, $name', (tester) async {
        final d = await shortcutsPage(tester, tokens: tokens);
        if (state == 'pending') {
          shortcutKeys.value = {'newChat': 'Shift+Cmd+N'};
          await tester.pumpAndSettle();
          await recordKey(tester, 'closeTab', LogicalKeyboardKey.keyS, [
            metaKey,
          ]);
        } else {
          await recordKey(tester, 'closeTab', LogicalKeyboardKey.keyC, [
            metaKey,
          ]);
        }
        // The pointer and the focus away, as a golden is looked at.
        FocusManager.instance.primaryFocus?.unfocus();
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
