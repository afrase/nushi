import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage_chart.dart';
import 'package:nushi/usage_page.dart';
import 'package:nushi/usage_range.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'settings_harness.dart';
import 'usage_fixtures.dart';

/// Settings › Usage on a daemon answering [usage], alone in a window of
/// [size].
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester,
  GetUsageResponse usage, {
  Size size = const Size(1000, 1700),
  Tokens tokens = Tokens.dark,
  int? api,
}) async {
  viewport(tester, size); // one pixel a point, as Settings' goldens
  final fake = settingsFake()..usage = usage;
  final d = await fake.connect(tester);
  if (api != null) d.daemonApi = api;
  await pumpSettings(
    tester,
    d,
    SettingsSection.usage,
    size: size,
    tokens: tokens,
  );
  return (fake, d);
}

/// The GetUsage requests [fake] was sent, in order.
List<GetUsageRequest> _asked(FakeDaemon fake) =>
    fake.calls.whereType<GetUsageRequest>().toList();

/// [d]'s midnight as GetUsage is asked from it.
int _ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  setUpAll(loadFonts);

  testWidgets('a busy week: spend, tokens, turns and who reports no cost', (
    tester,
  ) async {
    final (fake, d) = await _open(tester, busyUsage());
    expect(find.text(r'$145.80'), findsOneWidget);
    expect(find.text('5.8M'), findsWidgets); // in and out, not the cache
    expect(find.text('412'), findsOneWidget);
    expect(find.text('Ante and Codex report no cost'), findsOneWidget);
    expect(
      find.text('Cache: 18.3M read · 2.1M written, apart from the tokens'),
      findsOneWidget,
    );
    expect(find.text('Spend by day'), findsOneWidget);
    expect(find.text('Costliest chats'), findsOneWidget);
    // Codex's row says it has no cost rather than a $0.
    expect(find.byKey(const ValueKey('usage-no-cost')), findsWidgets);
    expect(find.text(r'$0.00'), findsNothing);
    // A project by the sidebar's name, its path under the pointer.
    expect(find.text('lumen-docs'), findsOneWidget);
    expect(find.text('/Users/me/src/lumen-docs'), findsNothing);
    expect(find.text('Deleted chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-footnote')), findsOneWidget);
    // Asked once, for the last 7 days (the default), in the daemon's zone.
    expect(_asked(fake), [GetUsageRequest(from: _int(DateTime(2026, 10, 23)))]);
    d.dispose();
  });

  for (final (tokens, theme) in [
    (Tokens.dark, 'dark'),
    (Tokens.light, 'light'),
  ]) {
    testWidgets('a day under the pointer: its column lit, its figures on a '
        'card beside the pointer, $theme', (tester) async {
      final (_, d) = await _open(tester, busyUsage(), tokens: tokens);
      final chart = find.byType(UsageDayChart);
      final card = find.byType(UsageDayCard);
      expect(card, findsNothing);
      final box = tester.getRect(chart);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      // Tuesday's column, the fifth of seven, high in the plot.
      final tuesday = Offset(box.right - box.width * 0.36, box.top + 40);
      await mouse.moveTo(tuesday);
      await tester.pump();
      Finder on(String text) =>
          find.descendant(of: card, matching: find.text(text));
      expect(on('Tue, Oct 27'), findsOneWidget);
      expect(on(r'$42.10'), findsOneWidget);
      expect(on('1.4M'), findsOneWidget);
      expect(on('101'), findsOneWidget);
      // Right of and under the pointer, never over it.
      expect(tester.getRect(card).left, greaterThan(tuesday.dx));
      expect(tester.getRect(card).top, greaterThan(tuesday.dy));
      // The highest bar's own value gives way to the card.
      expect(
        find.descendant(of: chart, matching: find.text(r'$42.10')),
        findsOneWidget,
      );
      await render(tester, find.byType(MaterialApp), 'usage-hover-$theme');
      await expectLater(
        chart,
        matchesGoldenFile('goldens/usage_chart_hover_$theme.png'),
      );

      // It follows the pointer along the same day.
      final was = tester.getRect(card).topLeft;
      await mouse.moveTo(tuesday + const Offset(6, 10));
      await tester.pump();
      expect(tester.getRect(card).topLeft, was + const Offset(6, 10));

      // Today's, at the chart's edge and its foot: the card turns to the
      // pointer's left and stops at the foot, inside the chart.
      final today = Offset(box.right - 8, box.bottom - 30);
      await mouse.moveTo(today);
      await tester.pump();
      expect(on('Thu, Oct 29'), findsOneWidget);
      expect(tester.getRect(card).right, lessThan(today.dx));
      expect(tester.getRect(card).bottom, box.bottom);

      await mouse.moveTo(box.bottomRight + const Offset(0, 40));
      await tester.pump();
      expect(card, findsNothing);
      d.dispose();
    }, variant: onMac);
  }

  testWidgets('a day without a turn says nothing was used', (tester) async {
    final (_, d) = await _open(tester, quarterUsage());
    final box = tester.getRect(find.byType(UsageDayChart));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    // The default span is a week: five days back had no turn.
    await mouse.moveTo(Offset(box.right - box.width / 7 * 5.5, box.center.dy));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(UsageDayCard),
        matching: find.text('Nothing used'),
      ),
      findsOneWidget,
    );
    d.dispose();
  });

  testWidgets('limits: a row per window, the one near it unmistakable', (
    tester,
  ) async {
    final (_, d) = await _open(tester, busyUsage());
    expect(find.byKey(const ValueKey('usage-limits')), findsOneWidget);
    expect(find.text('Claude · 5-hour'), findsOneWidget);
    expect(find.text('Claude · Weekly'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('Near the limit'), findsOneWidget);
    expect(find.text('Within the limit'), findsOneWidget);
    // When it was seen, never shown as live.
    expect(find.textContaining('as of 12m ago'), findsNWidgets(2));
    expect(find.textContaining('Resets in 1h 05m'), findsOneWidget);
    d.dispose();
  });

  testWidgets('no limits reported: no Limits group at all', (tester) async {
    final (_, d) = await _open(tester, busyUsage()..limits.clear());
    expect(find.byKey(const ValueKey('usage-limits')), findsNothing);
    expect(find.text('Limits'), findsNothing);
    d.dispose();
  });

  testWidgets('no cost reported at all: tokens lead and no spend shows', (
    tester,
  ) async {
    final (_, d) = await _open(tester, noCostUsage());
    expect(find.byKey(const ValueKey('usage-spend')), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Ante and Codex report no cost'), findsOneWidget);
    expect(find.text('Tokens by day'), findsOneWidget);
    expect(find.text('Chats that used the most'), findsOneWidget);
    expect(find.text('11.4M'), findsOneWidget);
    d.dispose();
  });

  testWidgets('one agent with no cost is named on its own', (tester) async {
    final (_, d) = await _open(tester, busyUsage()..noCost.remove('ante'));
    expect(find.text('Codex reports no cost'), findsOneWidget);
    d.dispose();
  });

  testWidgets('nothing kept yet: one plain line, nothing else', (tester) async {
    final (_, d) = await _open(tester, emptyUsage());
    expect(
      find.text('Nothing yet: usage is counted from now, turn by turn'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('usage-limits')), findsNothing);
    expect(find.byKey(const ValueKey('usage-footnote')), findsNothing);
    expect(find.text('By agent'), findsNothing);
    d.dispose();
  });

  testWidgets('nothing in the span: it says so, and keeps the limits', (
    tester,
  ) async {
    final quiet = GetUsageResponse(
      earliest: msAgo(const Duration(days: 40)),
      limits: busyUsage().limits,
    );
    final (_, d) = await _open(tester, quiet);
    expect(find.text('Nothing used in the last 7 days'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-limits')), findsOneWidget);
    expect(find.text('Spend by day'), findsNothing);
    d.dispose();
  });

  testWidgets('the span asks again from its first day, and is remembered', (
    tester,
  ) async {
    final (fake, d) = await _open(tester, busyUsage());
    for (final (label, range, from) in [
      ('30 days', UsageRange.month, _int(DateTime(2026, 9, 30))),
      (
        '90 days',
        UsageRange.quarter,
        _int(DateTime(2026, 8, 2).subtract(const Duration(days: 1))),
      ),
      ('All', UsageRange.all, Int64.ZERO),
      ('7 days', UsageRange.week, _int(DateTime(2026, 10, 23))),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(_asked(fake).last, GetUsageRequest(from: from), reason: label);
      expect(usageRange.value, range);
      expect(tester.takeException(), isNull, reason: label);
    }
    expect(_asked(fake), hasLength(5));
    expect(readSaved()['usageRange'], 'week');
    d.dispose();
  });

  testWidgets('a span picked before opens next time', (tester) async {
    usageRange.value = UsageRange.quarter;
    final (fake, d) = await _open(tester, busyUsage());
    expect(
      _asked(fake).single,
      GetUsageRequest(
        from: _int(DateTime(2026, 8, 2).subtract(const Duration(days: 1))),
      ),
    );
    // 90 days are dated, every so many, and today named.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Oct 22'), findsOneWidget);
    d.dispose();
  });

  testWidgets('a chat in the list opens it and closes Settings', (
    tester,
  ) async {
    final (_, d) = await _open(tester, busyUsage());
    // A deleted chat's row, or one no longer here, opens nothing.
    expect(find.byKey(const ValueKey('usage-chat-gone')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('usage-chat-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('usage-chat-a')));
    await tester.pumpAndSettle();
    expect(d.selectedId, 'a');
    expect(d.settingsOpen, isNull);
    expect(find.text('closed'), findsOneWidget);
    d.dispose();
  });

  testWidgets('an older daemon: the page says it needs the restart', (
    tester,
  ) async {
    final (fake, d) = await _open(tester, busyUsage(), api: usageApi - 1);
    expect(find.byKey(const ValueKey('usage-old-daemon')), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-range')), findsNothing);
    expect(_asked(fake), isEmpty);
    d.dispose();
  });

  testWidgets('a failed ask says why and tries again', (tester) async {
    final fake = settingsFake()..usage = busyUsage();
    final inner = fake.answer!;
    var fail = true;
    fake.answer = (input) => input is GetUsageRequest && fail
        ? throw ConnectException(
            Code.failedPrecondition,
            'the database is locked',
          )
        : inner(input);
    final d = await fake.connect(tester);
    await pumpSettings(tester, d, SettingsSection.usage);
    expect(find.text("Couldn't read usage"), findsOneWidget);
    expect(find.textContaining('the database is locked'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't read usage"), findsNothing);
    expect(find.text(r'$145.80'), findsOneWidget);
    d.dispose();
  });

  testWidgets('narrowed to the modal at its least, nothing runs off', (
    tester,
  ) async {
    Daemon? d;
    Future<void> reopen() async {
      if (d case final open?) await closeView(tester, open);
      d = await pumpSettingsApp(
        tester,
        settingsFake()..usage = busyUsage(),
        SettingsSection.usage,
        size: const Size(1100, 900),
      );
    }

    await reopen();
    await narrowing(
      tester,
      from: 1100,
      to: 720,
      check: (w) {
        expect(tester.takeException(), isNull, reason: '$w');
        // The page's own text stays inside it at every width. (Not the
        // window's: the Close button's glyph lags a resize by a frame, in
        // any section, and the composer behind the modal is its own.)
        final page = tester.getRect(find.byType(UsageSection));
        for (final e
            in find
                .descendant(
                  of: find.byType(UsageSection),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final box = e.renderObject! as RenderBox;
          final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
          if (right.isNaN) continue;
          expect(right, lessThanOrEqualTo(page.right + 0.5), reason: '$w');
        }
      },
      reopen: reopen,
    );
    await closeView(tester, d!);
  }, variant: onMac);

  testWidgets("Settings alone at the modal's narrowest: all text inside", (
    tester,
  ) async {
    // The page as wide as the modal leaves it in a 720 window.
    final (_, d) = await _open(
      tester,
      busyUsage(),
      size: const Size(640, 2400),
    );
    expect(tester.takeException(), isNull);
    expectTextInside(tester, 640);
    d.dispose();
  });

  for (final (tokens, theme) in [
    (Tokens.dark, 'dark'),
    (Tokens.light, 'light'),
  ]) {
    for (final (name, usage, height) in [
      ('busy', busyUsage, 1700.0),
      ('nocost', noCostUsage, 1250.0),
      ('empty', emptyUsage, 300.0),
    ]) {
      testWidgets('the page, $name, $theme', (tester) async {
        final (_, d) = await _open(
          tester,
          usage(),
          size: Size(1000, height),
          tokens: tokens,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/usage_${name}_$theme.png'),
        );
        d.dispose();
      }, variant: onMac);
    }
  }
}

/// [d] as GetUsage's from.
Int64 _int(DateTime d) => Int64(_ms(d));
