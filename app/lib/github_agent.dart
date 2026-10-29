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
}) async {
  if (chat case final mine?) {
    await tryOrShow(context, () async {
      final me = await githubLogin(daemon, item.ref.host);
      for (final r in await replies()) {
        mine.draft.addReply(
          onPull(
            r,
            repo: item.ref.repo,
            number: item.ref.number,
            author: item.author,
            me: me,
          ),
        );
      }
    });
    return;
  }
  if (context.getInheritedWidgetOfExactType<SendToAgent>() case final here?) {
    await tryOrShow(
      context,
      () async => (await replies()).forEach(here.onSend),
    );
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
    final clones =
        githubFolders.value[(item.ref.host, item.ref.repo)] ?? const [];
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
    final me = await githubLogin(daemon, item.ref.host);
    for (final r in await replies()) {
      target.draft.addReply(
        onPull(
          r,
          repo: item.ref.repo,
          number: item.ref.number,
          author: item.author,
          me: me,
        ),
      );
    }
    daemon.select(target.id);
  });
}

/// Fix checks' cards: one per failed check (five at most), each with the
/// failing part of its job's log.
Future<List<Reply>> checkReplies(Daemon daemon, GitHubRef ref, GitHubPull p) =>
    Future.wait([
      for (final c in p.checks.where((c) => c.failed).take(5))
        checkReply(daemon, ref, c),
    ]);

/// Address comments' cards: one per thread not resolved, of [picked] when
/// given.
List<Reply> threadReplies(GitHubPull p, [List<String>? picked]) => [
  for (final x in p.threads)
    if (!x.resolved && (picked == null || picked.contains(x.id)))
      threadReply(x),
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
                  AgentMark(c.agent, color: t.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.title.isEmpty ? 'New chat' : c.title,
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

/// Asks which of a pull request's threads not resolved to address (all
/// picked to start with); null when cancelled.
Future<List<String>?> pickThreads(BuildContext context, GitHubPull pull) =>
    showDialog<List<String>>(
      context: context,
      builder: (_) => _PickThreads(pull),
    );

class _PickThreads extends StatefulWidget {
  const new(this.pull);

  final GitHubPull pull;

  @override
  State<_PickThreads> createState() => _PickThreadsState();
}

class _PickThreadsState extends State<_PickThreads> {
  late final List<GitHubThread> _threads = [
    for (final x in widget.pull.threads)
      if (!x.resolved) x,
  ];
  late final Set<String> _picked = {for (final x in _threads) x.id};

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return nushiDialog(
      'Address which threads?',
      SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final x in _threads)
              Tap(
                onTap: () => setState(
                  () => _picked.contains(x.id)
                      ? _picked.remove(x.id)
                      : _picked.add(x.id),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Icon(
                      _picked.contains(x.id)
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: t.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${x.path}:${x.outdated ? x.originalLine : x.line}',
                      style: theme.code(t.textSecondary, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        x.comments.isEmpty ? '' : x.comments.first.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text, size: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: 'Put in the box',
          kind: ButtonKind.primary,
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final x in _threads)
                    if (_picked.contains(x.id)) x.id,
                ]),
        ),
      ],
    );
  }
}
