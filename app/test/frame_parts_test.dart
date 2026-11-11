// The new look's own parts (ADR 0111): the card-filled wide button with its
// key's cap, the filled segmented control, a state's pill, a link's pill and
// a chat's color chip, on the fills they sit on.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _tabs = [(0, 'Chat'), (1, 'Changes'), (2, 'Pull request')];

Widget _segmented(
  int value,
  ValueChanged<int> onChanged, {
  bool roomy = true,
  bool onCard = false,
}) => Segmented(
  value: value,
  segments: _tabs,
  onChanged: onChanged,
  roomy: roomy,
  onCard: onCard,
);

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, the parts on the window, a pane and a card, $name', (
      tester,
    ) async {
      viewport(tester, const Size(760, 330));
      Widget on(Color fill, List<Widget> children) => Container(
        color: fill,
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          RepaintBoundary(
            key: const Key('shot'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The sidebar's, on the window itself.
                on(tokens.window, [
                  SizedBox(
                    width: 242,
                    child: WideButton(
                      label: 'New chat',
                      icon: Icons.add,
                      hint: '⌘N',
                      onPressed: () {},
                    ),
                  ),
                  const PhasePill(ChatPhase.waiting, small: true),
                  for (final c in ChatColor.values) ColorChip(c),
                  const KeyCap('⌘3'),
                ]),
                // The header's, on a pane.
                on(tokens.base, [
                  Segmented(
                    value: 0,
                    segments: _tabs,
                    badges: const {1: '2'},
                    onChanged: (_) {},
                    roomy: true,
                  ),
                  PillLink('LUM-142', mono: true, onTap: () {}),
                  IconTap.line(
                    LineIcon.details,
                    tooltip: '',
                    padding: IconTap.header,
                    lit: true,
                    onTap: () {},
                  ),
                  IconTap.line(
                    LineIcon.terminal,
                    tooltip: '',
                    padding: IconTap.header,
                    onTap: () {},
                  ),
                ]),
                on(tokens.base, [
                  for (final p in ChatPhase.values) PhasePill(p),
                ]),
                // A form's, in a dialog or on a card.
                on(tokens.raised, [
                  _segmented(1, (_) {}, roomy: false, onCard: true),
                  const KeyCap('⌘N'),
                ]),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/frame_parts_$name.png'),
      );
    });
  }

  testWidgets('a segment is picked by a click, and by Enter when focused; '
      'picked, the control is as wide as before', (tester) async {
    var value = 0;
    await tester.pumpWidget(
      themed(
        Center(
          child: StatefulBuilder(
            builder: (context, setState) =>
                _segmented(value, (v) => setState(() => value = v)),
          ),
        ),
      ),
    );
    final control = find.byType(Segmented<int>);
    final width = tester.getSize(control).width;
    expect(tester.getSize(control).height, 34);
    await tester.tap(find.text('Pull request'));
    await tester.pump();
    expect(value, 2);
    expect(tester.getSize(control).width, width);
    // One Tab stop each, in order; Enter picks the focused one.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(value, 1);
    expect(tester.getSize(control).width, width);
    // Each label is there once, for what reads it.
    expect(find.text('Changes'), findsOne);
  });

  testWidgets('a state’s pill says it in a word, capitalised, in the '
      'state’s ink on its soft fill', (tester) async {
    await tester.pumpWidget(
      themed(
        const Column(
          children: [
            PhasePill(ChatPhase.waiting),
            PhasePill(ChatPhase.working),
            PhasePill(ChatPhase.idle),
          ],
        ),
      ),
    );
    const t = Tokens.dark;
    Color fill(String word) =>
        (tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text(word),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    Color ink(String word) =>
        tester.widget<Text>(find.text(word)).style!.color!;
    expect((ink('Needs you'), fill('Needs you')), (t.needs, t.needsSoft));
    expect((ink('Working'), fill('Working')), (t.running, t.accentSoft));
    expect((ink('Idle'), fill('Idle')), (t.textSecondary, t.raised));
  });
}
