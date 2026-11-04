import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chats on a GitHub item, in its details: each a link to it (four
/// at most, then how many more), after [leading] (an issue's Start work).
class ItemChats extends StatelessWidget {
  const new(this.daemon, this.ref, {super.key, this.leading});

  final Daemon daemon;
  final GitHubRef ref;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chats = chatsOnItem(daemon, ref);
    if (chats.isEmpty && leading == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?leading,
        if (chats.isNotEmpty)
          Text('Chats:', style: theme.ui(t.textMuted, size: 12)),
        for (final c in chats.take(4))
          Tap(
            onTap: () => daemon.select(c.id),
            tooltip: 'Open the chat',
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AgentMark(c.agent, size: 13),
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
