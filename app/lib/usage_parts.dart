import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/usage_rows.dart';

// Settings › Usage's parts above and below its breakdowns (ADR 0136): the
// totals, a muted line in a card, and the small print.

/// A line in a group's card, muted: an empty state or why there's nothing.
class UsageNote extends StatelessWidget {
  const new(this.words, {super.key});

  final String words;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Text(words, style: theme.ui(theme.t.textMuted)),
        ),
      ],
    );
  }
}

/// The span's totals: what was spent (in each currency), the tokens in
/// and out, the turns, and the cache's own figures apart. With no cost
/// reported at all the tokens lead and no spend shows; the agents that
/// reported none are named beside it either way.
class UsageTotalsCard extends StatelessWidget {
  const new(this.r, this.measure, {super.key});

  final GetUsageResponse r;
  final UsageMeasure measure;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final u = r.totals;
    final none = r.noCost.isEmpty
        ? null
        : '${andList(r.noCost.map(agentTitle))} '
              '${r.noCost.length == 1 ? 'reports' : 'report'} no cost';
    final turns = u.turns.toInt();
    final cache = [
      if (u.cacheReadTokens > 0) '${tokens(u.cacheReadTokens.toInt())} read',
      if (u.cacheWriteTokens > 0)
        '${tokens(u.cacheWriteTokens.toInt())} written',
    ];
    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  if (measure.costs)
                    Expanded(
                      child: _Figure(
                        'Spend',
                        spendOf(u),
                        key: const ValueKey('usage-spend'),
                        sub: none,
                      ),
                    ),
                  Expanded(
                    child: _Figure(
                      'Tokens',
                      tokens(tokensOf(u)),
                      key: const ValueKey('usage-tokens'),
                      sub: measure.costs
                          ? '${tokens(u.inputTokens.toInt())} in · '
                                '${tokens(u.outputTokens.toInt())} out'
                          : none,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      'Turns',
                      '$turns',
                      key: const ValueKey('usage-turns'),
                    ),
                  ),
                ],
              ),
              if (cache.isNotEmpty)
                Text(
                  'Cache: ${cache.join(' · ')}, apart from the tokens',
                  key: const ValueKey('usage-cache'),
                  style: tabular(theme.ui(t.textMuted, size: 12)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A headline figure: its label, the value large, a muted line under it.
class _Figure extends StatelessWidget {
  const new(this.label, this.value, {super.key, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: tabular(theme.ui(t.text, size: 20, weight: FontWeight.w600)),
          ),
        ),
        if (sub case final s?)
          Text(s, maxLines: 2, style: theme.ui(t.textMuted, size: 12)),
      ],
    );
  }
}

/// What the figures are and aren't, in small print under them.
class UsageFootnote extends StatelessWidget {
  const new(this.earliest, {required this.costs, super.key});

  /// When the first turn kept ended.
  final DateTime earliest;

  /// Whether a cost was reported: then what spend is, said first.
  final bool costs;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final since =
        '${months[earliest.month - 1].substring(0, 3)} ${earliest.day}, '
        '${earliest.year}';
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        '${costs ? 'Spend is what the agent reports, which on a subscription '
                  'is what the API would charge. ' : ''}'
        'Usage is counted from $since, the first turn this version kept; '
        'turns Nushi runs out of sight (a context check, a workflow’s '
        'agents) aren’t counted.',
        key: const ValueKey('usage-footnote'),
        style: theme.ui(theme.t.textMuted, size: 12),
      ),
    );
  }
}
