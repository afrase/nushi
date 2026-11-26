import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage_chart.dart';
import 'package:nushi/usage_page.dart';
import 'package:nushi/usage_range.dart';
import 'package:nushi/usage_rows.dart';

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
    // The cache read back is a figure of its own, its share of the input
    // under it; the old line apart from the tokens is gone.
    expect(find.text('4.1M in, 1.6M out'), findsOneWidget);
    Finder inCached(String text) => find.descendant(
      of: find.byKey(const ValueKey('usage-cached')),
      matching: find.text(text),
    );
    expect(inCached('18.3M'), findsOneWidget);
    expect(inCached('75% of all input, 2.1M written'), findsOneWidget);
    expect(find.textContaining('Cache: '), findsNothing);
    // Spend, tokens, cached, turns: in that order, side by side.
    final order = [
      'usage-spend',
      'usage-tokens',
      'usage-cached',
      'usage-turns',
    ].map((k) => tester.getRect(find.byKey(ValueKey(k))));
    for (final (a, b)
        in order.indexed
            .skip(1)
            .map((e) => (order.elementAt(e.$1 - 1), e.$2))) {
      expect(b.left, greaterThanOrEqualTo(a.right));
      expect(b.top, a.top);
    }
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
    expect(
      find.textContaining(
        'Cached is what the agent read back from its cache, apart from the '
        'tokens.',
      ),
      findsOneWidget,
    );
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

      // Tuesday's column, the fifth of seven, high in the plot: 24 from
      // the top (it was 40) so the card, taller by its Cached line, still
      // fits under the pointer. Lower, it meets the chart's foot and rises
      // beside the pointer, still never over it (as Today's below).
      final tuesday = Offset(box.right - box.width * 0.36, box.top + 24);
      await mouse.moveTo(tuesday);
      await tester.pump();
      Finder on(String text) =>
          find.descendant(of: card, matching: find.text(text));
      expect(on('Tue, Oct 27'), findsOneWidget);
      expect(on(r'$42.10'), findsOneWidget);
      expect(on('1.4M'), findsOneWidget);
      expect(on('101'), findsOneWidget);
      expect(on('Cached'), findsOneWidget);
      expect(on('4.3M'), findsOneWidget);
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

  testWidgets('nothing read from or written to the cache: no Cached '
      'figure and no Cached column', (tester) async {
    final quiet = busyUsage();
    quiet.totals
      ..cacheReadTokens = Int64.ZERO
      ..cacheWriteTokens = Int64.ZERO;
    for (final g in [...quiet.agents, ...quiet.models, ...quiet.folders]) {
      g.totals.cacheReadTokens = Int64.ZERO;
    }
    final (_, d) = await _open(tester, quiet);
    expect(find.byKey(const ValueKey('usage-cached')), findsNothing);
    expect(find.text('Cached'), findsNothing);
    expect(find.byKey(const ValueKey('usage-cached-cell')), findsNothing);
    expect(find.textContaining('Cached is what the agent'), findsNothing);
    d.dispose();
  });

  testWidgets('written to the cache but nothing read: the figure says so', (
    tester,
  ) async {
    final some = busyUsage();
    some.totals.cacheReadTokens = Int64.ZERO;
    final (_, d) = await _open(tester, some);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('usage-cached')),
        matching: find.text('0% of all input, 2.1M written'),
      ),
      findsOneWidget,
    );
    // And the small print says what Cached is.
    expect(find.textContaining('Cached is what the agent'), findsOneWidget);
    d.dispose();
  });

  testWidgets('every breakdown ends in a Cached column, its figures under '
      'its name, blank where a row read nothing', (tester) async {
    final (_, d) = await _open(tester, cachedUsage());
    final heads = find.descendant(
      of: find.byType(UsageColumnsHead),
      matching: find.text('Cached'),
    );
    // By agent, model and project, and the chats.
    expect(heads, findsNWidgets(4));
    final right = tester.getRect(heads.first).right;
    for (final h in heads.evaluate()) {
      expect(tester.getRect(find.byWidget(h.widget)).right, right);
    }
    final cells = find.byKey(const ValueKey('usage-cached-cell'));
    // 4 agents, 4 models, 3 folders, 3 chats.
    expect(cells, findsNWidgets(14));
    for (final c in cells.evaluate()) {
      final box = tester.getRect(find.byWidget(c.widget));
      expect(box.right, right);
    }
    Finder cellOf(String row) => find.descendant(
      of: find.ancestor(
        of: find.text(row),
        matching: find.byWidgetPredicate(
          (w) => w is UsageBarRow || w is UsageChatRow,
        ),
      ),
      matching: find.byKey(const ValueKey('usage-cached-cell')),
    );
    String said(String row) => switch (find
        .descendant(of: cellOf(row), matching: find.byType(Text))
        .evaluate()) {
      final e when e.isEmpty => '',
      final e => (e.single.widget as Text).data!,
    };
    expect(said('Claude'), '85.7M');
    expect(said('Codex'), '9.4M');
    expect(said('Ante'), ''); // blank: no dash, no 0
    expect(said('Release notes'), '');
    expect(said('Fix the login redirect'), '38.2M');
    expect(find.text('–'), findsNothing);
    expect(find.text('—'), findsNothing);
    d.dispose();
  });

  testWidgets('a group none of whose rows read from the cache has no '
      'Cached column', (tester) async {
    final some = busyUsage();
    for (final f in some.folders) {
      f.totals.cacheReadTokens = Int64.ZERO;
    }
    final (_, d) = await _open(tester, some);
    final heads = find.descendant(
      of: find.byType(UsageColumnsHead),
      matching: find.text('Cached'),
    );
    expect(heads, findsNWidgets(3));
    final projects = find.ancestor(
      of: find.text('By project'),
      matching: find.byType(SettingsGroup),
    );
    expect(
      find.descendant(of: projects, matching: find.text('Cached')),
      findsNothing,
    );
    d.dispose();
  });

  testWidgets('no dot or dash between words anywhere on the page', (
    tester,
  ) async {
    final twins = busyUsage()
      ..folders.add(
        UsageGroup(
          key: '/Users/me/work/lumen',
          totals: usageTotals(usd: 1, input: 1000, output: 1000),
        ),
      );
    final (_, d) = await _open(tester, twins);
    for (final e
        in find
            .descendant(
              of: find.byType(UsageSection),
              matching: find.byType(RichText),
            )
            .evaluate()) {
      final text = (e.widget as RichText).text.toPlainText();
      expect(text, isNot(contains('·')), reason: text);
      expect(text, isNot(contains(' — ')), reason: text);
      expect(text, isNot(contains(' – ')), reason: text);
    }
    expect(find.text('Claude 5-hour'), findsOneWidget);
    // A twin project: its parent's name after its own, muted, with no
    // separator.
    final twin = find.byWidgetPredicate(
      (w) => w is Text && w.textSpan?.toPlainText() == 'lumen work',
    );
    expect(twin, findsOneWidget);
    final spans = (tester.widget<Text>(twin).textSpan! as TextSpan).children!;
    expect([for (final s in spans) (s as TextSpan).text], ['lumen', ' work']);
    final t = NushiTheme.of(tester.element(twin)).t;
    expect((spans.last as TextSpan).style?.color, t.textMuted);
    d.dispose();
  });

  testWidgets('several currencies: each as reported, a comma between', (
    tester,
  ) async {
    final (_, d) = await _open(tester, twoCurrencyUsage());
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('usage-spend')),
        matching: find.text(r'$145.80, 2.00 EUR'),
      ),
      findsOneWidget,
    );
    final pig = find.ancestor(
      of: find.text('PiG'),
      matching: find.byType(UsageBarRow),
    );
    expect(
      find.descendant(of: pig, matching: find.text(r'$21.30, 2.00 EUR')),
      findsOneWidget,
    );
    await render(tester, find.byType(MaterialApp), 'usage-two-currency');
    d.dispose();
  });

  testWidgets('limits: a row per window, the one near it unmistakable', (
    tester,
  ) async {
    final (_, d) = await _open(tester, busyUsage());
    expect(find.byKey(const ValueKey('usage-limits')), findsOneWidget);
    expect(find.text('Claude 5-hour'), findsOneWidget);
    expect(find.text('Claude Weekly'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('Near the limit'), findsOneWidget);
    expect(find.text('Within the limit'), findsOneWidget);
    // When it was seen, never shown as live.
    expect(find.text('as of 12m ago'), findsNWidgets(2));
    // When it was seen on a line of its own under the reset, apart from
    // the commas of a date.
    final resets = tester.getRect(find.text('Resets in 1h 05m'));
    final seen = tester.getRect(find.text('as of 12m ago').first);
    expect(seen.top, greaterThanOrEqualTo(resets.bottom));
    expect(seen.left, resets.left);
    expect(find.text('Resets Nov 2, 2026, 12:00 PM'), findsOneWidget);
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
    var fail = true;
    fake.on(
      (input) => input is GetUsageRequest && fail
          ? throw ConnectException(
              Code.failedPrecondition,
              'the database is locked',
            )
          : null,
    );
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

  // Walked twice, at the page's top and at its foot: a 900 tall window
  // builds only some of the rows, and each label is checked where built.
  for (final foot in [false, true]) {
    testWidgets('narrowed to the modal at its least, nothing runs off, '
        '${foot ? 'at the foot' : 'at the top'}', (tester) async {
      Daemon? d;
      Future<void> reopen() async {
        if (d case final open?) await closeView(tester, open);
        d = await pumpSettingsApp(
          tester,
          settingsFake()..usage = cachedUsage(),
          SettingsSection.usage,
          size: const Size(1100, 900),
        );
        if (foot) {
          await tester.drag(
            find
                .descendant(
                  of: find.byType(UsageSection),
                  matching: find.byType(Scrollable),
                )
                .first,
            const Offset(0, -5000),
          );
          await tester.pumpAndSettle();
        }
      }

      await reopen();
      await narrowing(
        tester,
        from: 1100,
        to: 720,
        check: (w) {
          expect(tester.takeException(), isNull, reason: '$w');
          // The page's own text stays inside it at every width. (Not the
          // window's: the Close button's glyph lags a resize by a frame,
          // in any section, and the composer behind the modal is its
          // own.)
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
          if (!foot) {
            // Four across at the widest, two by two at the narrowest.
            if (w == 1100) _expectFiguresAcross(tester, '$w');
            if (w == 720) _expectFiguresTwoByTwo(tester, '$w');
          }
          _expectLabelsKeepRoom(
            tester,
            '$w',
            built: foot ? ['Release notes'] : ['Claude', 'big-model'],
          );
        },
        reopen: reopen,
      );
      await closeView(tester, d!);
    }, variant: onMac);
  }

  testWidgets('a 720 window: a long Cached line is never cut, the figures '
      'two to a row', (tester) async {
    final long = noCostUsage();
    long.totals
      ..inputTokens = Int64(900000000)
      ..cacheReadTokens = Int64(1000000)
      ..cacheWriteTokens = Int64(123400000);
    final d = await pumpSettingsApp(
      tester,
      settingsFake()..usage = long,
      SettingsSection.usage,
      size: const Size(720, 900),
    );
    final line = find.descendant(
      of: find.byKey(const ValueKey('usage-cached')),
      matching: find.text('under 1% of all input, 123M written'),
    );
    expect(line, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(line);
    expect(paragraph.didExceedMaxLines, isFalse);
    // Three figures too narrow for a row of three go two to a row.
    final tokens = tester.getRect(find.byKey(const ValueKey('usage-tokens')));
    final cached = tester.getRect(find.byKey(const ValueKey('usage-cached')));
    final turns = tester.getRect(find.byKey(const ValueKey('usage-turns')));
    expect(cached.top, tokens.top);
    expect(turns.top, greaterThan(tokens.bottom));
    expect(turns.left, tokens.left);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets("a chat's title at the modal's narrowest: one line, cut "
      'with an ellipsis, the whole title under the pointer', (tester) async {
    final (_, d) = await _open(
      tester,
      cachedUsage(),
      size: const Size(640, 2400),
    );
    final title = find.descendant(
      of: find.byType(UsageChatRow),
      matching: find.text('Fix the login redirect'),
    );
    final text = tester.widget<Text>(title);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    // One line high, as a project's row is.
    final line = tester.getSize(title).height;
    final project = find.descendant(
      of: find.byType(UsageBarRow),
      matching: find.text('lumen'),
    );
    expect(line, tester.getSize(project).height);
    expect(
      find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Fix the login redirect',
        ),
      ),
      findsOneWidget,
    );
    d.dispose();
  });

  testWidgets("Settings alone at the modal's narrowest: all text inside", (
    tester,
  ) async {
    // The page as wide as the modal leaves it in a 720 window.
    final (_, d) = await _open(
      tester,
      cachedUsage(),
      size: const Size(640, 2400),
    );
    expect(tester.takeException(), isNull);
    expectTextInside(tester, 640);
    _expectFiguresTwoByTwo(tester, '640');
    _expectLabelsKeepRoom(
      tester,
      '640',
      built: ['Claude', 'big-model', 'lumen', 'Release notes'],
    );
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

/// The totals card's figure keyed [k].
Rect _figure(WidgetTester tester, String k) =>
    tester.getRect(find.byKey(ValueKey('usage-$k')));

/// The totals card's four figures in one row: all share a top.
void _expectFiguresAcross(WidgetTester tester, String reason) {
  final top = _figure(tester, 'spend').top;
  for (final k in ['tokens', 'cached', 'turns']) {
    expect(_figure(tester, k).top, top, reason: '$reason: $k');
  }
}

/// The totals card's four figures two to a row: Cached under Spend, in
/// its column.
void _expectFiguresTwoByTwo(WidgetTester tester, String reason) {
  final spend = _figure(tester, 'spend');
  final cached = _figure(tester, 'cached');
  expect(cached.top, greaterThan(spend.bottom), reason: reason);
  expect(cached.left, spend.left, reason: reason);
}

/// Every breakdown's and chat's label built keeps room for some of its
/// words beside the columns: the columns never push a label to nothing.
/// Only the page's own rows: the sidebar has a chat of the same name.
/// Those [built] must be there to measure.
void _expectLabelsKeepRoom(
  WidgetTester tester,
  String reason, {
  required List<String> built,
}) {
  final rows = find.byWidgetPredicate(
    (w) => w is UsageBarRow || w is UsageChatRow,
    skipOffstage: false,
  );
  for (final label in ['Claude', 'big-model', 'lumen', 'Release notes']) {
    final found = find.descendant(
      of: rows,
      matching: find.text(label, skipOffstage: false),
      skipOffstage: false,
    );
    if (found.evaluate().isEmpty) {
      expect(built, isNot(contains(label)), reason: '$reason: $label');
      continue; // not built at this height
    }
    final box = tester.getRect(found.first);
    expect(box.width, greaterThan(40), reason: '$reason: $label');
  }
}

/// [d] as GetUsage's from.
Int64 _int(DateTime d) => Int64(_ms(d));
