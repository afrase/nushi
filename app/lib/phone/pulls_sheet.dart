import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/pull_link.dart' show addressOf;
import 'package:nushi/pull_rows.dart' show badgeColor, badgeCounts;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The phone's sheet of a chat's pull requests (ADR 0117): a row each, its
/// state's icon, title, `#n +adds −dels` and checks; a tap opens it on
/// GitHub ([onOpen]). No linking or unlinking on the phone.
Future<void> showPullsSheet(
  BuildContext context,
  Daemon daemon,
  ChatState chat, {
  required ValueChanged<String> onOpen,
}) {
  final items = GitHubItems.of(daemon);
  unawaited(items.ask([for (final l in chat.pulls) addressOf(l)]));
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NushiTheme.of(context).t.raised,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: items,
      builder: (context, _) {
        final theme = NushiTheme.of(context);
        final t = theme.t;
        // It scrolls where the phone is on its side.
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${chat.pulls.length} pull requests',
                    style: theme.ui(t.textMuted, weight: FontWeight.w600),
                  ),
                ),
                for (final l in chat.pulls)
                  _Row(l, items.look(addressOf(l)).item, onOpen: onOpen),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// One of the sheet's rows, 56 tall.
class _Row extends StatelessWidget {
  const new(this.link, this.item, {required this.onOpen});

  final GitHubLink link;
  final GitHubItem? item;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = item;
    final n = it == null ? null : badgeCounts(it);
    return Tap(
      onTap: () => onOpen(
        it?.url ?? 'https://${link.host}/${link.repo}/pull/${link.number}',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 56,
        child: Row(
          spacing: 10,
          children: [
            ItemIcon(it, pull: true, size: 17),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    it?.title ?? '${link.repo}#${link.number}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(
                      t.text,
                      size: 14.5,
                      weight: FontWeight.w500,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '#${link.number}',
                          style: theme.code(t.textMuted, size: 12),
                        ),
                        if (it != null &&
                            (it.additions > 0 || it.deletions > 0)) ...[
                          TextSpan(
                            text: ' +${it.additions}',
                            style: theme.code(t.done, size: 12),
                          ),
                          TextSpan(
                            text: ' −${it.deletions}',
                            style: theme.code(t.crashed, size: 12),
                          ),
                        ],
                        if (it != null && it.state != 'open')
                          TextSpan(
                            text: ' · ${stateWord(it)}',
                            style: theme.ui(t.textMuted, size: 12.5),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (n != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 5,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: badgeColor(t, n),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '${n.passed}/${n.total}',
                    style: theme.code(t.textSecondary, size: 12.5),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A link chip's card on the phone, as a sheet (there's no hover): the
/// card's inside, then Open on GitHub.
Future<void> showItemSheet(
  BuildContext context,
  Daemon daemon,
  GitHubAddress a, {
  required ValueChanged<String> onOpen,
}) {
  final items = GitHubItems.of(daemon)
    ..want(a, quiet: false, fresh: const Duration(minutes: 1));
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NushiTheme.of(context).t.raised,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ListenableBuilder(
          listenable: items,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              GitHubCardBody(a, items.look(a)),
              Button(
                label: 'Open on GitHub',
                icon: Icons.open_in_new,
                onPressed: () {
                  Navigator.pop(context);
                  onOpen(items.look(a).item?.url ?? a.url);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
