import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';

/// A token count in short: 950, 21.8k, 1M.
String tokens(int n) => switch (n) {
  < 1000 && final v => '$v',
  < 1000000 && final v => '${_short(v / 1000)}k',
  final v => '${_short(v / 1000000)}M',
};

String _short(double v) =>
    v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// The session's cost so far, as the agent reports it ("$0.19"), or ''.
/// Nothing for a cost of 0: a login that isn't paid by the token (a
/// subscription) reports 0, and some agents (oh-my-pi) send nothing then.
String cost(Usage u) {
  if (u.currency.isEmpty || u.cost == 0) return '';
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

/// How full the agent's context is, as Claude's own panel shows it: a
/// percentage and a small pill that fills, amber past 70% and red past 90%.
/// From [usage] when the agent reported it; else from [breakdown] (what
/// /context said, e.g. for a reopened chat before its first turn); else
/// nothing. The fill eases to its new width over 400 ms and its color
/// crossfades; a compaction (a drop of more than 20 points) drains it over
/// 600 ms, the figure counting down with it. With Reduce Motion it jumps.
class ContextMeter extends StatefulWidget {
  const new(this.usage, {super.key, this.breakdown});

  final Usage usage;
  final GetContextUsageResponse? breakdown;

  @override
  State<ContextMeter> createState() => _ContextMeterState();
}

class _ContextMeterState extends State<ContextMeter> with ClockRun {
  double? _from; // the fill the motion started from
  double? _to; // the fill it goes to
  bool _drain = false; // a compaction: the figure follows the fill

  // design: a meter's fill, its own pace
  static const _fillFor = Duration(milliseconds: 400);
  // design: a meter's drain, its own pace
  static const _drainFor = Duration(milliseconds: 600);
  static const _colorFor = 300.0;

  double? get _fill => widget.usage.contextSize > 0
      ? _fillOf(widget.usage)
      : breakdownFill(widget.breakdown?.categories ?? const []);

  @override
  void initState() {
    super.initState();
    _to = _fill;
  }

  @override
  void didUpdateWidget(ContextMeter old) {
    super.didUpdateWidget(old);
    final to = _fill;
    if (to == _to) return;
    final from = _now;
    _to = to;
    if (from == null || to == null || reduceMotion(context)) {
      stopRun();
      return;
    }
    _from = from;
    _drain = from - to > 0.2;
    runFor(_drain ? _drainFor : _fillFor);
  }

  /// The fill as it shows now, moving or not.
  double? get _now {
    final (from, to) = (_from, _to);
    if (!running || from == null || to == null) return to;
    return from + (to - from) * _eased;
  }

  double get _eased => _drain
      ? const Cubic(
          0.4,
          0,
          0.2,
          1,
        ).transform((ranMs / _drainFor.inMilliseconds).clamp(0.0, 1.0))
      : const Cubic(
          0.2,
          0.8,
          0.2,
          1,
        ).transform((ranMs / _fillFor.inMilliseconds).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final fill = _now;
    final to = _to;
    if (fill == null || to == null) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    // The color crossfades from where it was to the new fill's.
    final from = _from;
    Color color(Color quiet) => running && from != null
        ? Color.lerp(
            fillColor(t, from, quiet),
            fillColor(t, to, quiet),
            part(ranMs, 0, _colorFor),
          )!
        : fillColor(t, to, quiet);
    // The figure jumps to the new fill, but follows a drain down.
    final shown = _drain && running ? fill : to;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(shown * 100).round()}%',
          style: theme.ui(color(t.textMuted), size: 12),
        ),
        const SizedBox(width: 6),
        Container(
          width: 22,
          height: 8,
          decoration: BoxDecoration(
            color: t.lifted,
            borderRadius: BorderRadius.circular(NushiTheme.pill),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            // At least a dot, as Claude's does at 1%.
            widthFactor: fill.clamp(8 / 22, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color(t.accent),
                borderRadius: BorderRadius.circular(NushiTheme.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How full the context is by /context's categories: what's in it (not
/// the free space, the autocompact buffer or what's deferred) over the
/// window; null without them.
double? breakdownFill(List<ContextCategory> cs) {
  var used = 0;
  var size = 0;
  for (final c in cs.where((c) => c.kind != 'deferred')) {
    size += c.tokens.toInt();
    if (c.kind == '' && c.name != 'Autocompact buffer') {
      used += c.tokens.toInt();
    }
  }
  return size == 0 ? null : (used / size).clamp(0.0, 1.0);
}

double _fillOf(Usage u) =>
    (u.contextUsed.toInt() / u.contextSize.toInt()).clamp(0.0, 1.0);

/// [quiet] until the context fills: amber past 70%, red past 90%.
Color fillColor(Tokens t, double fill, Color quiet) => fill > 0.9
    ? t.crashed
    : fill > 0.7
    ? t.needs
    : quiet;
