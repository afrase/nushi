import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// Each control four times: at rest, under the pointer, focused from the
/// keyboard, disabled; each builds one, pressable or not.
final _controls = <String, Widget Function({required bool on})>{
  'button_primary': ({required on}) => Button(
    label: 'Done',
    kind: ButtonKind.primary,
    onPressed: on ? () {} : null,
  ),
  'button_secondary': ({required on}) =>
      Button(label: 'Show logs', onPressed: on ? () {} : null),
  'button_destructive': ({required on}) => Button(
    label: 'Delete…',
    kind: ButtonKind.destructive,
    onPressed: on ? () {} : null,
  ),
  'menu_field': ({required on}) => MenuField(
    label: const Text('JetBrains Mono'),
    entries: [if (on) MenuEntry('JetBrains Mono', onPick: () {})],
  ),
  'menu_compact': ({required on}) => MenuField(
    compact: true,
    label: const Text('Only me'),
    entries: [if (on) MenuEntry('Only me', onPick: () {})],
  ),
  'link': ({required on}) =>
      LinkText('Settings › Agents', onTap: on ? () {} : null),
  'icon': ({required on}) =>
      IconTap(Icons.close, tooltip: 'Close', onTap: on ? () {} : null),
};

Widget _app(Tokens tokens, Widget child) => MaterialApp(
  theme: NushiTheme(tokens).toThemeData(),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final MapEntry(key: control, value: make) in _controls.entries) {
      testWidgets('golden, $control at rest, hovered, focused, disabled, '
          '$name', (tester) async {
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(600, 72) * 2;
        addTearDown(tester.view.reset);
        const states = ['rest', 'hover', 'focused', 'disabled'];
        await tester.pumpWidget(
          _app(
            tokens,
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                spacing: 16,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in states)
                    Column(
                      key: ValueKey(s),
                      spacing: 6,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        make(on: s != 'disabled'),
                        Text(
                          s,
                          style: NushiTheme(tokens)
                              .ui(tokens.textMuted, size: 11),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
        // Tab to the third (rest, hover, then focused), point at the second.
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        }
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: tester.getCenter(
            find
                .descendant(
                  of: find.byKey(const ValueKey('hover')),
                  matching: find.byType(Pressable),
                )
                .first,
          ),
        );
        addTearDown(mouse.removePointer);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/control_${control}_$name.png'),
        );
      });
    }
  }

  testWidgets('what can be pressed shows the pointing hand; disabled, not', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Tokens.dark,
        Column(
          children: [
            for (final make in _controls.values) ...[
              make(on: true),
              make(on: false),
            ],
          ],
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final pressables = find.byType(Pressable);
    for (var i = 0; i < pressables.evaluate().length; i++) {
      await mouse.moveTo(tester.getCenter(pressables.at(i)));
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        i.isEven ? SystemMouseCursors.click : SystemMouseCursors.basic,
        reason: 'control $i',
      );
    }
  });

  testWidgets('Enter and Space press a focused control', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      _app(
        Tokens.light,
        Column(
          children: [
            Button(label: 'Go', onPressed: () => presses++),
            LinkText('There', onTap: () => presses++),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });

  testWidgets('a menu field opens its menu', (tester) async {
    String? picked;
    await tester.pumpWidget(
      _app(
        Tokens.light,
        Center(
          child: MenuField(
            label: const Text('12.5'),
            entries: [
              for (final s in ['12', '12.5', '13'])
                MenuEntry(s, onPick: () => picked = s),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    await tester.tap(find.text('12.5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('13'));
    await tester.pumpAndSettle();
    expect(picked, '13');
  });
}
