import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A message's reply cards are numbered when it carries two or more: the
// agent answers "#1 … #2 …" by the marks in the text, and the user sees
// the same numbers on the cards in the box and in the sent message.

const _mine = 'My review comments on your changes:';

const List<Reply> _cards = [
  (
    quote: '`cmd/server/main.go`, line 48:\n```go\ntracer := New(\n```',
    text: 'Should this be tracerClient?',
    from: _mine,
  ),
  (
    quote: '`cmd/server/main.go`, line 61:\n```go\nreturn nil\n```',
    text: 'The error is dropped here.',
    from: _mine,
  ),
  (quote: 'kept as a DateTime', text: 'Why not the string?', from: ''),
];

Finder _number(int n) => find.byKey(ValueKey('reply-number-$n'));

/// The app on a chat with a sent message of three cards, and three more in
/// the box.
Future<Future<void> Function()> _open(
  WidgetTester tester, {
  Size size = const Size(1700, 900),
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tracer setup');
  final fake = FakeDaemon([c])
    ..chatItems['c'] = [
      Item(
        id: 'u1',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: withReplies(_cards, 'Anything else you would change?'),
      ),
      Item(
        id: 'm1',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text:
            '#1: yes, renamed.\n\n#2: it returns the error now.\n\n'
            '#3: parsing once keeps sorting cheap.',
      ),
    ];
  final d = await fake.connect(tester);
  d.select('c');
  _cards.forEach(d.chats['c']!.draft.addReply);
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return () => closeView(tester, d);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('cards in the box are numbered from two, and renumber as one '
      'is removed', (tester) async {
    final end = await _open(tester);
    final box = find.byType(ReplyCards);
    Finder inBox(Finder f) => find.descendant(of: box, matching: f);
    expect(inBox(find.byType(ReplyNumber)), findsNWidgets(3));
    // Each number at its own card's start, before its quote.
    for (final (i, r) in _cards.indexed) {
      final text = tester.getRect(inBox(find.text(r.text)));
      final n = tester.getRect(inBox(_number(i + 1)));
      expect(n.right, lessThan(text.left + 30));
      expect(n.left, greaterThan(text.left - 30));
      expect(n.top, lessThan(text.top));
    }

    // The first card removed from its hover's button: the others are 1
    // and 2, as the message will be written.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(inBox(find.text(_cards[0].text))));
    await tester.pumpAndSettle();
    await tester.tap(inBox(find.byType(RemoveBadge)));
    await tester.pumpAndSettle();
    expect(inBox(find.byType(ReplyNumber)), findsNWidgets(2));
    expect(inBox(_number(3)), findsNothing);
    final now = tester.getRect(inBox(find.text(_cards[1].text)));
    expect(
      (tester.getRect(inBox(_number(1))).left - now.left).abs(),
      lessThan(30),
      reason: 'the second card is 1 now',
    );

    // One left: no number, as before numbers.
    await mouse.moveTo(tester.getCenter(inBox(find.text(_cards[1].text))));
    await tester.pumpAndSettle();
    await tester.tap(inBox(find.byType(RemoveBadge)));
    await tester.pumpAndSettle();
    expect(inBox(find.text(_cards[2].text)), findsOneWidget);
    expect(inBox(find.byType(ReplyNumber)), findsNothing);
    await end();
  }, variant: onMac);

  testWidgets('a sent message numbers its cards from two; one alone has '
      'none, and no number is ever in the text', (tester) async {
    Future<void> show(String message) =>
        tester.pumpWidget(themed(UserMessageText(message)));
    await show(withReplies(_cards, 'Anything else?'));
    expect(find.byType(ReplyNumber), findsNWidgets(3));
    expect(find.textContaining('reply 1'), findsNothing);
    // Each number left of its card's quote, level with its top.
    for (final (i, r) in _cards.indexed) {
      final quote = tester.getRect(
        find.ancestor(
          of: find.text(r.quote),
          matching: find.byType(QuoteBlock),
        ),
      );
      final n = tester.getRect(_number(i + 1));
      expect(n.right, lessThanOrEqualTo(quote.left));
      expect((n.top - quote.top).abs(), lessThan(8));
    }
    await show(withReplies(_cards.sublist(0, 1), 'Anything else?'));
    expect(find.byType(ReplyNumber), findsNothing);
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('goldens, three cards in the box and sent, $name', (
      tester,
    ) async {
      final end = await _open(tester, brightness: brightness);
      FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ReplyCards),
        matchesGoldenFile('goldens/numbered_reply_cards_$name.png'),
      );
      await expectLater(
        find.ancestor(
          of: find.byType(UserMessageText),
          matching: find.byType(RewindTarget),
        ),
        matchesGoldenFile('goldens/numbered_replies_sent_$name.png'),
      );
      await end();
    }, variant: onMac);
  }

  for (final width in [1700.0, 720.0]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets('the window ${width.round()} wide, $name', (tester) async {
        final end = await _open(
          tester,
          size: Size(width, 900),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(ReplyNumber), findsNWidgets(6));
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'numbered_replies_${width.round()}_$name',
        );
        await end();
      }, variant: onMac);
    }
  }
}
