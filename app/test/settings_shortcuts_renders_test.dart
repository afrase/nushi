// Settings › Keyboard shortcuts drawn at full size in the app, wide and
// narrow, dark and light, on the Mac and on Linux (where a chosen key's
// words are long), in each state a row has: an edited row with the
// pointer off it and on it, listening, a clash, a refusal, keys not
// used, and the page's end. Renders to look at (`make renders`), and
// what they show checked as they're drawn.
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/key_choice.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'shortcuts_harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final (size, w) in [
    (const Size(1700, 1000), 'wide'),
    (const Size(720, 900), 'narrow'),
  ]) {
    for (final b in Brightness.values) {
      testWidgets('renders, $w, ${b.name}', (tester) async {
        final linux = defaultTargetPlatform == TargetPlatform.linux;
        if (linux) shortcutsOnLinux();
        final command = linux ? ctrlKey : metaKey;
        final name =
            'settings_shortcuts_${linux ? 'linux' : 'mac'}_${w}_'
            '${b.name}';
        // New chat edited: on Linux a long key, as Ctrl+Alt+Shift+Page Up.
        shortcutKeys.value = {
          'newChat': linux ? 'Alt+Shift+Cmd+PageUp' : 'Shift+Cmd+N',
        };
        final d = await pumpSettingsApp(
          tester,
          settingsFake(),
          SettingsSection.shortcuts,
          size: size,
          brightness: b,
        );
        // [id]'s row a third of the way down, its neighbours in sight.
        Future<void> toward(String id) async {
          await Scrollable.ensureVisible(
            tester.element(rowOf(id)),
            alignment: 0.3,
          );
          await tester.pumpAndSettle();
        }

        Future<void> shot(String state) async {
          expect(tester.takeException(), isNull, reason: state);
          expectTextInside(tester, size.width);
          await render(tester, find.byType(NushiApp), '${name}_$state');
        }

        await shot('top');
        // The pointer on the edited row.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(rowOf('newChat')));
        await tester.pumpAndSettle();
        await shot('hover');
        await mouse.moveTo(const Offset(1, 1));
        await tester.pumpAndSettle();
        await mouse.removePointer();
        await toward('closeTab');
        await tester.tap(keyOf('closeTab'));
        await tester.pumpAndSettle();
        expect(shortcutRecording.value, isTrue);
        await shot('listening');
        await pressKey(tester, LogicalKeyboardKey.keyS, [command]);
        await toward('closeTab');
        await shot('clash');
        await tapIt(
          tester,
          find.byKey(const ValueKey('shortcut-cancel-closeTab')),
        );
        await recordKey(tester, 'closeTab', LogicalKeyboardKey.keyC, [command]);
        await toward('closeTab');
        await shot('refused');
        await pressKey(tester, LogicalKeyboardKey.escape);
        // Keys not used (a saved key refused, a default another holds),
        // and a note (on Linux a terminal keeps Ctrl+Alt+R).
        shortcutKeys.value = {
          ...shortcutKeys.value,
          'sidebar': 'Cmd+K',
          'find': 'Cmd+C',
          'reloadPage': 'Alt+Cmd+R',
        };
        await tester.pumpAndSettle();
        final page = find.byWidget(
          tester.widget(
            find
                .ancestor(
                  of: rowOf('closeTab'),
                  matching: find.byType(Scrollable),
                )
                .first,
          ),
        );
        await tester.scrollUntilVisible(
          rowOf('palette'),
          -300,
          scrollable: page,
        );
        await toward('find');
        await shot('notused');
        await tester.scrollUntilVisible(
          find.text('Quit'),
          300,
          scrollable: page,
        );
        await tester.pumpAndSettle();
        await shot('end');
        // The long key on the sidebar's New chat too.
        if (b == Brightness.dark) {
          d.select('a');
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(NushiApp),
            'sidebar_long_key_${linux ? 'linux' : 'mac'}_$w',
          );
        }
        d.dispose();
      }, variant: macAndLinux);
    }
  }
}
