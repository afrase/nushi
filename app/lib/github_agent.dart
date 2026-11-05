import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Fix checks and Address comments: [replies] (one reply card per failed
/// check or thread, as the Pull request tab's Send to agent makes them)
/// put in a chat's box, to go with the user's next message; never sent
/// here. In a chat's Pull request tab, that chat's box (its bar counts
/// them); else the item's chat (the one picked, when it has several),
/// and with none, Start work makes one first; [chat], that chat (the PR
/// widget's).
Future<void> toAgent(
  BuildContext context,
  Daemon daemon,
  GitHubItem item, {
  required Future<List<Reply>> Function() replies,
  ChatState? chat,
  String what = '',
}) async {
  if (chat case final mine?) {
    await tryOrShow(context, () async {
      await putReplies(
        daemon,
        mine,
        item.ref,
        author: item.author,
        replies: await replies(),
      );
    });
    return;
  }
  if (context.getInheritedWidgetOfExactType<SendToAgent>() case final here?) {
    await tryOrShow(context, () async => here.onSend(await replies(), what));
    return;
  }
  var chats = chatsOnItem(daemon, item.ref);
  ChatState? picked;
  if (chats.length == 1) {
    picked = chats.first;
  } else if (chats.length > 1) {
    picked = await showDialog<ChatState>(
      context: context,
      builder: (_) => _PickChat(chats),
    );
    if (picked == null) return;
  }
  if (!context.mounted) return;
  if (picked == null) {
    final clones = clonesOf(item.ref);
    await startOn(
      context,
      daemon,
      item,
      clones.length == 1 ? clones.first : null,
    );
    chats = chatsOnItem(daemon, item.ref);
    if (chats.isEmpty) return; // not started
    picked = chats.first;
  }
  final target = picked;
  if (!context.mounted) return;
  await tryOrShow(context, () async {
    await putReplies(
      daemon,
      target,
      item.ref,
      author: item.author,
      replies: await replies(),
    );
    daemon.select(target.id);
  });
}

/// Puts [replies] in [chat]'s box as cards on pull request [ref] (by
/// [author]; each says what it is, on which pull request, and whose that
/// is); how many of them were new there.
Future<int> putReplies(
  Daemon daemon,
  ChatState chat,
  GitHubRef ref, {
  required String author,
  required List<Reply> replies,
}) async {
  final me = await githubLogin(daemon, ref.host);
  var added = 0;
  for (final r in replies) {
    final card = onPull(
      r,
      repo: ref.repo,
      number: ref.number,
      author: author,
      me: me,
    );
    // A card for the same item is in the box already, perhaps with what
    // it asked before the settings changed: one card per item.
    if (inBox(chat.draft.replies.value, card)) continue;
    if (chat.draft.addReply(card)) added++;
  }
  return added;
}

/// Fix checks' cards: one per failed check (five at most), each with the
/// failing part of its job's log.
Future<List<Reply>> checkReplies(Daemon daemon, GitHubRef ref, GitHubPull p) =>
    Future.wait([
      for (final c in p.checks.where((c) => c.failed).take(5))
        checkReply(daemon, ref, c),
    ]);

/// Address comments' cards: one per thread not resolved.
List<Reply> threadReplies(GitHubPull p) => [
  for (final x in p.threads)
    if (!x.resolved) threadReply(x),
];

class _PickChat extends StatelessWidget {
  const new(this.chats);

  final List<ChatState> chats;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      'Which chat?',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in chats)
            Tap(
              onTap: () => Navigator.pop(context, c),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  AgentMark(c.agent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.shownTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.text),
                    ),
                  ),
                  Text(
                    folderParts(c.folder).$1,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      [Button(label: 'Cancel', onPressed: () => Navigator.pop(context))],
    );
  }
}
