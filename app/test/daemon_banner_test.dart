import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/daemon_banner.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Widget _app(Daemon d, {bool still = false, Tokens tokens = Tokens.dark}) =>
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Column(
            children: [
              RepaintBoundary(child: DaemonBanner(d)),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );

const _lost = 'Lost the connection to the daemon; reconnecting…';

void main() {
  setUpAll(loadFonts);

  /// The daemon's link drops ([down]) or comes back, as its next ping finds.
  Future<void> link(
    WidgetTester tester,
    FakeDaemon fake,
    Daemon d, {
    required bool down,
  }) async {
    fake.answer = down
        ? (i) => i is PingRequest ? throw StateError('gone') : null
        : null;
    final pinged = d.ping();
    await tester.pump();
    await tester.pump();
    await pinged;
    expect(d.connected, !down);
  }

  double height(WidgetTester tester) =>
      tester.getSize(find.byType(DaemonBanner)).height;

  testWidgets('a blip under 800 ms shows nothing; a longer loss slides the '
      'banner down, and once back it says "Reconnected", then goes', (
    tester,
  ) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(_app(d));

    await link(tester, fake, d, down: true);
    await tester.pump(const Duration(milliseconds: 400));
    await link(tester, fake, d, down: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_lost), findsNothing);
    expect(height(tester), 0);

    await link(tester, fake, d, down: true);
    await tester.pump(const Duration(milliseconds: 790));
    expect(find.text(_lost), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text(_lost), findsOneWidget);
    final full = tester.getSize(find.text(_lost)).height + 12;
    expect(height(tester), inExclusiveRange(0, full));
    await tester.pump(const Duration(milliseconds: 200));
    expect(height(tester), full);

    await link(tester, fake, d, down: false);
    expect(find.text('Reconnected'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Reconnected'), findsOneWidget);
    expect(height(tester), full);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    expect(height(tester), inExclusiveRange(0, full));
    await tester.pumpAndSettle();
    expect(find.text('Reconnected'), findsNothing);
    expect(height(tester), 0);

    await closeView(tester, d);
  });

  testWidgets('with Reduce Motion: the same grace and "Reconnected", without '
      'the slides', (tester) async {
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(_app(d, still: true));
    await link(tester, fake, d, down: true);
    await tester.pump(const Duration(milliseconds: 810));
    expect(find.text(_lost), findsOneWidget);
    final full = height(tester);
    expect(full, greaterThan(0));
    await link(tester, fake, d, down: false);
    expect(find.text('Reconnected'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1210));
    expect(find.text('Reconnected'), findsNothing);

    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, lost and reconnected, $name', (tester) async {
      viewport(tester, const Size(520, 120));
      final fake = FakeDaemon([]);
      final d = await fake.connect(tester);
      await tester.pumpWidget(_app(d, tokens: tokens));
      await link(tester, fake, d, down: true);
      await tester.pump(const Duration(milliseconds: 810));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(DaemonBanner),
        matchesGoldenFile('goldens/daemon_banner_lost_$name.png'),
      );
      await link(tester, fake, d, down: false);
      await expectLater(
        find.byType(DaemonBanner),
        matchesGoldenFile('goldens/daemon_banner_back_$name.png'),
      );
      await tester.pumpAndSettle();
      await closeView(tester, d);
    });
  }
}
