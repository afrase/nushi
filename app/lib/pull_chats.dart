import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chats on the pull request, in the GitHub view: each a link to it.
class PullChats extends StatelessWidget {
  const new(this.daemon, this.pull, {super.key});

  final Daemon daemon;
  final GitHubPull pull;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chats = chatsOnItem(daemon, pull.item.ref);
    if (chats.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Chats:', style: theme.ui(t.textMuted, size: 12)),
        for (final c in chats.take(4))
          Tap(
            onTap: () => daemon.select(c.id),
            tooltip: 'Open the chat',
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgentMark(c.agent, size: 13, color: t.textSecondary),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    c.shownTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.link, size: 12),
                  ),
                ),
              ],
            ),
          ),
        if (chats.length > 4)
          Text(
            '+${chats.length - 4} chats',
            style: theme.ui(t.textMuted, size: 12),
          ),
      ],
    );
  }
}
