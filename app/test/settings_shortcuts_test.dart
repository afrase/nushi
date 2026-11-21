// Settings › Keyboard shortcuts (ADR 0146): the rows by group, recording
// a key, refusals, clashes and Take it, clear and reset, Reset all, the
// menu bar quiet while a field listens (the rows' layout and goldens:
// settings_shortcuts_rows_test.dart; renders:
// settings_shortcuts_renders_test.dart).
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
import 'package:nushi/shortcut_row.dart';
import 'package:nushi/theme/theme.dart';

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

  testWidgets("the rows, by group, in the menus' order, and the fixed keys "
      'last', (tester) async {
    final d = await shortcutsPage(tester);
    final groups = {
      for (final g in tester.widgetList<SettingsGroup>(
        find.byType(SettingsGroup),
      ))
        g.title!: [
          for (final r in tester.widgetList<ShortcutRow>(
            find.descendant(
              of: find.byWidget(g),
              matching: find.byType(ShortcutRow),
            ),
          ))
            r.label,
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
      'Fixed': ['Stop', 'Rewind', 'Open chat 1–9', 'Terminal 1–9', 'Quit'],
    });
    expect(inRow('sidebar', r'⌘\'), findsOne);
    expect(find.text('⌘1–⌘9'), findsOne);
    expect(find.text('⌥⌘1–⌥⌘9'), findsOne);
    expect(find.text('⌘Q'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets("the second keys show in their action's row, left of its "
      "key, and go once the action's key is changed", (tester) async {
    final d = await shortcutsPage(tester);
    Finder second(String id) => find.byKey(ValueKey('shortcut-second-$id'));
    Finder shows(String id, String text) => find.descendant(
      of: find.descendant(of: rowOf(id), matching: second(id)),
      matching: find.text(text),
    );
    expect(shows('nextTab', '⇧⌘]'), findsOne);
    expect(shows('previousTab', '⇧⌘['), findsOne);
    expect(shows('palette', '⇧⌘P'), findsOne);
    expect(
      tester.getRect(second('nextTab')).right,
      lessThan(tester.getRect(keyOf('nextTab')).left),
    );
    // It isn't a control of its own: no focus, no hand.
    expect(
      find.descendant(of: second('nextTab'), matching: find.byType(Focus)),
      findsNothing,
    );
    shortcutKeys.value = {'nextTab': 'Alt+Cmd+N'};
    await tester.pumpAndSettle();
    expect(second('nextTab'), findsNothing);
    expect(shows('previousTab', '⇧⌘['), findsOne);
    // ⇧⌘} held by another binding is ⇧⌘], so that second key goes too.
    shortcutKeys.value = {'sidebar': 'Shift+Cmd+}'};
    await tester.pumpAndSettle();
    expect(second('nextTab'), findsNothing);
    d.dispose();
  }, variant: onMac);

  testWidgets('the second keys in Linux words', (tester) async {
    shortcutsOnLinux();
    final d = await shortcutsPage(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shortcut-second-palette')),
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
      expect(
        inRow('sidebar', '⌥Z: ⌥ and a key types a character'),
        findsNothing,
      );
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
      expect(resetOf('palette'), findsOne);
      expect(
        inkOf(tester, 'palette', "⌘K is Show or hide sidebar's"),
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
      await clickShown(tester, clearOf('reloadPage'));
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
      expect(ringOf(tester, first), 2);
      d.dispose();
    }, variant: onMac);
  });
}
