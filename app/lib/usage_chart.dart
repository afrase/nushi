import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/usage_range.dart';
import 'package:nushi/usage_rows.dart';

/// The days' short names, Monday first, as `DateTime.weekday` counts.
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// [d] as a chart labels it: "Oct 23".
String _short(DateTime d) => '${months[d.month - 1].substring(0, 3)} ${d.day}';

/// Settings › Usage's chart of days (ADR 0136): a bar a day from [first]
/// to [today], each [measure]'s amount of that day's usage in [days] (by
/// day key; a day without a turn has none), on one scale from 0 with a
/// few round lines across. Under the bars, each day's name, or, when
/// they're too many to name, every so many days' date, today's always;
/// the highest bar has its value over it. Under the pointer, the day's
/// column is lit and a card of its figures follows the pointer
/// ([UsageDayCard]), in place of the highest bar's value. Drawn from the
/// theme's tokens: no chart package.
class UsageDayChart extends StatefulWidget {
  const new({
    required this.days,
    required this.first,
    required this.today,
    required this.measure,
    super.key,
  });

  final List<UsageGroup> days;
  final DateTime first;
  final DateTime today;
  final UsageMeasure measure;

  /// The plot's height, bars and lines.
  static const plotHeight = 132.0;

  /// The room over the plot for the highest bar's value.
  static const headroom = 20.0;

  /// The room under it for the days' names.
  static const footRoom = 24.0;

  /// The least a day's label takes, with room on each side.
  static const _labelRoom = 46.0;

  @override
  State<UsageDayChart> createState() => _UsageDayChartState();
}

class _UsageDayChartState extends State<UsageDayChart> {
  Offset? _pointer; // where the pointer is over the chart, if it is

  static const double plotHeight = UsageDayChart.plotHeight;
  static const double headroom = UsageDayChart.headroom;
  static const double footRoom = UsageDayChart.footRoom;
  static const double _labelRoom = UsageDayChart._labelRoom;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final measure = widget.measure;
    final byKey = {for (final d in widget.days) d.key: d.totals};
    final all = daysBetween(widget.first, widget.today);
    final values = [
      for (final d in all) measure.of(byKey[dayKey(d)] ?? UsageTotals()),
    ];
    final top = values.fold(0.0, max);
    final lines = _ticks(top);
    final scale = max(top, lines.last);
    final small = tabular(theme.ui(t.textMuted, size: 11.5));
    // The scale's labels' column: as wide as its widest.
    final axis =
        lines
            .map((v) => _width(measure.write(v), small, context))
            .fold(0.0, max)
            .ceilToDouble() +
        12;
    final highest = top > 0 ? values.indexOf(top) : -1;
    final named = all.length <= 7;
    return SizedBox(
      height: headroom + plotHeight + footRoom,
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = (box.maxWidth - axis) / all.length;
          final bar = min(40.0, max(1.0, slot * (slot < 6 ? 0.8 : 0.6)));
          // Every so many days a date, counted back from today's.
          final every = named ? 1 : max(1, (_labelRoom / slot).ceil());
          double y(double v) =>
              headroom + plotHeight - (scale == 0 ? 0 : v / scale * plotHeight);
          // The day under the pointer: its column, whatever the height.
          final at = switch (_pointer) {
            final p? when p.dx >= axis && p.dx < box.maxWidth =>
              ((p.dx - axis) / slot).floor().clamp(0, all.length - 1),
            _ => null,
          };
          return MouseRegion(
            onHover: (e) => setState(() => _pointer = e.localPosition),
            onExit: (_) => setState(() => _pointer = null),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (at != null)
                  Positioned(
                    left: axis + slot * at,
                    width: slot,
                    top: 0,
                    height: headroom + plotHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.hover,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(NushiTheme.tag),
                        ),
                      ),
                    ),
                  ),
                for (final v in lines) ...[
                  Positioned(
                    left: axis,
                    right: 0,
                    top: y(v),
                    child: Container(height: 1, color: t.line),
                  ),
                  Positioned(
                    left: 0,
                    width: axis - 10,
                    top: y(v) - 8,
                    child: Text(
                      measure.write(v),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      style: small,
                    ),
                  ),
                ],
                for (final (i, d) in all.indexed) ...[
                  if (values[i] > 0)
                    Positioned(
                      left: axis + slot * i + (slot - bar) / 2,
                      width: bar,
                      top: y(values[i]),
                      height: max(2, values[i] / scale * plotHeight),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(min(NushiTheme.tag, bar / 2)),
                          ),
                        ),
                      ),
                    ),
                  if (i == highest && at == null)
                    Positioned(
                      // Over its bar; near either end of the plot, from
                      // the bar's edge inward, so it stays inside.
                      left: _valueLeft(
                        axis + slot * i,
                        slot,
                        axis,
                        box.maxWidth,
                      ),
                      width: 100,
                      top: y(values[i]) - 18,
                      child: Text(
                        measure.write(values[i]),
                        textAlign: _valueAlign(
                          axis + slot * i,
                          slot,
                          axis,
                          box.maxWidth,
                        ),
                        maxLines: 1,
                        style: tabular(
                          theme.ui(t.text, size: 12, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if ((all.length - 1 - i) % every == 0)
                    Positioned(
                      left: axis + slot * i + slot / 2 - _labelRoom,
                      width: _labelRoom * 2,
                      top: headroom + plotHeight + 6,
                      child: Text(
                        i == all.length - 1
                            ? 'Today'
                            : named
                            ? _weekdays[d.weekday - 1]
                            : _short(d),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: theme.ui(
                          i == all.length - 1 ? t.text : t.textSecondary,
                          size: 12,
                          weight: i == all.length - 1 ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                ],
                if (at != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomSingleChildLayout(
                        delegate: _BesidePointer(_pointer!),
                        child: UsageDayCard(
                          day: all[at],
                          totals: byKey[dayKey(all[at])],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A day's figures on the card that follows the pointer over
/// [UsageDayChart]: the day ("Tue, Oct 27"), then its spend (when any
/// was reported), tokens and turns, a line each, or that nothing was
/// used.
class UsageDayCard extends StatelessWidget {
  const new({required this.day, required this.totals, super.key});

  final DateTime day;

  /// The day's usage; none when it had no turn.
  final UsageTotals? totals;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final u = totals;
    final none = u == null || u.turns == 0 && tokensOf(u) == 0;
    final spent = none ? '' : spendOf(u);
    final label = theme.ui(t.textSecondary, size: 12);
    final value = tabular(theme.ui(t.text, size: 12, weight: FontWeight.w600));
    Widget line(String name, String figure) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 56, child: Text(name, style: label)),
          Text(figure, maxLines: 1, style: value),
        ],
      ),
    );
    return Container(
      decoration: floatBox(t, radius: NushiTheme.control),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_weekdays[day.weekday - 1]}, ${_short(day)}',
            // design: off the type scale, to move to a step
            style: theme.ui(t.text, size: 12.5, weight: FontWeight.w600),
          ),
          if (none)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Nothing used', style: label),
            )
          else ...[
            if (spent.isNotEmpty) line('Spend', spent),
            line('Tokens', tokens(tokensOf(u))),
            line('Turns', '${u.turns.toInt()}'),
          ],
        ],
      ),
    );
  }
}

