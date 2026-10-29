import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/cleanup_dialog.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/pull_widget.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

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
    tooltip: () => cp.checkedText,
    summary: ListenableBuilder(
      listenable: Listenable.merge([CleanUpJob.of(cp.chat), cleanUpLater]),
      builder: (_, _) => _seen(() => _Summary(cp)),
    ),
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
    final offer =
        p != null &&
        p.item.state == 'merged' &&
        cp.daemon.daemonApi >= cleanUpApi &&
        !cleanUpLater.value.contains(cp.chat.id) &&
        !CleanUpJob.of(cp.chat).started;
    return pullSummary(
      theme,
      number: l.number,
      pull: p,
      unread: p == null ? 0 : unreadComments(cp.chat.id, p),
      onCleanUp: offer
          ? () => showCleanUp(context, cp.daemon, cp.chat, pull: p)
          : null,
    );
  }
}

/// The card open: the pull request ([PullRows]); or why there's none.
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
    // Kept from before while it's asked: says when it was read.
    final kept = cp.keptAt;
    if (kept == null) return PullRows(cp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PullRows(cp),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            updatedLine(kept, loading: cp.asking, now: clock())!,
            style: theme.ui(t.textMuted, size: 11.5),
          ),
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
        if (cp.pull case final p?
            when (p.item.state == 'merged' || p.item.state == 'closed') &&
                cp.daemon.daemonApi >= cleanUpApi)
          MenuEntry(
            'Clean up…',
            onPick: () => showCleanUp(context, cp.daemon, cp.chat, pull: p),
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
