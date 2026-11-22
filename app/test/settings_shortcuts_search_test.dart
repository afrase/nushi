// Settings › Keyboard shortcuts' search (ADR 0146): what a row is found
// by (its name, its group's, its keys as shown or in words), the list it
// leaves, × and Esc, a row being worked on never going from under the
// user, and the head kept in view while the list scrolls.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/shortcut_row.dart';
import 'package:nushi/shortcut_search.dart';

import 'harness.dart';
import 'shortcuts_harness.dart';

final Finder _search = find.byKey(const ValueKey('shortcuts-search'));

/// The labels of the rows shown.
List<String> _rows(WidgetTester tester) => [
  for (final r in tester.widgetList<ShortcutRow>(find.byType(ShortcutRow)))
    r.label,
];

/// The groups shown, by title.
List<String> _groups(WidgetTester tester) => [
  for (final g in tester.widgetList<SettingsGroup>(find.byType(SettingsGroup)))
    g.title!,
];

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

void main() {
  group('what matches', () {
    bool matches(String query, SingleActivator k, {String name = 'Act'}) =>
        shortcutMatches(query, name: name, group: 'View', keys: [k]);
    const cmdK = SingleActivator(LogicalKeyboardKey.keyK, meta: true);
    const shiftCmdP = SingleActivator(
      LogicalKeyboardKey.keyP,
      meta: true,
      shift: true,
    );
    const ctrlTab = SingleActivator(LogicalKeyboardKey.tab, control: true);

    testWidgets('a name or its group, case aside, every word', (tester) async {
      expect(matches('', cmdK), isTrue);
      expect(matches('SIDE', cmdK, name: 'Show or hide sidebar'), isTrue);
      expect(matches('hide side', cmdK, name: 'Show or hide sidebar'), isTrue);
      expect(matches('view', cmdK), isTrue);
      expect(matches('side tab', cmdK, name: 'Show or hide sidebar'), isFalse);
    }, variant: onMac);

    testWidgets('a key as the Mac shows it or in words', (tester) async {
      for (final q in ['⌘K', '⌘k', 'cmd k', 'Cmd+K', 'command k', '⌘ k']) {
        expect(matches(q, cmdK), isTrue, reason: q);
      }
      for (final q in ['shift cmd p', 'cmd shift p', '⇧⌘P', 'cmd sh p']) {
        expect(matches(q, shiftCmdP), isTrue, reason: q);
      }
      for (final q in ['ctrl tab', 'control tab', '⌃⇥', 'ctrl+tab']) {
        expect(matches(q, ctrlTab), isTrue, reason: q);
      }
      // Every word, and a single letter is the key itself.
      expect(matches('cmd j', cmdK), isFalse);
      expect(matches('alt k', cmdK), isFalse);
      expect(matches('cmd s', shiftCmdP), isFalse);
      expect(
        matches('esc', const SingleActivator(LogicalKeyboardKey.escape)),
        isTrue,
      );
    }, variant: onMac);

    testWidgets('a key as Linux shows it or in words', (tester) async {
      shortcutsOnLinux();
      const linuxTab = SingleActivator(LogicalKeyboardKey.tab, control: true);
      const pageUp = SingleActivator(
        LogicalKeyboardKey.pageUp,
        control: true,
        alt: true,
        shift: true,
      );
      for (final q in ['ctrl tab', 'Ctrl+Tab', 'cmd tab']) {
        expect(matches(q, linuxTab), isTrue, reason: q);
      }
      for (final q in ['ctrl alt shift page up', 'ctrl+pageup', 'pgup']) {
        expect(matches(q, pageUp), isTrue, reason: q);
      }
      expect(matches('super tab', linuxTab), isFalse);
      // A key's words are whole: Ctrl+Shift+P has no S, Ctrl+Alt+1 no A,
      // Ctrl+Tab no T.
      const linuxP = SingleActivator(
        LogicalKeyboardKey.keyP,
        control: true,
        shift: true,
      );
      const linuxAlt1 = SingleActivator(
        LogicalKeyboardKey.digit1,
        control: true,
        alt: true,
      );
      expect(matches('ctrl s', linuxP), isFalse);
      expect(matches('ctrl+a', linuxAlt1), isFalse);
      expect(matches('ctrl t', linuxTab), isFalse);
      expect(matches('ctrl shift p', linuxP), isTrue);
      expect(matches('Ctrl+Alt+1', linuxAlt1), isTrue);
    }, variant: onMac);
  });

  group('the page', () {
    testWidgets('typing narrows the list; a group left with none goes; '
        'by name, group, key, a second key and the fixed keys', (tester) async {
      final d = await shortcutsPage(tester);
      await _type(tester, 'side');
      expect(_rows(tester), ['Show or hide sidebar', 'Side chat']);
      expect(_groups(tester), ['View', 'Chat']);
      await _type(tester, 'chat');
      expect(_groups(tester), containsAll(['Chat', 'File', 'View', 'Fixed']));
      await _type(tester, 'nushi');
      expect(_rows(tester), ['Settings']);
      await _type(tester, 'cmd k');
      expect(_rows(tester), ['Command palette']);
      // Its second key.
      await _type(tester, 'shift cmd p');
      expect(_rows(tester), contains('Command palette'));
      await _type(tester, 'esc');
      expect(_rows(tester), ['Stop', 'Rewind']);
      // A key with more held matches too: ⌘3 is in ⌃⌘3.
      await _type(tester, '⌘3');
      expect(_rows(tester), [
        'Pull request tab',
        'Open chat 1–9',
        'Terminal 1–9',
      ]);
      await _type(tester, '⌃⌘3');
      expect(_rows(tester), ['Pull request tab']);
      d.dispose();
    }, variant: onMac);

    testWidgets('nothing left: Nothing matches; × empties the field', (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      final all = _rows(tester).length;
      expect(
        find.byKey(const ValueKey('shortcuts-search-clear')),
        findsNothing,
      );
      await _type(tester, 'xyzzy');
      expect(_rows(tester), isEmpty);
      expect(find.text('Nothing matches'), findsOne);
      await tapIt(tester, find.byKey(const ValueKey('shortcuts-search-clear')));
      expect(_rows(tester).length, all);
      expect(find.text('Nothing matches'), findsNothing);
      d.dispose();
    }, variant: onMac);

    testWidgets('Esc in the field with text empties it and Settings stays; '
        'in an empty field it shuts Settings', (tester) async {
      final d = await shortcutsPage(tester);
      final all = _rows(tester).length;
      await _type(tester, 'tab');
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsNothing);
      expect(_rows(tester).length, all);
      expect(tester.widget<TextField>(_search).controller!.text, isEmpty);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(find.text('closed'), findsOne);
      d.dispose();
    }, variant: onMac);

    testWidgets("a row in a clash or refused stays while what's typed no "
        'longer matches it; one just recorded stays until the search '
        'changes', (tester) async {
      final d = await shortcutsPage(tester);
      await _type(tester, 'side');
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyD, [metaKey]);
      expect(takeOf('sidebar'), findsOne);
      await _type(tester, 'xyzzy');
      expect(_rows(tester), ['Show or hide sidebar']);
      expect(takeOf('sidebar'), findsOne);
      expect(find.text('Nothing matches'), findsNothing);
      await tapIt(
        tester,
        find.byKey(const ValueKey('shortcut-cancel-sidebar')),
      );
      // Refused.
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyJ);
      expect(inRow('sidebar', 'J: Hold ⌘, ⌃ or ⌥ with it'), findsOne);
      await _type(tester, 'xyzzy2');
      expect(_rows(tester), ['Show or hide sidebar']);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.escape);
      // Found by its key, then given another: it stays till typing goes on.
      await _type(tester, r'cmd \');
      expect(_rows(tester), ['Show or hide sidebar']);
      await recordKey(tester, 'sidebar', LogicalKeyboardKey.keyY, [
        metaKey,
        LogicalKeyboardKey.altLeft,
      ]);
      expect(savedKeys(), {'sidebar': 'Alt+Cmd+Y'});
      expect(_rows(tester), ['Show or hide sidebar']);
      await _type(tester, r'cmd \ ');
      expect(_rows(tester), isEmpty);
      d.dispose();
    }, variant: onMac);

    testWidgets('Reset all while the search shows only fixed keys adds no '
        'row, and the search keeps the keyboard', (tester) async {
      final d = await shortcutsPage(tester);
      shortcutKeys.value = {'pin': 'Cmd+J'};
      await _type(tester, 'esc');
      expect(_rows(tester), ['Stop', 'Rewind']);
      await tapIt(tester, find.byKey(const ValueKey('shortcuts-reset-all')));
      await tapIt(tester, find.text('Reset all'));
      expect(savedKeys(), isEmpty);
      expect(_rows(tester), ['Stop', 'Rewind']);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'shortcuts-search',
      );
      d.dispose();
    }, variant: onMac);

    testWidgets('a field listening takes every key, the search none', (
      tester,
    ) async {
      final d = await shortcutsPage(tester);
      await tapIt(tester, keyOf('find'));
      expect(shortcutRecording.value, isTrue);
      await pressKey(tester, LogicalKeyboardKey.keyG, [metaKey, altKey]);
      expect(savedKeys(), {'find': 'Alt+Cmd+G'});
      expect(tester.widget<TextField>(_search).controller!.text, isEmpty);
      d.dispose();
    }, variant: onMac);

    testWidgets('the title, Reset all and the search stay in view as the '
        'list scrolls', (tester) async {
      final d = await shortcutsPage(tester, size: const Size(1000, 700));
      final title = tester.getRect(find.text('Keyboard shortcuts').last);
      final field = tester.getRect(_search);
      final reset = tester.getRect(
        find.byKey(const ValueKey('shortcuts-reset-all')),
      );
      final page = find
          .ancestor(
            of: find.byType(SettingsGroup).first,
            matching: find.byType(Scrollable),
          )
          .first;
      // A hairline under the head once the list is under it, not before.
      final edge = find.descendant(
        of: find.byKey(const ValueKey('settings-head-edge')),
        matching: find.byType(ColoredBox),
      );
      expect(edge, findsNothing);
      await tester.scrollUntilVisible(find.text('Quit'), 300, scrollable: page);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Keyboard shortcuts').last), title);
      expect(tester.getRect(_search), field);
      expect(
        tester.getRect(find.byKey(const ValueKey('shortcuts-reset-all'))),
        reset,
      );
      // No row drawn over the field: the list's view starts below it.
      expect(tester.getRect(page).top, greaterThan(field.bottom));
      expect(edge, findsOne);
      // A search short enough to leave the list at its top: no hairline.
      await _type(tester, 'xyzzy');
      expect(edge, findsNothing);
      d.dispose();
    }, variant: onMac);
  });
}
