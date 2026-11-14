import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_agent.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_text.dart' show readablePad;
import 'package:nushi/menu.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_rows.dart';
import 'package:nushi/pull_states.dart';
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
    final source = ChatPull.of(daemon, chat);
    return ListenableBuilder(
      listenable: source,
      builder: (context, _) => _build(context, source),
    );
  }

  Widget _build(BuildContext context, ChatPull source) {
    final l = source.current;
    if (l == null) return const SizedBox.shrink();
    final ref = l.asRef;
    final links = source.links;
    // What went in shows on its rows ("In the box ✓") and in the bar at
    // the foot, with its Go to chat; a toast says only that nothing new
    // did, which neither of those would show.
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
      toast?.hideCurrentSnackBar();
      if (added > 0) return;
      showToast(
        toast,
        sentWords(replies.length, added, what),
        // 520 wide at most, centred, above the bar that counts the cards.
        margin: EdgeInsets.fromLTRB(side, 0, side, 64),
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
          if (links.length >= 2) _Picker(source, l, links),
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

/// With several pull requests (ADR 0117), the tab's head starts with a
/// menu field of their rows; the one picked is remembered for the chat.
class _Picker extends StatelessWidget {
  const new(this.cp, this.shown, this.links);

  final ChatPull cp;
  final GitHubLink shown;
  final List<GitHubLink> links;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = cp.itemOf(shown);
    // Over the pane's column ([readablePad]), where its head starts.
    return LayoutBuilder(
      builder: (context, box) => Padding(
        padding: EdgeInsets.fromLTRB(readablePad(box.maxWidth), 12, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: MenuField(
            compact: true,
            tooltip: "The chat's pull requests",
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  ItemIcon(it, pull: true, size: 13),
                  Text(
                    '#${shown.number}',
                    style: theme.code(t.textSecondary, size: 12),
                  ),
                  Flexible(
                    child: Text(
                      it?.title ?? shown.repo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.text, size: 12),
                    ),
                  ),
                ],
              ),
            ),
            entries: [
              for (final l in links)
                MenuEntry.row(
                  (close) => SizedBox(
                    width: 340,
                    child: PullRow(cp, l, onShow: close, menu: false),
                  ),
                ),
            ],
          ),
        ),
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
    // A banner set in from the pane's edges, as the blocks around it are
    // (ADR 0111): the accent's soft fill, no line.
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(NushiTheme.gutter - 8, 6, 6, 6),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(NushiTheme.control),
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
                    style: theme.ui(t.text, size: 12, weight: FontWeight.w600),
                  ),
                  const TextSpan(
                    text:
                        " waiting in the chat's box. They go with your next "
                        'message.',
                  ),
                ],
              ),
              style: theme.ui(t.text, size: 12),
            ),
          ),
          Button(label: 'Go to chat', onPressed: onChat),
        ],
      ),
    );
  }
}
