import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = chat.pull;
    if (l == null) return const SizedBox.shrink();
    final ref = GitHubRef(host: l.host, repo: l.repo, number: l.number);
    final source = ChatPull.of(daemon, chat);
    // A toast says what went in.
    Future<void> send(
      ScaffoldMessengerState? toast,
      double side,
      List<Reply> replies,
      String what,
    ) async {
      final added = await putReplies(
        daemon,
        chat,
        ref,
        author: source.pull?.item.author ?? '',
        replies: replies,
      );
      if (replies.isEmpty) return;
      toast
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            // 520 wide at most, centred, above the bar that counts the
            // cards.
            margin: EdgeInsets.fromLTRB(side, 0, side, 64),
            content: Text(sentWords(replies.length, added, what)),
            action: SnackBarAction(label: 'Go to chat', onPressed: onChat),
          ),
        );
    }

    final side = ((MediaQuery.sizeOf(context).width - 520) / 2).clamp(
      16.0,
      double.infinity,
    );
    return SendToAgent(
      box: chat.draft.replies,
      onSend: (r, what) =>
          send(ScaffoldMessenger.maybeOf(context), side, r, what).ignore(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GitHubPullPane(
              key: ValueKey('${chat.id} ${l.id}'),
              daemon: daemon,
              ref: ref,
              source: source,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: chat.draft.replies,
            builder: (context, replies, _) => replies.isEmpty
                ? const SizedBox.shrink()
                : RepliesWaiting(replies.length, onChat: onChat),
          ),
        ],
      ),
    );
  }
}

/// What a toast says of [sent] cards put in the chat's box, [added] of
/// them new there: "Added to the chat's box: CI / rubocop", "Added 6 to
/// the chat's box", "Added 4 to the chat's box; 2 were there already",
/// "Already in the chat's box: CI / rubocop".
String sentWords(int sent, int added, String what) {
  final there = sent - added;
  if (sent == 1 || (added == 0 && what.isNotEmpty)) {
    return added > 0
        ? "Added to the chat's box: $what"
        : "Already in the chat's box: $what";
  }
  if (added == 0) return "All $sent are in the chat's box already";
  final also = there == 0
      ? ''
      : '; $there ${there == 1 ? 'was' : 'were'} there already';
  return "Added $added to the chat's box$also";
}

/// "2 waiting in the chat's box", and Go to chat: under the Pull request
/// tab and over the Changes view while cards they sent wait there.
class RepliesWaiting extends StatelessWidget {
  const new(this.n, {required this.onChat, super.key});

  final int n;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NushiTheme.gutter,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: t.accentSoft,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 14, color: t.text),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$n',
                    style: theme.ui(
                      t.text,
                      size: 12.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " waiting in the chat's box. They go with your next "
                        'message.',
                  ),
                ],
              ),
              style: theme.ui(t.text, size: 12.5),
            ),
          ),
          Button(label: 'Go to chat', onPressed: onChat),
        ],
      ),
    );
  }
}