/// Puts the day's card beside the pointer at [at]: right of it, or left
/// of it where that would leave the chart's width, and under it as far as
/// the chart's foot lets it, where it stops; never over the pointer
/// itself.
class _BesidePointer extends SingleChildLayoutDelegate {
  const new(this.at);

  final Offset at;

  /// Between the pointer and the card.
  static const gap = 14.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().copyWith(maxHeight: double.infinity);

  @override
  Offset getPositionForChild(Size size, Size child) => Offset(
    at.dx + gap + child.width <= size.width
        ? at.dx + gap
        : max(0, at.dx - gap - child.width),
    min(at.dy + gap, max(0, size.height - child.height)),
  );

  @override
  bool shouldRelayout(_BesidePointer old) => old.at != at;
}

/// Where a bar's value label (100 wide) starts, for the bar in the slot
/// at [at], [slot] wide, in a plot from [from] to [to]: centred over it,
/// or from its slot's edge where centring would leave the plot.
double _valueLeft(double at, double slot, double from, double to) =>
    switch (at + slot / 2 - 50) {
      final l when l < from => at,
      final l when l + 100 > to => at + slot - 100,
      final l => l,
    };

/// How a bar's value label lines up in its box ([_valueLeft]'s cases).
TextAlign _valueAlign(double at, double slot, double from, double to) =>
    switch (at + slot / 2 - 50) {
      final l when l < from => TextAlign.left,
      final l when l + 100 > to => TextAlign.right,
      _ => TextAlign.center,
    };

/// [text]'s width in [style].
double _width(String text, TextStyle style, BuildContext context) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

/// Round lines up the scale for [top]: 0, then steps of 1, 2, 2.5 or 5
/// times a power of ten, about three of them, the last at or past [top]
/// so the highest bar stays under it.
List<double> _ticks(double top) {
  if (top <= 0) return [0, 1];
  final raw = top / 3;
  final p = pow(10, (log(raw) / ln10).floor()).toDouble();
  final step = [1, 2, 2.5, 5, 10].map((m) => m * p).firstWhere((s) => s >= raw);
  return [for (var v = 0.0; v < top + step - 1e-9; v += step) v];
}
