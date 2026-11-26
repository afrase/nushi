import 'package:fixnum/fixnum.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage_range.dart';

import 'harness.dart';

// Made-up usage for Settings › Usage's tests and renders (ADR 0136): the
// demo's imaginary lumen projects, invented chats.

/// Turns summed: [usd] dollars (none when null), tokens in and out, the
/// cache's, and how many turns.
UsageTotals usageTotals({
  double? usd,
  int input = 0,
  int output = 0,
  int read = 0,
  int written = 0,
  int turns = 0,
}) => UsageTotals(
  cost: [if (usd != null) UsageCost(currency: 'USD', amount: usd)],
  inputTokens: Int64(input),
  outputTokens: Int64(output),
  cacheReadTokens: Int64(read),
  cacheWriteTokens: Int64(written),
  turns: Int64(turns),
);

/// [fixtureNow]'s day less [back] days, as the daemon keys it.
String usageDay(int back) =>
    dayKey(DateTime(fixtureNow.year, fixtureNow.month, fixtureNow.day - back));

/// A busy week: Claude, PiG and OpenCode report a cost, Codex and Ante
/// none; Claude's two limits, the 5-hour one near it.
GetUsageResponse busyUsage() => GetUsageResponse(
  totals: usageTotals(
    usd: 145.80,
    input: 4120000,
    output: 1630000,
    read: 18300000,
    written: 2100000,
    turns: 412,
  ),
  // Each day's spend, tokens in and out, cache read and written, and
  // turns: they add up to the week's.
  days: [
    for (final (back, usd, input, output, read, written, turns) in [
      (6, 18.20, 457500, 152500, 1830000, 300000, 43),
      (5, 5.10, 105000, 35000, 420000, 0, 10),
      (4, 1.20, 22500, 7500, 90000, 0, 2),
      (3, 29.40, 735000, 245000, 2940000, 500000, 70),
      (2, 42.10, 1065000, 355000, 4260000, 600000, 101),
      (1, 37.40, 945000, 315000, 3780000, 400000, 90),
      (0, 12.40, 790000, 520000, 4980000, 300000, 96),
    ])
      UsageGroup(
        key: usageDay(back),
        totals: usageTotals(
          usd: usd,
          input: input,
          output: output,
          read: read,
          written: written,
          turns: turns,
        ),
      ),
  ],
  agents: [
    UsageGroup(
      key: 'ante',
      totals: usageTotals(input: 520000, output: 180000, turns: 31),
    ),
    UsageGroup(
      key: 'claude',
      totals: usageTotals(
        usd: 112.60,
        input: 2510000,
        output: 980000,
        read: 16900000,
        written: 2100000,
        turns: 228,
      ),
    ),
    UsageGroup(
      key: 'codex',
      totals: usageTotals(
        input: 610000,
        output: 240000,
        read: 1400000,
        turns: 74,
      ),
    ),
    UsageGroup(
      key: 'opencode',
      totals: usageTotals(usd: 11.90, input: 180000, output: 90000, turns: 22),
    ),
    UsageGroup(
      key: 'pig',
      totals: usageTotals(usd: 21.30, input: 300000, output: 140000, turns: 57),
    ),
  ],
  models: [
    UsageGroup(
      key: '',
      totals: usageTotals(input: 90000, output: 30000, turns: 6),
    ),
    UsageGroup(
      key: 'big-model',
      totals: usageTotals(
        usd: 98.10,
        input: 1900000,
        output: 700000,
        read: 16900000,
        written: 2100000,
      ),
    ),
    UsageGroup(
      key: 'quick-model',
      totals: usageTotals(usd: 47.70, input: 1500000, output: 610000),
    ),
    UsageGroup(
      key: 'coder-large',
      totals: usageTotals(input: 630000, output: 290000, read: 1400000),
    ),
  ],
  folders: [
    UsageGroup(
      key: '',
      totals: usageTotals(usd: 3.20, input: 60000, output: 20000),
    ),
    UsageGroup(
      key: '/Users/me/src/lumen',
      totals: usageTotals(
        usd: 101.40,
        input: 2900000,
        output: 1100000,
        read: 13000000,
        written: 1500000,
      ),
    ),
    UsageGroup(
      key: '/Users/me/src/lumen-docs',
      totals: usageTotals(
        usd: 41.20,
        input: 1160000,
        output: 510000,
        read: 5300000,
        written: 600000,
      ),
    ),
  ],
  chats: [
    UsageChat(
      chatId: 'a',
      title: 'Fix the login redirect',
      agent: 'claude',
      totals: usageTotals(
        usd: 38.20,
        input: 820000,
        output: 310000,
        read: 6200000,
      ),
    ),
    UsageChat(
      chatId: 'gone',
      agent: 'claude',
      totals: usageTotals(usd: 22.75, input: 540000, output: 160000),
    ),
    UsageChat(
      chatId: 'c',
      title: 'Release notes',
      agent: 'pig',
      totals: usageTotals(usd: 14.10, input: 210000, output: 90000),
    ),
    UsageChat(
      chatId: 'b',
      title: 'Bump the API version',
      agent: 'codex',
      totals: usageTotals(input: 610000, output: 240000),
    ),
  ],
  noCost: ['ante', 'codex'],
  earliest: msAgo(const Duration(days: 23)),
  limits: [
    UsageLimit(
      agent: 'claude',
      kind: 'five_hour',
      status: 'allowed_warning',
      utilization: 0.86,
      resetsAt: Int64(
        fixtureNow
            .add(const Duration(hours: 1, minutes: 5))
            .millisecondsSinceEpoch,
      ),
      seen: msAgo(const Duration(minutes: 12)),
    ),
    UsageLimit(
      agent: 'claude',
      kind: 'seven_day',
      status: 'allowed',
      utilization: 0.64,
      resetsAt: Int64(
        fixtureNow.add(const Duration(days: 4)).millisecondsSinceEpoch,
      ),
      seen: msAgo(const Duration(minutes: 12)),
    ),
  ],
);

