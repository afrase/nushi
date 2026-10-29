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

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: child),
  ),
);

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

  testWidgets('a permission that comes glows once: its ring grows to 6 px '
      'and settles at 2; one the chat opened with has its 2 at once', (
    tester,
  ) async {
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
    expect(_ring(tester), 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(PermissionCard(_ask(), onAnswer: (_) async {})),
    );
    expect(_ring(tester), 2);

    await tester.pumpWidget(
      _app(PermissionCard(_ask(status: 'answered'), onAnswer: (_) async {})),
    );
    expect(_ring(tester), isNull);
  });

  testWidgets('with Reduce Motion the ring is there at once', (tester) async {
    await tester.pumpWidget(
      _app(
        Arriving(
          play: true,
          child: PermissionCard(_ask(), onAnswer: (_) async {}),
        ),
        still: true,
      ),
    );
    expect(_ring(tester), 2);
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
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Jump to latest'), findsOneWidget);

    chat
      ..waiting = true
      ..items.add(_ask())
      ..notifyListeners();
    await tester.pump();
    expect(find.text('Needs you'), findsOneWidget);
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

    await tester.tap(find.text('Needs you'));
    await tester.pumpAndSettle();
    expect(find.byType(JumpChip), findsNothing);

    await tester.pumpWidget(const SizedBox());
    d.dispose();
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
    testWidgets('golden, a waiting card with its ring, 2×, $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: enlarged(
                const Size(300, 140),
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
          ),
        ),
      );
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/waiting_ring_$name.png'),
      );
    });
  }
}
