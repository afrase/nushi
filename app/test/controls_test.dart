import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'theme_sets.dart';

/// Each control five times: at rest, under the pointer, focused from the
/// keyboard, pressed (the pointer down on it), disabled; each builds one,
/// pressable or not.
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
  // A card's own controls (ADR 0111).
  'button_quiet': ({required on}) => Button(
    label: 'Reject',
    kind: ButtonKind.quiet,
    onPressed: on ? () {} : null,
  ),
  'pill_button': ({required on}) => PillButton(
    label: 'Stop and send',
    icon: Icons.fast_forward,
    onPressed: on ? () {} : null,
  ),
  'pill_small': ({required on}) => PillButton(
    label: 'Preview',
    icon: Icons.visibility_outlined,
    small: true,
    onPressed: on ? () {} : null,
  ),
  'round_plain': ({required on}) => RoundButton(
    tooltip: 'Add',
    onPressed: on ? () {} : null,
    glyph: (color) => LineIcon.plus.view(size: 18, color: color),
  ),
  'round_primary': ({required on}) => RoundButton(
    kind: RoundKind.primary,
    tooltip: 'Send',
    onPressed: on ? () {} : null,
    glyph: (color) => Icon(Icons.arrow_upward, size: 17, color: color),
  ),
  'menu_pill': ({required on}) => MenuField(
    pill: true,
    label: const Text('Accept edits'),
    entries: [if (on) MenuEntry('Accept edits', onPick: () {})],
  ),
  'link': ({required on}) =>
      LinkText('Settings › Agents', onTap: on ? () {} : null),
  'icon': ({required on}) =>
      IconTap(Icons.close, tooltip: 'Close', onTap: on ? () {} : null),
};

Widget _app(Tokens tokens, Widget child) => themed(child, tokens: tokens);

