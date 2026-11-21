// Settings › Keyboard shortcuts (ADR 0146): the rows by group, recording
// a key, refusals, clashes and Take it, clear and reset, Reset all, the
// menu bar quiet while a field listens, controls that never move, and
// goldens and renders of the page.
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/controls.dart' show Button;
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';

/// Settings alone at Keyboard shortcuts in a window of [size], tall
/// enough that every row is built.
Future<Daemon> _page(
  WidgetTester tester, {
  Size size = const Size(1000, 2600),
  Tokens tokens = Tokens.dark,
}) async {
  final d = await FakeDaemon([]).connect(tester);
  await pumpSettings(
    tester,
    d,
    SettingsSection.shortcuts,
    size: size,
    tokens: tokens,
  );
  return d;
}

Finder _key(String id) => find.byKey(ValueKey('shortcut-key-$id'));
Finder _row(String id) => find.byKey(ValueKey('shortcut-row-$id'));
Finder _in(String id, String text) =>
    find.descendant(of: _row(id), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// [key] pressed with [holding] held, then settled.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [],
  PhysicalKeyboardKey? physical,
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key, physicalKey: physical);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pumpAndSettle();
}

/// [id]'s field clicked and [key] pressed with [holding].
Future<void> _record(
  WidgetTester tester,
  String id,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [],
  PhysicalKeyboardKey? physical,
]) async {
  await _tap(tester, _key(id));
  await _press(tester, key, holding, physical);
}

const LogicalKeyboardKey _meta = LogicalKeyboardKey.metaLeft;
const LogicalKeyboardKey _alt = LogicalKeyboardKey.altLeft;
const LogicalKeyboardKey _shift = LogicalKeyboardKey.shiftLeft;
const LogicalKeyboardKey _ctrl = LogicalKeyboardKey.controlLeft;

/// The keys `app.json` holds, none before the first change.
Map<String, Object?> _saved() =>
    readSaved()['shortcuts'] as Map<String, Object?>? ?? {};

/// What [id]'s field shows.
String _shows(WidgetTester tester, String id) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: _key(id), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? t.textSpan!.toPlainText()).join();
}

