// Jump to latest on the phone: a round ↓ over the transcript's bottom
// right, where a thumb reaches (the Mac's is in the column's middle); it
// says what it is to VoiceOver and in its tooltip, and takes the chat
// back down.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final Chat _chat = chat('a', 'claude', 'Fix the flaky relay test');

GetChatResponse _items() => GetChatResponse(
  chat: _chat,
  items: [
    for (var i = 0; i < 12; i++) ...[
      Item(
        id: 'u$i',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'Question $i',
      ),
      Item(
        id: 'm$i',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text: 'Answer $i, long enough to take a couple of lines on a phone.',
      ),
    ],
  ],
);

void main() {
  setUpAll(loadFonts);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    if (rendering) ('light', Brightness.light),
  ]) {
    testWidgets('scrolled up, a round ↓ takes the chat back down, $name', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844), ratio: 3, brightness: brightness);
      final fake = FakeDaemon([_chat])
        ..answer = (input) => input is GetChatRequest ? _items() : null;
      final phone = await startPhone(tester, fake);
      await tester.tap(find.text('Fix the flaky relay test'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.textContaining('Answer 9').first,
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      final chip = find.byType(JumpChip);
      expect(chip, findsOneWidget);
      await render(tester, find.byType(PhoneApp), 'phone_jump_$name');

      // An arrow alone, no words; named for VoiceOver and its tooltip.
      expect(
        find.descendant(of: chip, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(of: chip, matching: find.byIcon(Icons.arrow_downward)),
        findsOneWidget,
      );
      expect(find.byTooltip('Jump to latest'), findsOneWidget);
      expect(
        tester.getSemantics(find.byTooltip('Jump to latest')),
        isSemantics(isButton: true, tooltip: 'Jump to latest'),
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      // Round and compact, in a finger's target at the bottom right.
      final round = find.descendant(
        of: chip,
        matching: find.byKey(JumpChip.roundKey),
      );
      final face = tester.getRect(round);
      expect(face.width, face.height);
      expect(face.width, inInclusiveRange(36, 40));
      expect(tester.getSize(chip).width, greaterThanOrEqualTo(44));
      expect(face.right, greaterThan(390 - 40));

      // One tap, back at the latest.
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(JumpChip), findsNothing);
      expect(find.textContaining('Answer 11'), findsWidgets);
      await endPhone(tester, phone);
    });
  }

  testWidgets('needing you, it turns amber and says so', (tester) async {
    await tester.pumpWidget(
      themed(TouchTargets(child: JumpChip(needs: true, onTap: () {}))),
    );
    await tester.pumpAndSettle();
    final t = NushiTheme.of(tester.element(find.byType(JumpChip))).t;
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_downward));
    expect(icon.color, t.needs);
    expect(find.byType(Text), findsNothing);
    expect(find.byTooltip('Needs you: jump to latest'), findsOneWidget);
  });

  testWidgets('on the desktop, a smaller round ↓, its words its tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(themed(JumpChip(needs: false, onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Jump to latest'), findsNothing);
    expect(find.byTooltip('Jump to latest'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(JumpChip.roundKey)),
      Size.square(JumpChip.face),
    );
  });
}
