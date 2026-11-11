import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jump_chip.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Widget _app(Widget child, {bool still = false}) => themed(child, still: still);

Item _ask({String status = 'pending'}) => Item(
  id: 'p',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  status: status,
  title: 'rm -rf build/',
  options: [Option(id: 'y', name: 'Allow once')],
);

/// The waiting card's ring: its spread, or null without one.
double? _ring(WidgetTester tester) {
  final box = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(WaitingCard),
          matching: find.byType(Container),
        ),
      )
      .first;
  final shadows = (box.decoration! as BoxDecoration).boxShadow;
  return shadows?.single.spreadRadius;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a permission that comes glows once: a ring grows to 6 px '
      'and fades away; one the chat opened with has none, only its mark '
      'and its pill (ADR 0111)', (tester) async {
    await tester.pumpWidget(
      _app(
        Arriving(
          play: true,
          child: PermissionCard(_ask(), onAnswer: (_) async {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_ring(tester), lessThan(2));
    await tester.pump(const Duration(milliseconds: 110));
    expect(_ring(tester), greaterThan(4));
    await tester.pumpAndSettle();
    expect(_ring(tester), isNull);
    expect(find.text('Needs you'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(PermissionCard(_ask(), onAnswer: (_) async {})),
    );
    expect(_ring(tester), isNull);
    expect(find.text('Needs you'), findsOneWidget);

    // Answered, the pill goes as the card settles.
    await tester.pumpWidget(
      _app(PermissionCard(_ask(status: 'answered'), onAnswer: (_) async {})),
    );
    await tester.pumpAndSettle();
    expect(_ring(tester), isNull);
    expect(find.text('Needs you'), findsNothing);
  });

  testWidgets('with Reduce Motion nothing glows', (tester) async {
    await tester.pumpWidget(
      _app(
        Arriving(
          play: true,
          child: PermissionCard(_ask(), onAnswer: (_) async {}),
        ),
        still: true,
      ),
    );
    expect(_ring(tester), isNull);
    expect(find.text('Needs you'), findsOneWidget);
  });

  testWidgets('scrolled up, the Jump chip turns amber and says "Needs you" '
      'as a prompt comes, hopping once', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..items.addAll([
        for (var i = 0; i < 40; i++)
          Item(
            id: 'm$i',
            kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
            text: 'Line $i',
          ),
      ]);
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: chat,
          builder: (context, _) =>
              Transcript(chat: chat, daemon: d, onReply: null),
        ),
      ),
    );
    // Filled in (it opens on its last entries), then scrolled up.
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Jump to latest'), findsOneWidget);

    chat
      ..waiting = true
      ..items.add(_ask())
      ..notifyListeners();
    await tester.pump();
    // The chip's, beside the card's own pill under it.
    final chip = find.descendant(
      of: find.byType(JumpChip),
      matching: find.text('Needs you'),
    );
    expect(chip, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    final hop = tester.widget<Transform>(
      find.descendant(
        of: find.byType(JumpChip),
        matching: find.byType(Transform),
      ),
    );
    expect(hop.transform.getTranslation().y, lessThan(0));
    await tester.pumpAndSettle();

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(JumpChip), findsNothing);

    await closeView(tester, d);
  });

  testWidgets('with Reduce Motion the chip turns amber without the hop', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(JumpChip(needs: false, onTap: () {}), still: true),
    );
    await tester.pumpWidget(
      _app(JumpChip(needs: true, onTap: () {}), still: true),
    );
    expect(find.text('Needs you'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(JumpChip),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a waiting card, 2×, $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: enlarged(
              const Size(320, 170),
              2,
              ColoredBox(
                color: tokens.base,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PermissionCard(_ask(), onAnswer: (_) async {}),
                ),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/waiting_card_$name.png'),
      );
    });
  }
}
