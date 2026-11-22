// Settings › Keyboard shortcuts (ADR 0146): the rows by group, the second
// keys and their names (recording: settings_shortcuts_record_test.dart;
// refusals and clashes: settings_shortcuts_clash_test.dart; No key and
// resets: settings_shortcuts_reset_test.dart; the rows' layout and
// goldens: settings_shortcuts_rows_test.dart; renders:
// settings_shortcuts_renders_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_actions.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/shortcut_row.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'shortcuts_harness.dart';

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
}
