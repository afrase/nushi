import 'package:flutter/material.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_link_dialog.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pull_summary.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The details panel's Pull request widget (ADR 0117): a row for each of
/// the chat's pull requests ([PullRow]), titled "Pull requests" with two
/// or more; folded, one as a line ([pullSummary]), several as their
/// count by state and the worst checks. A row opens the Pull request tab
/// on it ([onShow]). Without one, on a branch of a GitHub repository: "No
/// pull request linked for `branch`" and Link…. Null (no widget) for a
/// folder that isn't a GitHub repository's clone on a host signed in to,
/// or on its default branch.
PanelWidget? pullWidget(ChatPull cp, {VoidCallback? onShow}) {
  final f = cp.found;
  final links = cp.links;
  if (links.isEmpty && (f == null || f.host.isEmpty || f.defaultBranch)) {
    return null;
  }
  final show = onShow ?? () {};
  return PanelWidget(
    title: 'Pull request',
    label: links.length >= 2 ? 'Pull requests' : null,
    tooltip: () => cp.checkedText,
    summary: ListenableBuilder(
      listenable: Listenable.merge([
        CleanUpJob.of(cp.chat),
        GitHubItems.of(cp.daemon),
      ]),
      builder: (_, _) => _seen(() => _Summary(cp)),
    ),
    action: _Menu(cp),
    rows: [
      (
        null,
        // The job too: a merged row offers Clean up… only until one starts.
        ListenableBuilder(
          listenable: Listenable.merge([
            CleanUpJob.of(cp.chat),
            GitHubItems.of(cp.daemon),
          ]),
          builder: (_, _) => _seen(() => _Rows(cp, show)),
        ),
      ),
    ],
  );
}

/// [child] built again when comments are seen.
Widget _seen(Widget Function() child) =>
    ListenableBuilder(listenable: pullSeenComments, builder: (_, _) => child());

class _Summary extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final links = cp.links;
    if (links.isEmpty) {
      return Text('None', style: theme.ui(t.textMuted, size: 12));
    }
    if (links.length >= 2) {
      return pullsFolded(theme, [for (final l in links) cp.itemOf(l)]);
    }
    // From its row's item (ADR 0140); the whole one only from a daemon
    // before them.
    final l = links.single;
    final it = cp.itemOf(l);
    final offer = it?.state == 'merged' && offersCleanUp(cp);
    return pullSummary(
      context,
      theme,
      number: l.number,
      pull: null,
      item: it,
      unread: cp.unreadOf(l),
      onCleanUp: offer ? () => cleanUpPull(context, cp, l) : null,
    );
  }
}

/// The widget open: a row a pull request; or why there's none.
class _Rows extends StatelessWidget {
  const new(this.cp, this.onShow);

  final ChatPull cp;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    final links = cp.links;
    final error = cp.error;
    if (links.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'No pull request linked for '),
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
    // Kept from before while it's asked: says when it was read.
    final kept = cp.keptAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in links) PullRow(cp, l, onShow: onShow),
        // A clean-up under way, or what it did and kept (ADR 0063).
        ListenableBuilder(
          listenable: CleanUpJob.of(cp.chat),
          builder: (context, _) => CleanUpJob.of(cp.chat).started
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CleanUpProgress(CleanUpJob.of(cp.chat)),
                )
              : const SizedBox.shrink(),
        ),
        if (kept != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              updatedLine(kept, loading: cp.asking)!,
              style: theme.ui(t.textMuted, size: 11.5),
            ),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error, style: muted),
          ),
      ],
    );
  }
}

/// The widget's menu: Link pull request…, or Link another pull request…
/// once there's one.
class _Menu extends StatelessWidget {
  const new(this.cp);

  final ChatPull cp;

  @override
  Widget build(BuildContext context) => MenuIcon.line(
    LineIcon.more,
    size: 14,
    tooltip: 'Pull requests',
    entries: [
      MenuEntry(
        cp.links.isEmpty ? 'Link pull request…' : 'Link another pull request…',
        onPick: () => linkPull(context, cp),
      ),
    ],
  );
}
