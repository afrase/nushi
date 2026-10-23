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
  const ContextMeter(this.usage, {super.key});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    if (usage.contextSize == 0) return const SizedBox.shrink();
    final theme = NushiTheme.of(context), t = theme.t;
    final fill = (usage.contextUsed.toInt() / usage.contextSize.toInt()).clamp(
      0.0,
      1.0,
    );
    final color = fill > 0.9
        ? t.crashed
        : fill > 0.7
        ? t.needs
        : t.textSecondary;
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