/// [busyUsage] with PiG's turns in Release notes also spending 2.00 EUR:
/// two currencies, each written as the agent reported it.
GetUsageResponse twoCurrencyUsage() {
  final r = busyUsage();
  final euros = UsageCost(currency: 'EUR', amount: 2);
  for (final t in [
    r.totals,
    r.days.firstWhere((d) => d.key == usageDay(1)).totals,
    r.agents.firstWhere((g) => g.key == 'pig').totals,
    r.models.firstWhere((g) => g.key == 'quick-model').totals,
    r.folders.firstWhere((g) => g.key == '/Users/me/src/lumen-docs').totals,
    r.chats.firstWhere((c) => c.chatId == 'c').totals,
  ]) {
    t.cost.add(euros);
  }
  return r;
}

/// The first day: nothing kept yet.
GetUsageResponse emptyUsage() => GetUsageResponse();

/// A week on Codex and Ante alone, which report no cost.
GetUsageResponse noCostUsage() => GetUsageResponse(
  totals: usageTotals(
    input: 8100000,
    output: 3300000,
    read: 41000000,
    turns: 268,
  ),
  // Each day's tokens in and out, cache read, and turns: they add up to
  // the week's.
  days: [
    for (final (back, input, output, read, turns) in [
      (6, 980000, 420000, 5000000, 33),
      (5, 140000, 60000, 700000, 5),
      (3, 1820000, 780000, 9400000, 61),
      (2, 2310000, 990000, 11900000, 78),
      (1, 2030000, 870000, 10400000, 68),
      (0, 820000, 180000, 3600000, 23),
    ])
      UsageGroup(
        key: usageDay(back),
        totals: usageTotals(
          input: input,
          output: output,
          read: read,
          turns: turns,
        ),
      ),
  ],
  agents: [
    UsageGroup(
      key: 'ante',
      totals: usageTotals(
        input: 1600000,
        output: 700000,
        read: 8000000,
        turns: 61,
      ),
    ),
    UsageGroup(
      key: 'codex',
      totals: usageTotals(
        input: 6500000,
        output: 2600000,
        read: 33000000,
        turns: 207,
      ),
    ),
  ],
  models: [
    UsageGroup(
      key: 'coder-large',
      totals: usageTotals(input: 6500000, output: 2600000, read: 33000000),
    ),
    UsageGroup(
      key: 'open-model',
      totals: usageTotals(input: 1600000, output: 700000, read: 8000000),
    ),
  ],
  folders: [
    UsageGroup(
      key: '/Users/me/src/lumen',
      totals: usageTotals(input: 5300000, output: 2300000, read: 30000000),
    ),
    UsageGroup(
      key: '/Users/me/src/lumen-docs',
      totals: usageTotals(input: 2800000, output: 1000000, read: 11000000),
    ),
  ],
  chats: [
    UsageChat(
      chatId: 'b',
      title: 'Bump the API version',
      agent: 'codex',
      totals: usageTotals(input: 2100000, output: 900000, read: 9000000),
    ),
    UsageChat(
      chatId: 'x',
      title: 'Translate the CLI messages',
      agent: 'ante',
      totals: usageTotals(input: 900000, output: 300000),
    ),
  ],
  noCost: ['ante', 'codex'],
  earliest: msAgo(const Duration(days: 9)),
);

