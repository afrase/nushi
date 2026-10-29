import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/turn_status.dart';

import 'fake_daemon.dart';

Widget _app(Widget child, {Tokens tokens = Tokens.dark, bool still = false}) =>
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 520, child: child),
          ),
        ),
      ),
    );

ChatState _working(Duration ran) {
  final chat = ChatState('c', '/x')
    ..loaded = true
    ..busy = true
    ..started = DateTime.now().subtract(ran)
    ..items.addAll([
      Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
      Item(id: 'a', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Done.'),
    ]);
  _ran[chat] = ran;
  return chat;
}

/// How long each chat's turn ran, as it ends: its start is set again just
/// before, so a slow machine's wall clock doesn't add a second.
final _ran = Expando<Duration>();

void _end(ChatState chat, {bool stopped = false}) {
  chat
    ..started = DateTime.now().subtract(_ran[chat]!)
    ..stopping = stopped
    ..notifyListeners()
    ..busy = false
    ..started = null
    ..stopping = false
    ..notifyListeners();
}

/// The check painter TurnStatus or ChatDot draws, if one shows.
CheckPainter? _check(WidgetTester tester, Type under) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(under),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((p) => p.painter)
    .whereType<CheckPainter>()
    .firstOrNull;

void main() {
  setUpAll(loadFonts);

  testWidgets('a long turn that ends while you watch leaves a receipt: the '
      'check draws, sparks fly, then the line folds away', (tester) async {
    final chat = _working(const Duration(seconds: 12));
    await tester.pumpWidget(_app(TurnStatus(chat)));
    expect(find.text('Writing'), findsOneWidget);
    final line = tester.getSize(find.byType(TurnStatus)).height;

    _end(chat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Done in 12s'), findsOneWidget);
    var check = _check(tester, TurnStatus)!;
    expect(check.drawn, inExclusiveRange(0, 1));
    expect(check.sparks, isNotNull);
    expect(tester.getSize(find.byType(TurnStatus)).height, line);

    await tester.pump(const Duration(milliseconds: 600));
    check = _check(tester, TurnStatus)!;
    expect(check.drawn, 1);
    expect(check.sparks!.done, isTrue);

    // Folding: shorter, then gone.
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.getSize(find.byType(TurnStatus)).height,
      inExclusiveRange(0, line),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Done in'), findsNothing);
    expect(tester.getSize(find.byType(TurnStatus)).height, 0);
  });

  testWidgets('a short, stopped or failed turn, or one ending unseen, gets '
      'no receipt: the line just folds', (tester) async {
    Future<void> noReceipt(ChatState chat, {bool stopped = false}) async {
      await tester.pumpWidget(_app(TurnStatus(chat)));
      _end(chat, stopped: stopped);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Done in'), findsNothing);
      expect(_check(tester, TurnStatus), isNull);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TurnStatus)).height, 0);
      await tester.pumpWidget(const SizedBox());
    }

    await noReceipt(_working(const Duration(seconds: 4)));
    await noReceipt(_working(const Duration(seconds: 30)), stopped: true);
    await noReceipt(
      _working(const Duration(seconds: 30))
        ..items.add(
          Item(id: 'e', kind: ItemKind.ITEM_KIND_NOTICE, status: 'error'),
        ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await noReceipt(_working(const Duration(seconds: 30)));
  });

  testWidgets('with Reduce Motion the receipt shows still, then goes', (
    tester,
  ) async {
    final chat = _working(const Duration(minutes: 2, seconds: 31));
    await tester.pumpWidget(_app(TurnStatus(chat), still: true));
    _end(chat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Done in 2m 31s'), findsOneWidget);
    final check = _check(tester, TurnStatus)!;
    expect((check.drawn, check.sparks), (1, null));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();
    expect(find.textContaining('Done in'), findsNothing);
  });

  testWidgets("the sidebar's dot sparks as its check draws; the header's "
      'only draws', (tester) async {
    final chat = _working(const Duration(seconds: 40));
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            ChatDot(chat: chat, sparks: true),
            ChatDot(chat: chat),
          ],
        ),
      ),
    );
    _end(chat);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<CheckPainter>()
        .toList();
    expect(painters, hasLength(2));
    expect(painters[0].sparks, isNotNull);
    expect(painters[1].sparks, isNull);
    await tester.pumpAndSettle();
  });

  // Enlarged, mid-burst: the check half drawn, the sparks on their way.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a receipt with its sparks, $name', (tester) async {
      final chat = _working(const Duration(minutes: 2, seconds: 30));
      await tester.pumpWidget(
        _app(
          enlarged(
            const Size(170, 30),
            3,
            ColoredBox(
              color: tokens.base,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TurnStatus(chat),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      _end(chat);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 110));
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/turn_receipt_$name.png'),
      );
      await tester.pumpAndSettle();
    });
  }
}
