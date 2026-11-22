// Settings › Keyboard shortcuts (ADR 0146): No key, Reset and Reset all,
// and where the keyboard's focus goes after each.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show Button;
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'shortcuts_harness.dart';

void main() {
  setUpAll(loadFonts);

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