/// [id]'s field's focus.
FocusNode _node(WidgetTester tester, String id) => tester
    .widgetList<Focus>(
      find.descendant(of: _key(id), matching: find.byType(Focus)),
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

void _onLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow();

void main() {
  setUpAll(loadFonts);

  testWidgets("the rows, by group, in the menus' order, and the fixed keys "
      'last', (tester) async {
    final d = await _page(tester);
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
    expect(_in('sidebar', r'⌘\'), findsOne);
    expect(find.text('⌘1–⌘9'), findsOne);
    expect(find.text('⌥⌘1–⌥⌘9'), findsOne);
    expect(find.text('⌘Q'), findsOne);
    d.dispose();
  }, variant: onMac);

  testWidgets("the second keys are listed, and read Off once their action's "
      'key is changed', (tester) async {
    final d = await _page(tester);
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
    _onLinux();
    final d = await _page(tester);
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
      final d = await _page(tester);
      await _tap(tester, _key('sidebar'));
      expect(_shows(tester, 'sidebar'), 'Press keys…');
      expect(shortcutRecording.value, isTrue);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-sidebar',
      );
      // A modifier alone waits.
      await tester.sendKeyDownEvent(_meta);
      await tester.sendKeyDownEvent(_alt);
      await tester.pumpAndSettle();
      expect(_shows(tester, 'sidebar'), 'Press keys…');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(_alt);
      await tester.sendKeyUpEvent(_meta);
      await tester.pumpAndSettle();
      expect(_saved(), {'sidebar': 'Alt+Cmd+S'});
      expect(_shows(tester, 'sidebar'), '⌥⌘S');
      expect(shortcutRecording.value, isFalse);
      expect(_in('sidebar', 'Edited'), findsOne);
      d.dispose();
    }, variant: onMac);

    testWidgets('⇧⌘} as a keyboard reports it is saved as ⇧⌘], and is '
        "Next tab's own second key, so no clash", (tester) async {
      final d = await _page(tester);
      await _record(tester, 'nextTab', LogicalKeyboardKey.braceRight, [
        _shift,
        _meta,
      ], PhysicalKeyboardKey.bracketRight);
      expect(_saved(), {'nextTab': 'Shift+Cmd+]'});
      expect(_shows(tester, 'nextTab'), '⇧⌘]');
      d.dispose();
    }, variant: onMac);

    testWidgets("a French keyboard's shifted symbols are saved as they come, "
        'not as the US keys that make them', (tester) async {
      final d = await _page(tester);
      // ⇧⌘ on ù reports %, which is not ⇧⌘5 there; on its , key, ?.
      await _record(tester, 'pin', LogicalKeyboardKey.percent, [
        _shift,
        _meta,
      ], PhysicalKeyboardKey.quote);
      await _record(tester, 'sidebar', LogicalKeyboardKey.question, [
        _shift,
        _meta,
      ], PhysicalKeyboardKey.keyM);
      expect(_saved(), {'pin': 'Shift+Cmd+%', 'sidebar': 'Shift+Cmd+?'});
      expect(_shows(tester, 'pin'), '⇧⌘%');
      d.dispose();
    }, variant: onMac);

    testWidgets('Esc while listening stops it, not Settings; a second Esc '
        'closes Settings', (tester) async {
      final d = await _page(tester);
      final before = shortcutKeys.value;
      await _tap(tester, _key('find'));
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsNothing);
      expect(shortcutKeys.value, same(before));
      expect(_shows(tester, 'find'), '⌘F');
      expect(shortcutRecording.value, isFalse);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsOne);
      d.dispose();
    }, variant: onMac);

    testWidgets("started with Enter, Enter's repeat and lifting don't end "
        'it', (tester) async {
      final d = await _page(tester);
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
      expect(_shows(tester, 'settings'), 'Press keys…');
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_shows(tester, 'settings'), 'Press keys…');
      expect(_saved(), isEmpty);
      await _press(tester, LogicalKeyboardKey.escape);
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
      await _tap(tester, _key('reloadPage'));
      expect(reload().shortcut, isNull);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(reload().shortcut, isNotNull);
      expect(d.settingsOpen, isNotNull);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(d.settingsOpen, isNull);
      // Again, and Settings shut by a click on the dim.
      d.openSettings(section: SettingsSection.shortcuts);
      await tester.pumpAndSettle();
      await _tap(tester, _key('reloadPage'));
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
        (LogicalKeyboardKey.keyD, [_meta]),
        (LogicalKeyboardKey.keyS, [_alt, _meta]),
      ]) {
        await _tap(tester, _key('sidebar'));
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
          await _tap(tester, find.text('Cancel'));
        }
      }
      expect(d.settingsOpen, isNotNull);
      expect(_saved(), {'sidebar': 'Alt+Cmd+S'});
      d.dispose();
    }, variant: onMac);

    testWidgets('on Linux AltGr alone is held, not taken', (tester) async {
      _onLinux();
      final d = await _page(tester);
      await _tap(tester, _key('sidebar'));
      await tester.sendKeyDownEvent(_ctrl);
      // GTK's ISO_Level3_Shift, the right Alt key.
      const altRight = PhysicalKeyboardKey.altRight;
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altGraph,
        physicalKey: altRight,
      );
      await tester.pumpAndSettle();
      expect(shortcutRecording.value, isTrue);
      expect(_shows(tester, 'sidebar'), 'Press keys…');
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.altGraph,
        physicalKey: altRight,
      );
      await tester.sendKeyUpEvent(_ctrl);
      await tester.pumpAndSettle();
      expect(shortcutRecording.value, isFalse);
      expect(_saved(), {'sidebar': 'Cmd+F6'});
      d.dispose();
    }, variant: onMac);

    testWidgets("on Linux a refused Ctrl+Q's repeats don't quit; lifted, it "
        'quits again', (tester) async {
      _onLinux();
      final d = await pumpSettingsApp(
        tester,
        settingsFake(),
        SettingsSection.shortcuts,
      );
      final exits = _ExitAsks();
      tester.binding.addObserver(exits);
      addTearDown(() => tester.binding.removeObserver(exits));
      await _tap(tester, _key('sidebar'));
      await tester.sendKeyDownEvent(_ctrl);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _row('sidebar'),
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
      await tester.sendKeyUpEvent(_ctrl);
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
        ('settings', LogicalKeyboardKey.period, [_alt, _meta]),
        ('sidebar', LogicalKeyboardKey.period, [_alt, _meta]),
      ]) {
        await _tap(tester, _key(id));
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
      expect(_saved(), {'settings': 'Alt+Cmd+.'});
      expect(_in('sidebar', 'In use'), findsOne);
      await _tap(tester, find.byKey(const ValueKey('shortcut-cancel-sidebar')));
      await _press(tester, LogicalKeyboardKey.period, [_alt, _meta]);
      expect(d.settingsOpen, isNull);
      d.dispose();
    }, variant: onMac);
  });

  group('refusals', () {
    testWidgets('a key needs ⌘, ⌃ or ⌥, but F5', (tester) async {
      final d = await _page(tester);
      // The line names the key pressed: the field still shows the row's.
      for (final (key, holding, label) in [
        (LogicalKeyboardKey.keyJ, <LogicalKeyboardKey>[], 'J'),
        (LogicalKeyboardKey.keyJ, [_shift], '⇧J'),
        (LogicalKeyboardKey.tab, <LogicalKeyboardKey>[], '⇥'),
      ]) {
        await _record(tester, 'pin', key, holding);
        expect(_in('pin', '$label: Hold ⌘, ⌃ or ⌥ with it'), findsOne);
        expect(_in('pin', 'Not allowed'), findsOne);
        expect(_saved(), isEmpty);
      }
      await _record(tester, 'pin', LogicalKeyboardKey.f5);
      expect(_saved(), {'pin': 'F5'});
      expect(_in('pin', 'Not allowed'), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets("the system's, a field's and a message box's keys are "
        "refused with why; a fixed key too; a row's own default isn't", (
      tester,
    ) async {
      final d = await _page(tester);
      for (final (key, holding, why) in [
        (LogicalKeyboardKey.keyQ, [_meta], '⌘Q: macOS keeps it'),
        (LogicalKeyboardKey.digit4, [_shift, _meta], '⇧⌘4: macOS keeps it'),
        (LogicalKeyboardKey.keyC, [_meta], '⌘C: A text field keeps it'),
        (LogicalKeyboardKey.keyA, [_ctrl], '⌃A: A text field keeps it'),
        (
          LogicalKeyboardKey.enter,
          [_alt, _meta],
          '⌥⌘⏎: A message box keeps it',
        ),
        // A fixed key's reason names it already.
        (LogicalKeyboardKey.digit1, [_meta], '⌘1 opens a chat'),
      ]) {
        await _record(tester, 'pin', key, holding);
        expect(_in('pin', why), findsOne, reason: why);
        expect(_saved(), isEmpty, reason: why);
        expect(_shows(tester, 'pin'), '⌘D');
      }
      // ⌥Z types Ω elsewhere, but is Wrap lines' own.
      shortcutKeys.value = {'wrap': 'Alt+Cmd+W', 'previousChat': 'Alt+Cmd+P'};
      await tester.pumpAndSettle();
      await _record(tester, 'wrap', LogicalKeyboardKey.keyZ, [_alt]);
      await _record(tester, 'previousChat', LogicalKeyboardKey.arrowUp, [
        _alt,
        _meta,
      ]);
      expect(_saved(), isEmpty);
      await _record(tester, 'sidebar', LogicalKeyboardKey.keyZ, [_alt]);
      expect(_in('sidebar', '⌥Z: ⌥ and a key types a character'), findsOne);
      // Esc drops the refusal, and Settings stays.
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_in('sidebar', 'Not allowed'), findsNothing);
      expect(find.text('closed'), findsNothing);
      d.dispose();
    }, variant: onMac);
  });

  group('clashes', () {
    testWidgets("another binding's key is offered to take: Cancel changes "
        'nothing, Take it leaves the other with none', (tester) async {
      final d = await _page(tester);
      await _record(tester, 'sidebar', LogicalKeyboardKey.keyD, [_meta]);
      expect(_in('sidebar', 'Pin chat has ⌘D'), findsOne);
      expect(_in('sidebar', 'In use'), findsOne);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'shortcut-cancel');
      await _tap(tester, find.byKey(const ValueKey('shortcut-cancel-sidebar')));
      expect(_saved(), isEmpty);
      expect(_in('sidebar', 'In use'), findsNothing);
      // Esc cancels too, not Settings.
      await _record(tester, 'sidebar', LogicalKeyboardKey.keyD, [_meta]);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_in('sidebar', 'In use'), findsNothing);
      expect(find.text('closed'), findsNothing);
      expect(_saved(), isEmpty);
      await _record(tester, 'sidebar', LogicalKeyboardKey.keyD, [_meta]);
      await _tap(tester, find.byKey(const ValueKey('shortcut-take-sidebar')));
      expect(_saved(), {'sidebar': 'Cmd+D', 'pin': ''});
      expect(_shows(tester, 'sidebar'), '⌘D');
      expect(_shows(tester, 'pin'), 'None');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcut-sidebar',
      );
      d.dispose();
    }, variant: onMac);

    testWidgets("⇧⌘] for another binding is Next tab's second key: taken, "
        'it goes', (tester) async {
      final d = await _page(tester);
      await _record(tester, 'sidebar', LogicalKeyboardKey.bracketRight, [
        _shift,
        _meta,
      ]);
      expect(_in('sidebar', "⇧⌘] is Next tab's second key"), findsOne);
      await _tap(tester, find.byKey(const ValueKey('shortcut-take-sidebar')));
      expect(_saved(), {'sidebar': 'Shift+Cmd+]'});
      expect(_shows(tester, 'nextTab'), '⌃⇥');
      d.dispose();
    }, variant: onMac);

    testWidgets('reset on a row whose default another took offers to take '
        'it back', (tester) async {
      final d = await _page(tester);
      shortcutKeys.value = {'pin': 'Cmd+J', 'sidebar': 'Cmd+D'};
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
      expect(_in('pin', 'Show or hide sidebar has ⌘D'), findsOne);
      await _tap(tester, find.byKey(const ValueKey('shortcut-take-pin')));
      expect(_saved(), {'sidebar': ''});
      expect(_shows(tester, 'pin'), '⌘D');
      d.dispose();
    }, variant: onMac);

    testWidgets("saved keys that clash or are refused say they aren't used", (
      tester,
    ) async {
      final d = await _page(tester);
      shortcutKeys.value = {'sidebar': 'Cmd+K', 'pin': 'Cmd+C'};
      await tester.pumpAndSettle();
      expect(_shows(tester, 'palette'), 'None');
      expect(_in('palette', 'Not used'), findsOne);
      expect(_in('palette', "⌘K is Show or hide sidebar's"), findsOne);
      expect(_shows(tester, 'pin'), '⌘D');
      expect(_in('pin', 'Not used'), findsOne);
      expect(_in('pin', "Your ⌘C isn't used: A text field keeps it"), findsOne);
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
      await _tap(
        tester,
        find.byKey(const ValueKey('shortcut-clear-reloadPage')),
      );
      expect(_shows(tester, 'reloadPage'), 'None');
      expect(_saved(), {'reloadPage': ''});
      expect(reload().shortcut, isNull);
      await _tap(
        tester,
        find.byKey(const ValueKey('shortcut-reset-reloadPage')),
      );
      expect(_shows(tester, 'reloadPage'), '⌘R');
      expect(_saved(), isEmpty);
      expect(reload().shortcut, isNotNull);
      d.dispose();
    }, variant: onMac);

    testWidgets("from the keyboard, Clear leaves the focus on its row's "
        'field', (tester) async {
      final d = await _page(tester);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await _tap(tester, _key('sidebar'));
      await _press(tester, LogicalKeyboardKey.escape);
      // Back a step from the field: its row's Clear.
      await _press(tester, LogicalKeyboardKey.tab, [_shift]);
      await _press(tester, LogicalKeyboardKey.space);
      expect(_saved(), {'sidebar': ''});
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
      final d = await _page(tester);
      Button button() => tester.widget<Button>(
        find.byKey(const ValueKey('shortcuts-reset-all')),
      );
      shortcutKeys.value = {'later': 'Cmd+J'};
      await tester.pumpAndSettle();
      expect(button().onPressed, isNull);
      shortcutKeys.value = {'later': 'Cmd+J', 'pin': 'Cmd+J'};
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('shortcuts-reset-all')));
      expect(find.text('Reset all keys?'), findsOne);
      await _tap(tester, find.text('Cancel'));
      expect(_saved(), {'later': 'Cmd+J', 'pin': 'Cmd+J'});
      await _tap(tester, find.byKey(const ValueKey('shortcuts-reset-all')));
      await _tap(tester, find.text('Reset all'));
      expect(_saved(), {'later': 'Cmd+J'});
      expect(button().onPressed, isNull);
      d.dispose();
    }, variant: onMac);
  });

  group('layout', () {
    for (final width in [1000.0, 720.0]) {
      testWidgets('Clear, Reset and Take it move neither the field nor the '
          'controls left, ${width.toInt()} wide', (tester) async {
        final d = await _page(tester, size: Size(width, 2600));
        Rect at(Finder f) => tester.getRect(f);
        await tester.ensureVisible(_row('pin'));
        await tester.pumpAndSettle();
        final field = at(_key('pin'));
        final clear = at(find.byKey(const ValueKey('shortcut-clear-pin')));
        final row = at(_row('pin'));
        await _tap(tester, find.byKey(const ValueKey('shortcut-clear-pin')));
        expect(at(_key('pin')), field);
        expect(at(_row('pin')), row);
        final reset = at(find.byKey(const ValueKey('shortcut-reset-pin')));
        await _tap(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
        expect(at(_key('pin')), field);
        expect(at(find.byKey(const ValueKey('shortcut-clear-pin'))), clear);
        expect(at(_row('pin')), row);
        // A clash: its buttons come and go beside a field that stays.
        await _record(tester, 'pin', LogicalKeyboardKey.backslash, [_meta]);
        expect(at(_key('pin')), field);
        expect(at(_row('pin')), row);
        await _tap(tester, find.byKey(const ValueKey('shortcut-take-pin')));
        expect(at(_key('pin')), field);
        expect(at(find.byKey(const ValueKey('shortcut-reset-pin'))), reset);
        expect(at(_row('pin')), row);
        expectControlsAtEdge(tester);
        expect(tester.takeException(), isNull);
        d.dispose();
      }, variant: onMac);
    }

    testWidgets('on Linux a chosen Ctrl+Alt+R notes the shell keeps it; reset, '
        'the note goes and nothing moves', (tester) async {
      _onLinux();
      final d = await _page(tester);
      final field = tester.getRect(_key('pin'));
      final row = tester.getRect(_row('pin'));
      // Ctrl+R is Reload page's there.
      await _record(tester, 'pin', LogicalKeyboardKey.keyR, [_ctrl, _alt]);
      expect(_saved(), {'pin': 'Alt+Cmd+R'});
      expect(_in('pin', 'A focused terminal keeps it for the shell'), findsOne);
      await _tap(tester, find.byKey(const ValueKey('shortcut-reset-pin')));
      expect(
        _in('pin', 'A focused terminal keeps it for the shell'),
        findsNothing,
      );
      expect(tester.getRect(_key('pin')), field);
      expect(tester.getRect(_row('pin')), row);
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
        final d = await _page(tester, tokens: tokens);
        if (state == 'pending') {
          shortcutKeys.value = {'newChat': 'Shift+Cmd+N'};
          await tester.pumpAndSettle();
          await _record(tester, 'closeTab', LogicalKeyboardKey.keyS, [_meta]);
        } else {
          await _record(tester, 'closeTab', LogicalKeyboardKey.keyC, [_meta]);
        }
        // The pointer and the focus away, as a golden is looked at.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await expectLater(
          find.ancestor(
            of: _row('closeTab'),
            matching: find.byType(SettingsGroup),
          ),
          matchesGoldenFile('goldens/settings_shortcuts_${state}_$name.png'),
        );
        d.dispose();
      }, variant: onMac);
    }
  }

  // The page at full size, in the app.
  for (final (size, w) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 900), 'narrow'),
  ]) {
    for (final b in Brightness.values) {
      testWidgets('renders, $w, ${b.name}', (tester) async {
        final d = await pumpSettingsApp(
          tester,
          settingsFake(),
          SettingsSection.shortcuts,
          size: size,
          brightness: b,
        );
        expect(tester.takeException(), isNull);
        expectTextInside(tester, size.width);
        expectControlsAtEdge(tester);
        await render(
          tester,
          find.byType(NushiApp),
          'settings_shortcuts_${w}_${b.name}',
        );
        shortcutKeys.value = {'newChat': 'Shift+Cmd+N', 'pin': 'Cmd+C'};
        await tester.pumpAndSettle();
        await _record(tester, 'closeTab', LogicalKeyboardKey.keyS, [_meta]);
        expect(tester.takeException(), isNull);
        await render(
          tester,
          find.byType(NushiApp),
          'settings_shortcuts_${w}_${b.name}_clash',
        );
        final page = tester.widget<CustomScrollView>(
          find.ancestor(
            of: _row('closeTab'),
            matching: find.byType(CustomScrollView),
          ),
        );
        await tester.dragUntilVisible(
          find.text('Quit'),
          find.byWidget(page),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'settings_shortcuts_${w}_${b.name}_end',
        );
        d.dispose();
      }, variant: onMac);
    }
  }
}
