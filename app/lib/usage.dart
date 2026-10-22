import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';

/// A token count in short: 950, 21.8k, 1M.
String _tokens(int n) => switch (n) {
  < 1000 && final v => '$v',
  < 1000000 && final v => '${_short(v / 1000)}k',
  final v => '${_short(v / 1000000)}M',
};

String _short(double v) =>
    v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// How full the agent's context is, as a small ring and a percentage; the
/// counts, and the last turn's tokens, on hover. Nothing until the agent
/// reports it.
class ContextMeter extends StatelessWidget {
  const ContextMeter(this.usage, {super.key});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    if (usage.contextSize == 0) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final fill = (usage.contextUsed.toInt() / usage.contextSize.toInt()).clamp(
      0.0,
      1.0,
    );
    final color = fill > 0.9
        ? t.crashed
        : fill > 0.7
        ? t.needs
        : t.textSecondary;
    final u = usage;
    final turn = [
      if (u.inputTokens > 0) '${_tokens(u.inputTokens.toInt())} in',
      if (u.outputTokens > 0) '${_tokens(u.outputTokens.toInt())} out',
      if (u.cachedReadTokens > 0)
        '${_tokens(u.cachedReadTokens.toInt())} cache read',
      if (u.cachedWriteTokens > 0)
        '${_tokens(u.cachedWriteTokens.toInt())} cache written',
    ];
    return Tooltip(
      message: [
        '${_tokens(u.contextUsed.toInt())} of ${_tokens(u.contextSize.toInt())} tokens in context',
        if (turn.isNotEmpty) 'Last turn: ${turn.join(', ')}',
      ].join('\n'),
      child: Row(
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
          Text('${(fill * 100).round()}%', style: theme.ui(color, size: 11.5)),
        ],
      ),
    );
  }
}

/// The session's cost so far, if the agent reports it ("$0.19").
class CostLabel extends StatelessWidget {
  const CostLabel(this.usage, {super.key, this.style});

  final Usage usage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final u = usage;
    if (u.currency.isEmpty) return const SizedBox.shrink();
    final amount = u.cost.toStringAsFixed(2);
    return Tooltip(
      message: 'The session’s cost so far, as the agent reports it',
      child: Text(
        u.currency == 'USD' ? '\$$amount' : '$amount ${u.currency}',
        style: style,
      ),
    );
  }
}
