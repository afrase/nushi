import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A chat's Pull request tab: the GitHub view's pull request (its
/// conversation, review threads, checks with a failed job's log, files,
/// replies and comments) for the chat's pull request; its comments are
/// seen while it shows. A comment, a thread or a failed check goes to the
/// chat's box as a reply card (Send to agent), several together; a bar
/// counts them, with the way back to the chat ([onChat]).
class PullTab extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChat,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChat;

  /// Adds [r] to the chat's box, unless it's there already.
  void _send(Reply r) {
    final now = chat.draft.replies.value;
    if (now.any((x) => x.quote == r.quote)) return;
    chat.draft.replies.value = [...now, r];
  }

  @override
  Widget build(BuildContext context) {
    final l = chat.pull;
    if (l == null) return const SizedBox.shrink();
    final ref = GitHubRef(host: l.host, repo: l.repo, number: l.number);
    return SendToAgent(
      onSend: _send,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder(
            valueListenable: chat.draft.replies,
            builder: (context, replies, _) => replies.isEmpty
                ? const SizedBox.shrink()
                : _Waiting(replies.length, onChat: onChat),
          ),
          Expanded(
            child: GitHubPullPane(
              key: ValueKey('${chat.id} ${l.id}'),
              daemon: daemon,
              ref: ref,
              inChat: true,
              onLoad: (p) => markPullSeen(chat.id, p),
            ),
          ),
        ],
      ),
    );
  }
}

/// "2 waiting in the chat's box", and Show the chat.
class _Waiting extends StatelessWidget {
  const new(this.n, {required this.onChat});

  final int n;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
      color: t.accentSoft,
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 14, color: t.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              n == 1
                  ? "1 reply waits in the chat's box, to send to the agent"
                  : "$n replies wait in the chat's box, to send to the agent",
              style: theme.ui(t.text, size: 12.5),
            ),
          ),
          Button(label: 'Show the chat', onPressed: onChat),
        ],
      ),
    );
  }
}
