import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/usage_rows.dart';

import 'harness.dart';
import 'usage_fixtures.dart';

void main() {
  test("the cache's share of the input: a whole per cent, never 0% or "
      "100% when it isn't exactly so", () {
    String share({int input = 0, int read = 0, int written = 0}) =>
        cachedShare(usageTotals(input: input, read: read, written: written));
    expect(share(input: 5800000, read: 95100000, written: 1200000), '93%');
    expect(share(input: 1000, read: 3000), '75%');
    expect(share(input: 100000, read: 10), 'under 1%');
    expect(share(input: 10, read: 100000), 'over 99%');
    expect(share(read: 100000), '100%');
    expect(share(input: 100, written: 50), '0%');
  });

  // The made-up weeks the goldens and renders show add up, as the
  // daemon's would: each breakdown and the days sum to the totals (turns
  // by agent and by day; models and projects carry none).
  for (final (name, usage) in [
    ('busy', busyUsage),
    ('cached', cachedUsage),
    ('nocost', noCostUsage),
    ('two-currency', twoCurrencyUsage),
  ]) {
    test('the $name fixture adds up', () {
      final r = usage();
      String sum(List<UsageGroup> groups, {required bool turns}) {
        var (input, output, read, written, n) = (0, 0, 0, 0, 0);
        final cost = <String, int>{};
        for (final g in groups) {
          final t = g.totals;
          input += t.inputTokens.toInt();
          output += t.outputTokens.toInt();
          read += t.cacheReadTokens.toInt();
          written += t.cacheWriteTokens.toInt();
          n += t.turns.toInt();
          for (final c in t.cost) {
            cost[c.currency] =
                (cost[c.currency] ?? 0) + (c.amount * 100).round();
          }
        }
        return '$input in, $output out, $read read, $written written, '
            '${turns ? n : '-'} turns, $cost';
      }

      final want = sum([UsageGroup(totals: r.totals)], turns: true);
      final wantNoTurns = sum([UsageGroup(totals: r.totals)], turns: false);
      expect(sum(r.days, turns: true), want, reason: 'days');
      expect(sum(r.agents, turns: true), want, reason: 'agents');
      expect(sum(r.models, turns: false), wantNoTurns, reason: 'models');
      expect(sum(r.folders, turns: false), wantNoTurns, reason: 'folders');
    });
  }

  test('a cost shows as the agent reports it, and 0 shows nothing', () {
    expect(cost(Usage(cost: 0.19, currency: 'USD')), r'$0.19');
    expect(cost(Usage(cost: 1.5, currency: 'EUR')), '1.50 EUR');
    expect(cost(Usage(cost: 0, currency: 'USD')), '');
    expect(cost(Usage(cost: 0.19)), '');
  });

  test('what /context lists says how full it is, without the free space, '
      'the buffer or the deferred', () {
    ContextCategory c(
      String name,
      int tokens, {
      String kind = '',
      String part = '',
    }) => ContextCategory(
      name: name,
      tokens: Int64(tokens),
      kind: kind,
      part: part,
    );
    expect(
      breakdownFill([
        c('System prompt', 5000),
        c('Messages', 100000, part: 'messages'),
        c('Tools', 327000, kind: 'deferred'),
        // Named as no agent names it: its part says it's the buffer.
        c('Reserve', 45000, part: 'buffer'),
        c('Free space', 850000, kind: 'free'),
      ]),
      closeTo(105000 / 1000000, 1e-9),
    );
    expect(breakdownFill([]), isNull);
  });

  testWidgets('the meter: a percentage from the usage, else from /context, '
      'else nothing', (tester) async {
    Future<void> show(ContextMeter m) =>
        tester.pumpWidget(themed(Center(child: m)));
    await show(
      ContextMeter(
        Usage(contextUsed: Int64(105100), contextSize: Int64(1000000)),
      ),
    );
    expect(find.text('11%'), findsOneWidget);
    await show(
      ContextMeter(
        Usage(),
        breakdown: GetContextUsageResponse(
          categories: [
            ContextCategory(name: 'Messages', tokens: Int64(30000)),
            ContextCategory(
              name: 'Free space',
              tokens: Int64(70000),
              kind: 'free',
            ),
          ],
        ),
      ),
    );
    expect(find.text('30%'), findsOneWidget);
    await show(ContextMeter(Usage()));
    expect(find.byType(Text), findsNothing);
  });
}
