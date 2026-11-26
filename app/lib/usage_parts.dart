import 'dart:math';

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
/// and out, what was read back from the cache (its share of the input,
/// and what was written to it), and the turns. With no cost reported at
/// all the tokens lead and no spend shows; the agents that reported none
/// are named on a line of their own under the figures, either way. Too
/// narrow for them side by side, the figures go two to a row.
class UsageTotalsCard extends StatelessWidget {
  const new(this.r, this.measure, {super.key});

  final GetUsageResponse r;
  final UsageMeasure measure;

  /// The least a figure takes beside the others, whatever its small line.
  static const figureRoom = 100.0;

  /// Between figures, across and down.
  static const _gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final u = r.totals;
    final none = r.noCost.isEmpty
        ? null
        : '${andList(r.noCost.map(agentTitle))} '
              '${r.noCost.length == 1 ? 'reports' : 'report'} no cost';
    final read = u.cacheReadTokens.toInt();
    final written = u.cacheWriteTokens.toInt();
    final figures = [
      if (measure.costs)
        _Figure('Spend', spendOf(u), key: const ValueKey('usage-spend')),
      _Figure(
        'Tokens',
        tokens(tokensOf(u)),
        key: const ValueKey('usage-tokens'),
        sub:
            '${tokens(u.inputTokens.toInt())} in, '
            '${tokens(u.outputTokens.toInt())} out',
      ),
      if (read > 0 || written > 0)
        _Figure(
          'Cached',
          tokens(read),
          key: const ValueKey('usage-cached'),
          sub: [
            '${cachedShare(u)} of all input',
            if (written > 0) '${tokens(written)} written',
          ].join(', '),
        ),
      _Figure(
        'Turns',
        '${u.turns.toInt()}',
        key: const ValueKey('usage-turns'),
      ),
    ];
    return SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: LayoutBuilder(
            builder: (context, box) {
              final n = figures.length;
              final room = [
                figureRoom,
                for (final f in figures)
                  if (f.sub case final s?)
                    _twoLines(s, _Figure.subStyle(theme), scaler),
              ].reduce(max);
              final fits = (box.maxWidth - _gap * (n - 1)) / n >= room;
              final across = fits ? n : 2;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (var i = 0; i < n; i += across)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: _gap,
                      children: [
                        for (var j = i; j < i + across; j++)
                          Expanded(
                            child: j < n ? figures[j] : const SizedBox(),
                          ),
                      ],
                    ),
                  if (none != null)
                    Text(
                      none,
                      key: const ValueKey('usage-no-cost-note'),
                      style: theme.ui(theme.t.textMuted, size: 12),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The least width that holds [words] in [style] on two lines: a figure's
/// small line is never cut while its figures can go two to a row.
double _twoLines(String words, TextStyle style, TextScaler scaler) {
  final p = TextPainter(
    text: TextSpan(text: words, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 2,
  )..layout();
  var (fit, short) = (p.width, 0.0);
  while (fit - short > 1) {
    final mid = (fit + short) / 2;
    p.layout(maxWidth: mid);
    if (p.didExceedMaxLines) {
      short = mid;
    } else {
      fit = mid;
    }
  }
  p.dispose();
  return fit.ceilToDouble();
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
          // Two lines always fit (UsageTotalsCard makes the room); the
          // ellipsis is the last resort, never a silent cut.
          Text(
            s,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: subStyle(theme),
          ),
      ],
    );
  }

  /// The small line's style, which the card measures its room by.
  static TextStyle subStyle(NushiTheme theme) =>
      theme.ui(theme.t.textMuted, size: 12);
}

/// What the figures are and aren't, in small print under them.
class UsageFootnote extends StatelessWidget {
  const new(
    this.earliest, {
    required this.costs,
    this.cached = false,
    super.key,
  });

  /// When the first turn kept ended.
  final DateTime earliest;

  /// Whether a cost was reported: then what spend is, said first.
  final bool costs;

  /// Whether the Cached figure shows (anything read from or written to
  /// the cache): then what it is.
  final bool cached;

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
        '${cached ? 'Cached is what the agent read back from its cache, '
                  'apart from the tokens. ' : ''}'
        'Usage is counted from $since, the first turn this version kept; '
        'turns Nushi runs out of sight (a context check, a workflow’s '
        'agents) aren’t counted.',
        key: const ValueKey('usage-footnote'),
        style: theme.ui(theme.t.textMuted, size: 12),
      ),
    );
  }
}
