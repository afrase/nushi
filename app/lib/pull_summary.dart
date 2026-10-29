import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_lights.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/theme/theme.dart';

/// A pull request on one line, as the collapsed PR widget (and the
/// phone's chat bar) shows it: its number in its state's color, then for
/// an open one what's going on (failing or running checks, changes
/// requested or a reviewer waiting, threads not resolved, new comments),
/// or "Ready" once it can merge; "Draft", "Merged", "Closed" else.
Widget pullSummary(
  NushiTheme theme, {
  required int number,
  required GitHubPull? pull,
  int unread = 0,
  double size = 12,
  VoidCallback? onCleanUp,
}) {
  final t = theme.t;
  final p = pull;
  Widget count(IconData icon, Color color, String words, String tip) => Tooltip(
    message: tip,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        Icon(icon, size: size + 1, color: color),
        if (words.isNotEmpty) Text(words, style: theme.ui(color, size: size)),
      ],
    ),
  );
  final it = p?.item;
  final parts = <Widget>[];
  if (p != null && it != null) {
    final n = countChecks(p);
    final open = p.threads.where((x) => !x.resolved).length;
    final waiting = p.reviewers.any((r) => r.state == 'requested');
    final ready =
        (p.mergeState == 'clean' || p.mergeState == 'has_hooks') &&
        n.failing + n.running == 0 &&
        open == 0;
    switch (it.state) {
      case 'merged' || 'closed':
        parts.add(
          Text(itemState(it), style: theme.ui(itemColor(t, it), size: size)),
        );
      case _ when it.draft:
        parts.add(Text('Draft', style: theme.ui(t.textMuted, size: size)));
      case _ when ready:
        parts.add(count(Icons.merge_type, t.done, 'Ready', 'Ready to merge'));
      default:
        if (n.failing > 0) {
          parts.add(
            count(
              Icons.cancel_outlined,
              t.crashed,
              '${n.failing}',
              'Checks: ${n.failing} failing',
            ),
          );
        } else if (n.running > 0) {
          parts.add(
            count(
              Icons.schedule,
              t.needs,
              '${n.running}',
              'Checks: ${n.running} running',
            ),
          );
        }
        if (it.review == 'changes_requested') {
          parts.add(
            count(
              Icons.rate_review_outlined,
              t.crashed,
              '',
              'Changes requested',
            ),
          );
        } else if (waiting) {
          parts.add(
            Tooltip(
              message: 'A reviewer is waited on',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.textMuted, width: 1.2),
                ),
              ),
            ),
          );
        }
        if (open > 0) {
          parts.add(
            count(
              Icons.forum_outlined,
              t.needs,
              '$open',
              '$open unresolved thread${open == 1 ? '' : 's'}',
            ),
          );
        }
    }
    if (unread > 0 && it.state == 'open') {
      parts.add(
        count(
          Icons.chat_bubble_outline,
          t.link,
          '$unread',
          '$unread new comment${unread == 1 ? '' : 's'}',
        ),
      );
    }
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 7,
    children: [
      Text(
        '#$number',
        style: theme.code(
          it == null
              ? t.link
              : it.draft && it.state == 'open'
              ? t.textMuted
              : itemColor(t, it),
          size: size,
        ),
      ),
      ...parts,
      if (onCleanUp != null)
        LinkText('Clean up…', size: size, onTap: onCleanUp),
    ],
  );
}
