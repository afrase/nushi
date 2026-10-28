import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A pull request's checks counted: failing, running and passed.
({int failing, int running, int passed}) checkCounts(GitHubPull p) => (
  failing: p.checks.where((c) => c.failed).length,
  running: p.checks.where((c) => c.state == 'pending').length,
  passed: p.checks.where((c) => c.state == 'success').length,
);

/// The checks in words ("2 failing · 1 running · 5 passed") and the
/// color of the worst; null when there are none.
(String, Color)? checksWords(Tokens t, GitHubPull p) {
  final n = checkCounts(p);
  if (p.checks.isEmpty) return null;
  final words = [
    if (n.failing > 0) '${n.failing} failing',
    if (n.running > 0) '${n.running} running',
    if (n.passed > 0) '${n.passed} passed',
  ];
  return (
    words.isEmpty ? '${p.checks.length} skipped' : words.join(' · '),
    n.failing > 0
        ? t.crashed
        : n.running > 0
        ? t.needs
        : t.done,
  );
}

/// The checks in words as [checksWords] says them, each count in its own
/// color (failing red, running amber, passed green) and the dots between
/// muted: "1 passed" beside "1 failing" isn't red.
TextSpan checksSpan(NushiTheme theme, GitHubPull p) {
  final t = theme.t;
  final n = checkCounts(p);
  final parts = [
    if (n.failing > 0) ('${n.failing} failing', t.crashed),
    if (n.running > 0) ('${n.running} running', t.needs),
    if (n.passed > 0) ('${n.passed} passed', t.done),
  ];
  if (parts.isEmpty) {
    return TextSpan(
      text: '${p.checks.length} skipped',
      style: theme.ui(t.textMuted, size: 12),
    );
  }
  return TextSpan(
    children: [
      for (final (i, (words, color)) in parts.indexed) ...[
        if (i > 0)
          TextSpan(text: ' · ', style: theme.ui(t.textMuted, size: 12)),
        TextSpan(text: words, style: theme.ui(color, size: 12)),
      ],
    ],
  );
}

/// The details panel's Pull request card: the chat's pull request (the
/// one it started from, else its branch's) as a summary, collapsed (its
/// number in its state's color, its checks, review, unread comments),
/// and as rows open; [onShow] opens its tab. Without one, on a branch of
/// a GitHub repository: "No pull request for `branch`" and Link…. Null
/// (no card) for a folder that isn't a GitHub repository's clone on a
/// host signed in to, or on its default branch.
PanelCard? pullCard(ChatPull cp, {VoidCallback? onShow}) {
  final f = cp.found;
  if (cp.link == null && (f == null || f.host.isEmpty || f.defaultBranch)) {
    return null;
  }
  return PanelCard(
    title: 'Pull request',
    summary: _seen(() => _Summary(cp)),
    action: _Menu(cp),
    onTap: cp.pull == null ? null : onShow,
    rows: [(null, _seen(() => _Rows(cp)))],
  );
}

/// [child] built again when comments are seen.
Widget _seen(Widget Function() child) => ValueListenableBuilder(
  valueListenable: pullSeen,
  builder: (_, _, _) => child(),
);

class _Summary extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final l = cp.link;
    final p = cp.pull;
    if (l == null) return Text('None', style: theme.ui(t.textMuted, size: 12));
    final checks = p == null ? null : checksWords(t, p);
    final n = p == null ? null : checkCounts(p);
    final review = p == null ? null : reviewWords(t, p.item.review);
    final unread = p == null ? 0 : unreadComments(cp.chat.id, p);
    final small = theme.ui(t.textSecondary, size: 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Text(
          '#${l.number}',
          style: theme.code(
            p == null ? t.link : itemColor(t, p.item),
            size: 12,
          ),
        ),
        if (checks != null && n != null)
          Tooltip(
            message: 'Checks: ${checks.$1}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Icon(
                  n.failing > 0
                      ? Icons.close
                      : n.running > 0
                      ? Icons.schedule
                      : Icons.check,
                  size: 13,
                  color: checks.$2,
                ),
                if (n.failing + n.running > 0)
                  Text(
                    '${n.failing > 0 ? n.failing : n.running}',
                    style: theme.ui(checks.$2, size: 12),
                  ),
              ],
            ),
          ),
        if (review != null)
          Tooltip(
            message: review.$1,
            child: Icon(Icons.rate_review_outlined, size: 13, color: review.$2),
          ),
        if (unread > 0)
          Tooltip(
            message: '$unread new comment${unread == 1 ? '' : 's'}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Icon(Icons.chat_bubble_outline, size: 12, color: t.link),
                Text('$unread', style: small.copyWith(color: t.link)),
              ],
            ),
          ),
      ],
    );
  }
}

/// The card open: the title, then its state, checks, review, whether it
/// can merge and its comments; or why there's none.
class _Rows extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final l = cp.link;
    final p = cp.pull;
    final error = cp.error;
    if (l == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'No pull request for '),
                TextSpan(
                  text: cp.found?.branch ?? '',
                  style: theme.code(t.textSecondary, size: 11.5),
                ),
              ],
            ),
            style: muted,
          ),
          LinkText(
            'Link…',
            size: 12,
            tooltip: 'Link a pull request to this chat by hand',
            onTap: () => linkPull(context, cp),
          ),
          if (error != null) Text(error, style: muted),
        ],
      );
    }
    if (p == null) {
      return Text(error ?? '#${l.number}…', style: muted);
    }
    final it = p.item;
    final checks = checksWords(t, p);
    final review = reviewWords(t, it.review);
    final merge = mergeWords(t, p);
    final unread = unreadComments(cp.chat.id, p);
    final total = commentTimes(p).length;
    Widget row(String label, String value, Color color, {TextSpan? span}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 72, child: Text(label, style: muted)),
              Expanded(
                child: Text.rich(
                  span ?? TextSpan(text: value),
                  textAlign: TextAlign.right,
                  style: theme.ui(color, size: 12),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '#${it.ref.number} ',
                  style: theme.code(itemColor(t, it), size: 12),
                ),
                TextSpan(text: it.title),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text, size: 12.5, weight: FontWeight.w500),
          ),
        ),
        row('State', itemState(it), itemColor(t, it)),
        row(
          'Checks',
          checks?.$1 ?? 'None',
          t.textMuted,
          span: checks == null ? null : checksSpan(theme, p),
        ),
        row('Review', review?.$1 ?? 'None yet', review?.$2 ?? t.textMuted),
        if (it.state == 'open') row('Merge', merge.$1, merge.$2),
        row(
          'Comments',
          unread > 0 ? '$unread new of $total' : '$total',
          unread > 0 ? t.link : t.text,
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Not current: $error', style: muted),
          ),
      ],
    );
  }
}

/// The card's menu: Open on GitHub, Link another…, Unlink.
class _Menu extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final l = cp.link;
    final url = cp.pull?.item.url ?? '';
    return MenuIcon(
      Icons.more_horiz,
      size: 14,
      tooltip: 'Pull request',
      entries: [
        if (url.isNotEmpty)
          MenuEntry(
            'Open on GitHub',
            onPick: () {
              if (cp.pull case final p?) markPullSeen(cp.chat.id, p);
              openWeb(url);
            },
          ),
        MenuEntry(
          l == null ? 'Link pull request…' : 'Link another…',
          onPick: () => linkPull(context, cp),
        ),
        if (l != null)
          MenuEntry(
            'Unlink',
            tooltip: "It isn't found again for this chat",
            onPick: () => tryOrShow(context, () => cp.setLink(null)),
          ),
      ],
    );
  }
}
