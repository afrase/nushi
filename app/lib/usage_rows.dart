import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';

// Settings › Usage's rows (ADR 0136): a group's rows with a bar to scale,
// a costly chat's row, and an account limit's.

/// Figures that line up down a column, whatever their digits.
TextStyle tabular(TextStyle s) =>
    s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// The spend in [t], each currency as the agent reported it ("$12.40",
/// "$3.10, 2.00 EUR"); '' when no turn reported a cost.
String spendOf(UsageTotals t) => [
  for (final c in t.cost)
    if (cost(Usage(cost: c.amount, currency: c.currency)) case final s
        when s.isNotEmpty)
      s,
].join(', ');

/// [amount] in [currency], as [spendOf] writes it; "0" for nothing.
String money(double amount, String currency) =>
    switch (cost(Usage(cost: amount, currency: currency))) {
      '' => '0',
      final s => s,
    };

/// The tokens counted as used: what went in and came out, not what the
/// cache read or wrote (shown apart, never folded in).
int tokensOf(UsageTotals t) => (t.inputTokens + t.outputTokens).toInt();

/// What the cache read back of [t]'s input, as a whole per cent of all
/// that went in (fresh, read from the cache and written to it): "93%",
/// "under 1%" and "over 99%" where rounding would say 0% or 100% of a
/// share that isn't exactly so.
String cachedShare(UsageTotals t) {
  final read = t.cacheReadTokens.toInt();
  final all = (t.inputTokens + t.cacheReadTokens + t.cacheWriteTokens).toInt();
  if (all <= 0) return '0%';
  return switch ((read * 100 / all).round()) {
    0 when read > 0 => 'under 1%',
    100 when read < all => 'over 99%',
    final p => '$p%',
  };
}

/// What the page measures by: the spend in [currency] (the one most was
/// spent in), or tokens when nothing in the range reported a cost.
final class UsageMeasure {
  const new(this.currency, {this.cached = false});

  /// By the currency most of [t] was spent in, or tokens; a Cached column
  /// when anything in [t] was read from the cache.
  factory mostSpent(UsageTotals t) {
    final paid = [...t.cost.where((c) => c.amount > 0)]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return UsageMeasure(
      paid.firstOrNull?.currency,
      cached: t.cacheReadTokens > 0,
    );
  }

  /// The currency spend is measured in; null: tokens instead.
  final String? currency;

  /// Whether the rows show what each read from the cache.
  final bool cached;

  /// The same, with a Cached column only where one of [rows] read from
  /// the cache: a group whose rows read nothing has no blank column.
  UsageMeasure forRows(Iterable<UsageTotals> rows) => UsageMeasure(
    currency,
    cached: cached && rows.any((t) => t.cacheReadTokens > 0),
  );

  /// Whether any turn in the range reported a cost.
  bool get costs => currency != null;

  /// [t]'s amount by it.
  double of(UsageTotals t) => switch (currency) {
    final c? => t.cost.where((x) => x.currency == c).firstOrNull?.amount ?? 0,
    null => tokensOf(t).toDouble(),
  };

  /// [v] as written: money or a token count.
  String write(double v) => switch (currency) {
    final c? => money(v, c),
    null => tokens(v.round()),
  };
}

/// A row's columns at its end: spend ([measure]'s money, if any), tokens
/// and what was read from the cache (if the span read any; blank for a
/// row that read none), at fixed widths so they line up down a group.
List<Widget> usageColumns(
  NushiTheme theme,
  UsageTotals t,
  UsageMeasure measure, {
  required String agentWords,
}) {
  final tt = theme.t;
  final style = tabular(theme.ui(tt.text, weight: FontWeight.w500));
  final muted = tabular(theme.ui(tt.textMuted, size: 12));
  final spent = spendOf(t);
  return [
    if (measure.costs) ...[
      const SizedBox(width: 12),
      SizedBox(
        width: UsageBarRow.spendWidth,
        child: Text(
          spent.isEmpty ? 'No cost' : spent,
          key: spent.isEmpty ? const ValueKey('usage-no-cost') : null,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: spent.isEmpty ? muted : style,
          semanticsLabel: spent.isEmpty ? '$agentWords: no cost' : null,
        ),
      ),
    ],
    const SizedBox(width: 12),
    SizedBox(
      width: UsageBarRow.tokensWidth,
      child: Text(
        tokens(tokensOf(t)),
        textAlign: TextAlign.right,
        maxLines: 1,
        style: measure.costs ? muted : style,
      ),
    ),
    if (measure.cached) ...[
      const SizedBox(width: 12),
      SizedBox(
        key: const ValueKey('usage-cached-cell'),
        width: UsageBarRow.cachedWidth,
        child: t.cacheReadTokens > 0
            ? Text(
                tokens(t.cacheReadTokens.toInt()),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: muted,
              )
            : null,
      ),
    ],
  ];
}

/// The names of [usageColumns]' columns, over a group's rows at the end
/// of its title's line, each over its column.
class UsageColumnsHead extends StatelessWidget {
  const new(this.measure, {super.key});

