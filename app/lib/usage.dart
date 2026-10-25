import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

/// A token count in short: 950, 21.8k, 1M.
String tokens(int n) => switch (n) {
  < 1000 && final v => '$v',
  < 1000000 && final v => '${_short(v / 1000)}k',
  final v => '${_short(v / 1000000)}M',
};

String _short(double v) =>
    v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// The session's cost so far, as the agent reports it ("$0.19"), or ''.
String cost(Usage u) {
  if (u.currency.isEmpty) return '';
  final amount = u.cost.toStringAsFixed(2);
  return u.currency == 'USD' ? '\$$amount' : '$amount ${u.currency}';
}

/// The last turn's tokens ("950 in · 210 out"), or ''.
String lastTurn(Usage u) => [
  if (u.inputTokens > 0) '${tokens(u.inputTokens.toInt())} in',
  if (u.outputTokens > 0) '${tokens(u.outputTokens.toInt())} out',
].join(' · ');

/// The last turn's cache use, or ''.
String cacheUse(Usage u) => [
  if (u.cachedReadTokens > 0) '${tokens(u.cachedReadTokens.toInt())} read',
  if (u.cachedWriteTokens > 0) '${tokens(u.cachedWriteTokens.toInt())} written',
].join(' · ');

/// How full the agent's context is, as a small ring and a percentage, amber
/// past 70% and red past 90%. Nothing until the agent reports it.
class ContextMeter extends StatelessWidget {
  const new(this.usage, {super.key});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    if (usage.contextSize == 0) return const SizedBox.shrink();
    final theme = NushiTheme.of(context), t = theme.t;
    final fill = _fill(usage), color = _color(t, fill);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 13,
          child: CircularProgressIndicator(
            value: fill,
            strokeWidth: 2,
            backgroundColor: t.borderStrong,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text('${(fill * 100).round()}%', style: theme.ui(color, size: 12)),
      ],
    );
  }
}

double _fill(Usage u) =>
    (u.contextUsed.toInt() / u.contextSize.toInt()).clamp(0.0, 1.0);

/// Quiet until it fills: amber past 70%, red past 90%.
Color _color(Tokens t, double fill) => fill > 0.9
    ? t.crashed
    : fill > 0.7
    ? t.needs
    : t.textSecondary;

/// "4% used", colored as [ContextMeter]; nothing until the agent says.
class ContextUsed extends StatelessWidget {
  const new(this.usage, {super.key});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    if (usage.contextSize == 0) return const SizedBox.shrink();
    final theme = NushiTheme.of(context), fill = _fill(usage);
    return Text(
      '${(fill * 100).round()}% used',
      style: theme.ui(_color(theme.t, fill), size: 12),
    );
  }
}

/// The context's fill as a bar, when what fills it isn't known.
class UsageBar extends StatelessWidget {
  const new(this.usage, {super.key});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t, fill = _fill(usage);
    return Container(
      height: 8,
      clipBehavior: Clip.antiAlias,
      decoration: box(t.borderSubtle, radius: 3),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fill,
        child: ColoredBox(color: _color(t, fill).withValues(alpha: 0.75)),
      ),
    );
  }
}

/// Whether the agent lists [c] without it being in the context: loaded on
/// demand.
bool onDemand(ContextCategory c) => c.kind == 'deferred';

/// The bar's parts: each category in the context (not those [onDemand]),
/// in order, with its share of their total; the shares add up to 1.
List<(ContextCategory, double)> contextShares(List<ContextCategory> all) {
  final parts = all.where((c) => !onDemand(c) && c.tokens > 0).toList();
  final total = parts.fold(0, (n, c) => n + c.tokens.toInt());
  return [for (final c in parts) (c, c.tokens.toInt() / total)];
}

/// What fills the agent's context, as /context tells (ADR 0017): a bar of
/// the categories in quiet colors, free space left empty, then a row per
/// category with its tokens and share; the deferred ones, outside the
/// context, dimmed under them.
class ContextBreakdown extends StatelessWidget {
  const new(this.categories, {super.key});

  final List<ContextCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final palette = [
      t.accent,
      t.function,
      t.string,
      t.keyword,
      t.claude,
      t.needs,
      t.done,
      t.link,
      t.crashed,
      t.textSecondary,
    ];
    bool free(ContextCategory c) => c.kind == 'free';
    final inContext = categories.where((c) => !onDemand(c)).toList();
    final colors = {
      for (final (i, c) in inContext.where((c) => !free(c)).indexed)
        c.name: palette[i % palette.length].withValues(alpha: 0.75),
    };
    final shares = contextShares(categories);
    Widget row(ContextCategory c, {bool dim = false}) => Row(
      spacing: 6,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: box(
            (dim ? null : colors[c.name]) ?? t.borderStrong,
            fill: dim ? null : colors[c.name],
            radius: 2,
          ),
        ),
        Expanded(
          child: Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(dim ? t.textMuted : t.textSecondary, size: 12),
          ),
        ),
        Text(
          dim
              ? tokens(c.tokens.toInt())
              : '${tokens(c.tokens.toInt())}  ${c.percent.toStringAsFixed(1)}%',
          style: theme.ui(dim ? t.textMuted : t.text, size: 12),
        ),
      ],
    );
    final later = categories.where(onDemand).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 3,
      children: [
        Container(
          height: 8,
          margin: const EdgeInsets.only(bottom: 4),
          clipBehavior: Clip.antiAlias,
          decoration: box(t.borderSubtle, radius: 3),
          child: LayoutBuilder(
            builder: (context, box) {
              // A used part gets a sliver at least; free space what's left.
              final used = [
                for (final (c, share) in shares)
                  if (!free(c))
                    (c, (share * box.maxWidth).clamp(1.5, box.maxWidth)),
              ];
              final width = used.fold(0.0, (w, p) => w + p.$2);
              final scale = width > box.maxWidth ? box.maxWidth / width : 1.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (c, w) in used)
                    SizedBox(
                      width: w * scale,
                      child: ColoredBox(color: colors[c.name]!),
                    ),
                ],
              );
            },
          ),
        ),
        for (final c in inContext) row(c),
        if (later.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Loaded on demand',
              style: theme.ui(t.textMuted, size: 11.5),
            ),
          ),
          for (final c in later) row(c, dim: true),
        ],
      ],
    );
  }
}
