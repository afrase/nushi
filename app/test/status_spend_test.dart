import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A day's usage: [usd] spent over [turns] turns.
GetUsageResponse _day(double usd, {int turns = 14}) => GetUsageResponse(
  earliest: msAgo(const Duration(days: 3)),
  totals: UsageTotals(
    cost: [if (usd > 0) UsageCost(currency: 'USD', amount: usd)],
    inputTokens: Int64(120000),
    outputTokens: Int64(9000),
    turns: Int64(turns),
  ),
);

/// The card's spend of [amount], with its word.
Finder _spend(String amount) => find.text('$amount today', findRichText: true);

/// The GetUsage requests [fake] was sent, in order.
List<GetUsageRequest> _asked(FakeDaemon fake) =>
    fake.calls.whereType<GetUsageRequest>().toList();

/// The card on its own, at a sidebar's width, on [fake].
Future<Daemon> _card(
  WidgetTester tester,
  FakeDaemon fake, {
  Tokens tokens = Tokens.dark,
  double width = 260,
  int? api,
}) async {
  viewport(tester, Size(width, 80));
  // An older daemon says so at each ping.
  if (api != null) {
    fake.on(
      (input) => input is PingRequest ? PingResponse(apiVersion: api) : null,
    );
  }
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 8),
          child: StatusBar(d),
        ),
      ),
      tokens: tokens,
      banner: false,
    ),
  );
  await tester.pump();
  await tester.pump();
  return d;
}