  final UsageMeasure measure;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme.ui(theme.t.textMuted, size: 11.5);
    Widget head(String name, double width) => SizedBox(
      width: width,
      child: Text(name, textAlign: TextAlign.right, style: style),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (measure.costs) head('Spend', UsageBarRow.spendWidth),
        const SizedBox(width: 12),
        head('Tokens', UsageBarRow.tokensWidth),
        if (measure.cached) ...[
          const SizedBox(width: 12),
          head('Cached', UsageBarRow.cachedWidth),
        ],
        const SizedBox(width: 14), // the rows' own padding
      ],
    );
  }
}

/// A row of a group's breakdown (by agent, model or project): [lead] (an
/// agent's mark), [label], a bar of its share at [measure]'s scale up to
/// [top], its spend and its tokens. Narrow, the bar goes under the label.
class UsageBarRow extends StatelessWidget {
  const new({
    required this.label,
    required this.totals,
    required this.measure,
    required this.top,
    super.key,
    this.lead,
    this.tip = '',
    this.after = '',
    this.muted = false,
  });

  /// The spend column's width: "$1234.56" and room.
  static const spendWidth = 80.0;

  /// The tokens column's width: "123.4M".
  static const tokensWidth = 56.0;

  /// The cached column's width, a token count as the tokens'.
  static const double cachedWidth = tokensWidth;

  /// The row's width under which the bar goes under the label.
  static const stackBelow = 440.0;

  final String label;
  final UsageTotals totals;
  final UsageMeasure measure;
  final double top;
  final Widget? lead;

  /// The label's tooltip (a project's path).
  final String tip;

  /// Muted words after the label, a space between: a twin project's
  /// parent ("lumen" then "work").
  final String after;

  /// The label in muted text: a name that's no name ("No folder").
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final share = top <= 0 ? 0.0 : (measure.of(totals) / top).clamp(0.0, 1.0);
    Widget name = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          if (after.isNotEmpty)
            TextSpan(text: ' $after', style: theme.ui(t.textMuted)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.ui(muted ? t.textMuted : t.text),
    );
    if (tip.isNotEmpty) name = tooltip(context, tip, name);
    final bar = ShareBar(share);
    return LayoutBuilder(
      builder: (context, box) {
        final stacked = box.maxWidth < stackBelow;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: stacked ? 8 : 12,
          ),
          child: Row(
            children: [
              if (stacked) ...[
                if (lead case final l?) ...[
                  SizedBox(width: 16, child: Center(child: l)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 5,
                    children: [name, bar],
                  ),
                ),
              ] else ...[
                // The mark is in the label's share, so every group's bars
                // start at the same place, marked or not.
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      if (lead case final l?) ...[
                        SizedBox(width: 16, child: Center(child: l)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: name),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: bar),
              ],
              ...usageColumns(theme, totals, measure, agentWords: label),
            ],
          ),
        );
      },
    );
  }
}

/// A thin bar on the meter's track, filled to [share] (0 to 1) in the
/// accent; a share above none shows at least a dot.
class ShareBar extends StatelessWidget {
  const new(this.share, {super.key, this.color});

  final double share;

  /// The fill's color; the accent's unless given (a limit's state).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final round = BorderRadius.circular(NushiTheme.pill);
    return Container(
      height: 6,
      decoration: BoxDecoration(color: t.lifted, borderRadius: round),
      alignment: Alignment.centerLeft,
      child: share <= 0
          ? null
          : FractionallySizedBox(
              widthFactor: share.clamp(0.0, 1.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: color ?? t.accent,
                    borderRadius: round,
                  ),
                ),
              ),
            ),
    );
  }
}

/// A costly chat's row: its agent's mark, its title ("Deleted chat" when
/// it's gone; one line, whole under the pointer), its spend and tokens.
/// [onOpen] opens it (null: it's gone).
class UsageChatRow extends StatelessWidget {
  const new(this.chat, {required this.measure, super.key, this.onOpen});

  final UsageChat chat;
  final UsageMeasure measure;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final gone = chat.title.isEmpty;
    // One line, as a project's row: where the columns leave a narrow page
    // little room the title is cut, and shows whole under the pointer.
    Widget title = Text(
      gone ? 'Deleted chat' : plainName(chat.title),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme
          .ui(gone ? t.textMuted : t.text)
          .copyWith(fontStyle: gone ? FontStyle.italic : null),
    );
    if (!gone) title = tooltip(context, plainName(chat.title), title);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 16, child: Center(child: AgentMark(chat.agent))),
          const SizedBox(width: 10),
          Expanded(child: title),
          ...usageColumns(theme, chat.totals, measure, agentWords: chat.title),
        ],
      ),
    );
    return onOpen == null
        ? row
        : Tap(
            key: ValueKey('usage-chat-${chat.chatId}'),
            radius: 0, // the group's corners cut it
            tooltip: 'Open chat',
            onTap: onOpen,
            child: row,
          );
  }
}