void main() {
  testWidgets('a shortcut keeps its line as high with ⌘ a size up', (
    tester,
  ) async {
    const style = TextStyle(fontFamily: NushiTheme.codeFont, fontSize: 11);
    Future<double> height(Widget text) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: text),
        ),
      );
      return tester.getSize(find.byType(RichText)).height;
    }

    final plain = await height(const Text('⌘N', style: style));
    expect(await height(keyText('⌘N', style)), plain);
    final span = tester.widget<Text>(find.byType(Text)).textSpan;
    final marks = (span! as TextSpan).children!.cast<TextSpan>().toList();
    expect(marks.map((m) => m.text), ['⌘', 'N']);
    expect(marks.first.style!.fontSize, greaterThan(11));
  });

  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final MapEntry(key: control, value: make) in _controls.entries) {
      testWidgets('golden, $control at rest, hovered, focused, pressed, '
          'disabled, $name', (tester) async {
        // A card's controls are taller than the rest.
        final tall =
            control.startsWith('pill') ||
            control.startsWith('round') ||
            control == 'menu_pill';
        viewport(tester, Size(760, tall ? 80 : 72), ratio: 2);
        const states = ['rest', 'hover', 'focused', 'pressed', 'disabled'];
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
        // A second mouse's button down on the fourth, held (a finger
        // would turn the hover and focus highlights off).
        final pressed = tester.getCenter(
          find
              .descendant(
                of: find.byKey(const ValueKey('pressed')),
                matching: find.byType(Pressable),
              )
              .first,
        );
        final press = TestPointer(9, PointerDeviceKind.mouse, 2);
        tester.binding
          ..handlePointerEvent(press.addPointer(location: pressed))
          ..handlePointerEvent(press.down(pressed));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/control_${control}_$name.png'),
        );
        tester.binding
          ..handlePointerEvent(press.up())
          ..handlePointerEvent(press.removePointer());
        await tester.pumpAndSettle();
      });
    }
  }

  // The filled controls, a field and a checkbox on a pane and on a card,
  // in every built-in theme: looked at as a render (`make renders
  // TEST=test/controls_test.dart`), since a button reads by its fill.
  testWidgets('every kind in every built-in theme, on a pane and a card', (
    tester,
  ) async {
    viewport(tester, Size(1500, everySet.length * 96.0 + 8));
    Widget row(Tokens t, Color fill) => Container(
      color: fill,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        spacing: 10,
        children: [
          for (final kind in ButtonKind.values)
            Button(label: kind.name, kind: kind, onPressed: () {}),
          const Button(label: 'disabled', onPressed: null),
          MenuField(
            label: const Text('Menu field'),
            entries: [MenuEntry('One', onPick: () {})],
          ),
          const SizedBox(
            width: 150,
            child: TextField(
              decoration: InputDecoration(hintText: 'A field', isDense: true),
            ),
          ),
          Checkbox(value: false, onChanged: (_) {}),
          Checkbox(value: true, onChanged: (_) {}),
          Checkbox(value: null, tristate: true, onChanged: (_) {}),
          Segmented(
            value: 1,
            segments: const [(1, 'One'), (2, 'Two')],
            onChanged: (_) {},
          ),
          IconTap(Icons.refresh, tooltip: 'Reload', onTap: () {}),
          LinkText('A link', onTap: () {}),
        ],
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          key: const ValueKey('sheet'),
          children: [
            for (final (_, t) in everySet)
              SizedBox(
                height: 96,
                child: themed(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: row(t, t.base)),
                      Expanded(child: row(t, t.raised)),
                    ],
                  ),
                  tokens: t,
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Button), findsNWidgets(everySet.length * 12));
    await render(
      tester,
      find.byKey(const ValueKey('sheet')),
      'controls_themes',
    );
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a field and a checkbox on a pane and a card, $name', (
      tester,
    ) async {
      viewport(tester, const Size(600, 152), ratio: 2);
      Widget row(Color fill) => Container(
        color: fill,
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            const SizedBox(
              width: 150,
              child: TextField(
                decoration: InputDecoration(hintText: 'Empty', isDense: true),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: TextEditingController(text: 'Written'),
                enabled: false,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            Checkbox(value: false, onChanged: (_) {}),
            Checkbox(value: true, onChanged: (_) {}),
            Checkbox(value: null, tristate: true, onChanged: (_) {}),
            const Checkbox(value: true, onChanged: null),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          tokens,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [row(tokens.base), row(tokens.raised)],
          ),
        ),
      );
      // The first field has the caret, so its edge is the focus color.
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // its edge fades
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/control_fields_$name.png'),
      );
    });
  }

  testWidgets('what can be pressed shows the pointing hand; disabled, not', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Tokens.dark,
        Wrap(
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

  // In a light set the focus color is within a shade of the accent's fill
  // (Nushi's 1.2:1): a focused primary has a line of onAccent at its edge,
  // its ring outside it, which read in every set (`tokens_test`'s
  // onAccent on accent).
  for (final (name, t) in everySet) {
    testWidgets('a focused primary button’s ring stands off its fill '
        '($name)', (tester) async {
      await tester.pumpWidget(
        _app(
          t,
          Button(label: 'Done', kind: ButtonKind.primary, onPressed: () {}),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Button),
              matching: find.byType(Container),
            )
            .first,
      );
      final ring = (box.foregroundDecoration! as ShapeDecoration).shape;
      // The line's 2 inside its edge (the ring is outside), in those colors.
      expect(ring.dimensions, const EdgeInsets.all(2));
      expect('$ring', allOf(contains('${t.focus}'), contains('${t.onAccent}')));
    });
  }

  testWidgets('the phone’s icon and button are Pressables: Tab focuses '
      'each, its ring shows, Enter presses it', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      _app(
        Tokens.light,
        TouchTargets(
          child: Column(
            children: [
              PhoneIcon(Icons.close, label: 'Close', onTap: () => presses++),
              PhoneButton('Archive', onTap: () => presses++),
            ],
          ),
        ),
      ),
    );
    for (final control in [PhoneIcon, PhoneButton]) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(control),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.foregroundDecoration != null);
      expect(ring, isNotEmpty, reason: '$control focused');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    }
    expect(presses, 2);
  });

  testWidgets('the phone’s button is a Button 48 high, full width: its '
      'corners that height’s share, its kind’s fill and ink, faded without '
      'its tap, and a destructive one pressed on red’s soft fill', (
    tester,
  ) async {
    const t = Tokens.light;
    await tester.pumpWidget(
      _app(
        t,
        TouchTargets(
          child: SizedBox(
            width: 300,
            child: Column(
              children: [
                PhoneButton('Pair', primary: true, onTap: () {}),
                PhoneButton('Forget', destructive: true, onTap: () {}),
                const PhoneButton('Later', onTap: null),
              ],
            ),
          ),
        ),
      ),
    );
    // The button's box: the Container that fills it.
    Container box(String label) => tester
        .widgetList<Container>(
          find.ancestor(of: find.text(label), matching: find.byType(Container)),
        )
        .firstWhere((c) => c.decoration != null);
    BoxDecoration fill(String label) => box(label).decoration! as BoxDecoration;
    for (final label in ['Pair', 'Forget', 'Later']) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(Button)),
        findsOneWidget,
      );
      final r = tester.getRect(find.byWidget(box(label)));
      expect(r.height, 48, reason: label);
      expect(r.width, 300, reason: label);
      expect(
        fill(label).borderRadius,
        BorderRadius.circular(ControlSize.radiusFor(48)),
      );
      expect(
        tester.widget<Text>(find.text(label)).style!.fontWeight,
        FontWeight.w500,
      );
    }
    expect(fill('Pair').color, t.accent);
    expect(tester.widget<Text>(find.text('Forget')).style!.color, t.crashed);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('Later'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.45,
    );
    final press = await tester.startGesture(
      tester.getCenter(find.text('Forget')),
    );
    await tester.pump();
    expect(fill('Forget').color, Color.alphaBlend(t.pressed, t.crashedSoft));
    await press.up();
  });

  testWidgets('the phone’s button wraps a long label and grows, rather '
      'than cutting it (a workflow’s name in Stop Workflow)', (tester) async {
    const label = 'Stop Workflow: Refactor auth and tests';
    await tester.pumpWidget(
      _app(
        Tokens.light,
        TouchTargets(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 288,
              child: PhoneButton(label, destructive: true, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    final text = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(label), matching: find.byType(RichText)),
    );
    expect(text.didExceedMaxLines, isFalse);
    expect(tester.getSize(find.byType(PhoneButton)).height, greaterThan(48));
  });

  testWidgets('WideButton’s corners are its height’s share; a PillLink '
      'without its tap is faded', (tester) async {
    await tester.pumpWidget(
      _app(
        Tokens.light,
        Column(
          children: [
            WideButton(label: 'New chat', onPressed: () {}),
            const PillLink('NUS-142', onTap: null),
          ],
        ),
      ),
    );
    final wide = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(WideButton),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (wide.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(ControlSize.radiusFor(WideButton.height)),
    );
    expect(
      find.descendant(
        of: find.byType(PillLink),
        matching: find.byType(Opacity),
      ),
      findsOne,
    );
  });

  testWidgets('a long key gives way to its label in a WideButton and a '
      'Button: the label stays whole, nothing overflows', (tester) async {
    const keys = 'Ctrl+Alt+Shift+Page Up';
    for (final (width, shows) in [
      (140.0, false),
      (230.0, false),
      (400.0, true),
    ]) {
      await tester.pumpWidget(
        _app(
          Tokens.dark,
          Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WideButton(
                    label: 'New chat',
                    icon: Icons.add,
                    hint: keys,
                    onPressed: () {},
                  ),
                  Button(label: 'New chat', hint: keys, onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$width');
      for (final button in [WideButton, Button]) {
        final inside = find.descendant(
          of: find.byType(button),
          matching: find.text('New chat'),
        );
        final label = tester.renderObject<RenderParagraph>(inside);
        expect(label.didExceedMaxLines, isFalse, reason: '$button $width');
        final key = find.descendant(
          of: find.byType(button),
          matching: find.text(keys, findRichText: true),
        );
        final hits = tester
            .hitTestOnBinding(tester.getCenter(key))
            .path
            .map((e) => e.target);
        expect(
          hits.contains(tester.renderObject(key)),
          shows,
          reason: '$button $width',
        );
      }
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

  testWidgets('the labels a button or a link keeps room for are never '
      'shown: it is as wide as the widest, and only its own is found', (
    tester,
  ) async {
    Widget host(String button, String link, {bool room = true}) => _app(
      Tokens.light,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Button(
            label: button,
            roomFor: room ? const ['Copy', 'Copied'] : const [],
            onPressed: () {},
          ),
          LinkText(
            link,
            roomFor: room ? const ['Show', 'Hide'] : const [],
            onTap: () {},
          ),
        ],
      ),
    );
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host('Copy', 'Show'));
    final button = tester.getRect(find.byType(Button));
    final link = tester.getRect(find.byType(LinkText));
    // A test that waits for "Copied" must not find the room kept for it.
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Copied'), findsNothing);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Hide'), findsNothing);
    expect(find.bySemanticsLabel('Copied'), findsNothing);
    expect(find.bySemanticsLabel('Hide'), findsNothing);

    await tester.pumpWidget(host('Copied', 'Hide'));
    expect(tester.getRect(find.byType(Button)), button);
    expect(tester.getRect(find.byType(LinkText)), link);
    expect(find.text('Copied'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Show'), findsNothing);
    expect(find.bySemanticsLabel('Copy'), findsNothing);
    expect(find.bySemanticsLabel('Show'), findsNothing);

    // Without the room each is only as wide as the label it shows.
    await tester.pumpWidget(host('Copy', 'Hide', room: false));
    expect(tester.getRect(find.byType(Button)).width, lessThan(button.width));
    expect(tester.getRect(find.byType(LinkText)).width, lessThan(link.width));
    handle.dispose();
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

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a tooltip with its key, ⇧ and ⌘ drawn, $name', (
      tester,
    ) async {
      viewport(tester, const Size(220, 72), ratio: 2);
      await tester.pumpWidget(
        // Without the debug banner, which would lie over it.
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Builder(
                builder: (context) => tooltip(
                  context,
                  withKey('Hide file tree', '⇧⌘Y'),
                  const SizedBox(width: 16, height: 16),
                ),
              ),
            ),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      tester.state<TooltipState>(find.byType(Tooltip)).ensureTooltipVisible();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // its fade in
      // The key's symbols are the code font's: the UI font has no ⇧ or ⌘,
      // and drew them as empty boxes.
      final spans = <TextSpan>[];
      for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
        r.text.visitChildren((s) {
          if (s case TextSpan(:final text?) when text.contains('⌘')) {
            spans.add(s);
          }
          return true;
        });
      }
      final key = spans.single;
      expect(key.style!.fontFamilyFallback, contains(NushiTheme.codeFont));
      // The app, whose overlay holds the tooltip.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/control_tooltip_key_$name.png'),
      );
    });
  }
}