/// [busyUsage] over 90 days: a day's spend rises and falls by the week,
/// weekends quiet, a few days without a turn.
GetUsageResponse quarterUsage() => busyUsage()
  ..days.clear()
  ..days.addAll([
    for (var back = 89; back >= 0; back--)
      if (back % 13 != 5)
        UsageGroup(
          key: usageDay(back),
          totals: usageTotals(
            usd: (back % 7 < 2 ? 2 : 14) + (back * 37 % 23).toDouble(),
            input: 400000 + back * 9000,
            output: 120000 + back * 3000,
            turns: 20 + back % 30,
          ),
        ),
  ]);

/// A week where the cache does most of the work: Claude with a big share
/// read back (4.2M tokens, 85.7M cached), Codex with some, Ante and PiG
/// with none; a cost from Claude and PiG, none from Ante and Codex; a
/// project with a long name.
GetUsageResponse cachedUsage() => GetUsageResponse(
  totals: usageTotals(
    usd: 47.30,
    input: 5800000,
    output: 2050000,
    read: 95100000,
    written: 1200000,
    turns: 268,
  ),
  // Each day's spend, tokens in and out, cache read and written, and
  // turns: they add up to the week's.
  days: [
    for (final (back, usd, input, output, read, written, turns) in [
      (6, 6.20, 675000, 225000, 11200000, 200000, 30),
      (5, 2.10, 300000, 100000, 4100000, 0, 13),
      (3, 9.40, 1200000, 400000, 19800000, 300000, 53),
      (2, 12.80, 1575000, 525000, 26300000, 400000, 70),
      (1, 11.10, 1462500, 487500, 24900000, 300000, 65),
      (0, 5.70, 587500, 312500, 8800000, 0, 37),
    ])
      UsageGroup(
        key: usageDay(back),
        totals: usageTotals(
          usd: usd,
          input: input,
          output: output,
          read: read,
          written: written,
          turns: turns,
        ),
      ),
  ],
  agents: [
    UsageGroup(
      key: 'claude',
      totals: usageTotals(
        usd: 41.20,
        input: 3100000,
        output: 1100000,
        read: 85700000,
        written: 1200000,
        turns: 180,
      ),
    ),
    UsageGroup(
      key: 'codex',
      totals: usageTotals(
        input: 1800000,
        output: 600000,
        read: 9400000,
        turns: 64,
      ),
    ),
    UsageGroup(
      key: 'ante',
      totals: usageTotals(input: 400000, output: 150000, turns: 12),
    ),
    UsageGroup(
      key: 'pig',
      totals: usageTotals(usd: 6.10, input: 500000, output: 200000, turns: 12),
    ),
  ],
  models: [
    UsageGroup(
      key: 'big-model',
      totals: usageTotals(
        usd: 41.20,
        input: 3100000,
        output: 1100000,
        read: 85700000,
        written: 1200000,
      ),
    ),
    UsageGroup(
      key: 'coder-large',
      totals: usageTotals(input: 1800000, output: 600000, read: 9400000),
    ),
    UsageGroup(
      key: 'quick-model',
      totals: usageTotals(usd: 6.10, input: 500000, output: 200000),
    ),
    UsageGroup(
      key: 'open-model',
      totals: usageTotals(input: 400000, output: 150000),
    ),
  ],
  folders: [
    UsageGroup(
      key: '/Users/me/src/lumen',
      totals: usageTotals(
        usd: 33.90,
        input: 2600000,
        output: 900000,
        read: 70100000,
        written: 900000,
      ),
    ),
    UsageGroup(
      key: '/Users/me/src/lumen-reading-room-companion-for-the-desktop',
      totals: usageTotals(
        usd: 13.40,
        input: 2900000,
        output: 1000000,
        read: 25000000,
        written: 300000,
      ),
    ),
    UsageGroup(key: '', totals: usageTotals(input: 300000, output: 150000)),
  ],
  chats: [
    UsageChat(
      chatId: 'a',
      title: 'Fix the login redirect',
      agent: 'claude',
      totals: usageTotals(
        usd: 18.40,
        input: 1300000,
        output: 500000,
        read: 38200000,
      ),
    ),
    UsageChat(
      chatId: 'c',
      title: 'Release notes',
      agent: 'pig',
      totals: usageTotals(usd: 6.10, input: 500000, output: 200000),
    ),
    UsageChat(
      chatId: 'b',
      title: 'Bump the API version',
      agent: 'codex',
      totals: usageTotals(input: 900000, output: 300000, read: 5100000),
    ),
  ],
  noCost: ['ante', 'codex'],
  earliest: msAgo(const Duration(days: 12)),
);