void main() {
  setUpAll(loadFonts);

  testWidgets("today's spend: what GetUsage sums from the Mac's midnight, "
      'as Usage writes money', (tester) async {
    final fake = FakeDaemon([])..usage = _day(12.4);
    final d = await _card(tester, fake);
    expect(_spend(r'$12.40'), findsOne);
    final midnight = DateTime(
      fixtureNow.year,
      fixtureNow.month,
      fixtureNow.day,
    );
    expect(_asked(fake).single.from.toInt(), midnight.millisecondsSinceEpoch);
    await closeView(tester, d);
  });

  testWidgets('no cost today (nothing spent, or an agent that reports '
      r'none): no spend at all, not $0.00', (tester) async {
    final fake = FakeDaemon([])..usage = _day(0, turns: 6);
    final d = await _card(tester, fake);
    expect(_asked(fake), hasLength(1));
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.byKey(const ValueKey('status-spend')), findsNothing);
    // The memory still shows, at the card's start in the spend's place.
    expect(find.text('438 MB'), findsOne);
    expect(tester.getRect(find.text('438 MB')).left, lessThan(50));
    await closeView(tester, d);
  });

  testWidgets(r'a cost too small to write as a cent: no spend, not $0.00', (
    tester,
  ) async {
    final fake = FakeDaemon([])..usage = _day(0.004);
    final d = await _card(tester, fake);
    expect(_asked(fake), hasLength(1));
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.byKey(const ValueKey('status-spend')), findsNothing);
    await closeView(tester, d);
  });

  testWidgets("the spend's tooltip, and a press opens Settings › Usage", (
    tester,
  ) async {
    final fake = FakeDaemon([])..usage = _day(12.4);
    final d = await _card(tester, fake);
    expect(find.byTooltip('Spent today, 14 turns'), findsOne);
    await tester.tap(find.byKey(const ValueKey('status-spend')));
    await tester.pump();
    expect(d.settingsOpen?.section, SettingsSection.usage);
    await closeView(tester, d);
  });

  testWidgets("an older daemon, which can't answer GetUsage, is never "
      'asked and the card shows no spend', (tester) async {
    final fake = FakeDaemon([])..usage = _day(12.4);
    final d = await _card(tester, fake, api: usageApi - 1);
    await tester.pump(const Duration(minutes: 2));
    expect(_asked(fake), isEmpty);
    expect(find.byKey(const ValueKey('status-spend')), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('asked once a minute while the window shows, never while '
      'hidden, at once as it shows again', (tester) async {
    final fake = FakeDaemon([])..usage = _day(1);
    final d = await _card(tester, fake);
    expect(_asked(fake), hasLength(1));
    fake.usage = _day(2);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(_asked(fake), hasLength(2));
    expect(_spend(r'$2.00'), findsOne);

    d.macView.window = false;
    await tester.pump(const Duration(minutes: 5));
    expect(_asked(fake), hasLength(2));
    fake.usage = _day(3);
    d.macView.window = true;
    await tester.pump();
    await tester.pump();
    expect(_asked(fake), hasLength(3));
    expect(_spend(r'$3.00'), findsOne);
    await closeView(tester, d);
  });

  testWidgets("asked as any chat's turn ends", (tester) async {
    final fake = FakeDaemon([chat('a', 'claude', 'Fix the login redirect')])
      ..usage = _day(1);
    final d = await _card(tester, fake);
    d.select('a'); // loaded, so its events apply
    await tester.pumpAndSettle();
    final before = _asked(fake).length;
    var seq = 1;
    Future<void> status(ChatStatus s) async {
      fake.emit(
        EventsResponse(status: s)
          ..seq = Int64(seq++)
          ..chatId = 'a',
      );
      await tester.pump();
      await tester.pump();
    }

    await status(ChatStatus(busy: true, started: Int64(1)));
    expect(_asked(fake), hasLength(before));
    fake.usage = _day(4.5);
    await status(ChatStatus(ended: TurnEnd.TURN_END_DONE));
    expect(_asked(fake), hasLength(before + 1));
    expect(_spend(r'$4.50'), findsOne);
    await closeView(tester, d);
  });

  testWidgets('asked as the daemon answers again after it was gone', (
    tester,
  ) async {
    final fake = FakeDaemon([])..usage = _day(2);
    final d = await _card(tester, fake);
    expect(_asked(fake), hasLength(1));
    fake.down = true;
    await tester.pump(const Duration(seconds: 6));
    expect(d.connected, isFalse);
    fake
      ..usage = _day(7)
      ..down = false;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(d.connected, isTrue);
    expect(_asked(fake), hasLength(2));
    expect(_spend(r'$7.00'), findsOne);
    await closeView(tester, d);
  });

  testWidgets('the last answer stays while another is asked, and after a '
      'failed ask', (tester) async {
    final fake = FakeDaemon([])..usage = _day(12.4);
    final d = await _card(tester, fake);
    expect(_spend(r'$12.40'), findsOne);

    // The fake records a call once it's answered: these count the asks.
    var asks = 0;
    final later = Completer<GetUsageResponse>();
    fake.on((input) {
      if (input is! GetUsageRequest) return null;
      asks++;
      return later.future;
    });
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(asks, 1);
    expect(_spend(r'$12.40'), findsOne);
    later.complete(_day(13));
    await tester.pump();
    await tester.pump();
    expect(_spend(r'$13.00'), findsOne);

    fake.on((input) {
      if (input is! GetUsageRequest) return null;
      asks++;
      throw ConnectException(Code.internal, 'database is locked');
    });
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(asks, 2);
    expect(_spend(r'$13.00'), findsOne);
    expect(find.textContaining('locked'), findsNothing);
    await closeView(tester, d);
  });

  testWidgets('the narrowest sidebar shows the spend and the memory '
      'whole', (tester) async {
    final fake = FakeDaemon([])..usage = _day(1234.5);
    final width = Sidebar.minWidth;
    final d = await _card(tester, fake, width: width);
    for (final f in [
      find.byKey(const ValueKey('status-spend')),
      find.text('438 MB'),
    ]) {
      expect(f, findsOne);
      final r = tester.getRect(f);
      expect(r.left, greaterThanOrEqualTo(10));
      expect(r.right, lessThanOrEqualTo(width - 8));
    }
    expectTextInside(tester, width);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final usd in [12.4, 0.0]) {
      final which = usd > 0 ? 'spend' : 'no_spend';
      testWidgets('golden: the card, $which ($name)', (tester) async {
        final fake = FakeDaemon([
          chat('a', 'claude', 'A', status: ChatStatus(busy: true)),
          chat('b', 'claude', 'B', status: ChatStatus(asleep: true)),
        ])..usage = _day(usd);
        final d = await _card(tester, fake, tokens: tokens);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/status_card_${which}_$name.png'),
        );
        await closeView(tester, d);
      });
    }
  }
}
