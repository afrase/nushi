import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_header.dart';
import 'package:nushi/theme/theme.dart';

/// What keeps an open pull request from merging, in a word each: its
/// checks, its review, its threads, conflicts, being behind its base.
List<String> mergeBlockers(GitHubPull p) => [
  if (p.checks.any((c) => c.failed) ||
      p.checks.any((c) => c.state == 'pending'))
    'checks',
  if (p.item.review == 'changes_requested' ||
      p.item.review == 'review_required' ||
      p.reviewers.any((r) => r.state == 'requested'))
    'review',
  if (p.threads.any((x) => !x.resolved)) 'threads',
  if (hasConflicts(p)) 'conflicts',
  if (p.mergeState == 'behind') 'behind ${p.base}',
];

/// A pull request's checks as one bar: failing red, running amber, passed
/// green, the rest grey, each as wide as its count.
class ChecksBar extends StatelessWidget {
  const new(this.pull, {super.key, this.height = 6});

  final GitHubPull pull;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final n = countChecks(pull);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 1,
          children: [
            for (final (count, color) in [
              (n.failing, t.crashed),
              (n.running, t.needs),
              (n.passed, t.done),
              (n.other, t.borderStrong),
            ])
              if (count > 0)
                Expanded(
                  flex: count,
                  child: ColoredBox(color: color),
                ),
          ],
        ),
      ),
    );
  }
}

class ChecksLegend extends StatelessWidget {
  const new(this.pull, {super.key});

  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = countChecks(pull);
    if (n.failing + n.running + n.other == 0) {
      return Text(
        n.passed == 1 ? 'The check passed' : 'All ${n.passed} checks passed',
        style: theme.ui(t.done, size: 12),
      );
    }
    Widget part(int count, String words, Color color, {bool dot = true}) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        if (dot)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        Text(
          '$count $words',
          style: theme.ui(
            words == 'failed' ? t.crashed : t.textSecondary,
            size: 12,
          ),
        ),
      ],
    );
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      children: [
        if (n.failing > 0) part(n.failing, 'failed', t.crashed),
        if (n.running > 0) part(n.running, 'running', t.needs),
        if (n.passed > 0) part(n.passed, 'passed', t.done),
        if (n.other > 0) part(n.other, 'skipped', t.textMuted, dot: false),
      ],
    );
  }
}

/// One of the widget's rows: an icon (or avatar), what, and a value or a
/// button at its right.
class WidgetRow extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.value,
    this.valueColor,
    this.trailing,
    this.color,
    this.muted = false,
    this.bold = false,
    this.tip = '',
    this.keepLabel = false,
  });

  final String tip;

  /// The label whole, the value cut instead.
  final bool keepLabel;
  final Widget icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final Color? color;
  final bool muted;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.ui(
        color ?? (muted ? t.textSecondary : t.text),
        size: 12.5,
        weight: bold ? FontWeight.w600 : null,
      ),
    );
    // A value at most 130 wide, else the label's room ([keepLabel]).
    Widget valueText(String v) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: keepLabel ? double.infinity : 130),
      child: Tooltip(
        message: tip,
        child: Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: theme.ui(valueColor ?? t.textMuted, size: 12),
        ),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: icon)),
          const SizedBox(width: 8),
          if (keepLabel) labelText else Expanded(child: labelText),
          if (value case final v?) ...[
            const SizedBox(width: 8),
            if (keepLabel) Expanded(child: valueText(v)) else valueText(v),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

/// A dashed-looking ring: someone asked, not yet answered.
class AskedRing extends StatelessWidget {
  const new(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.3),
    ),
  );
}

/// "2 new": comments since the tab last showed them.
class NewCount extends StatelessWidget {
  const new(this.n, {super.key});

  final int n;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$n new', style: theme.ui(t.accentInk, size: 11.5)),
    );
  }
}
