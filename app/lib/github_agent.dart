import 'package:flutter/material.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Fix checks and Address comments: a message for an agent about [item]
/// (the daemon writes it: [kind] "fix_checks" or "address_comments", the
/// [threads] picked, else all not resolved), put in a chat's box to read,
/// change and send; never sent here. The chat is the item's (the one
/// picked, when it has several); with none, Start work makes one first.
Future<void> toAgent(
  BuildContext context,
  Daemon daemon,
  GitHubItem item, {
  required String kind,
  List<String> threads = const [],
}) async {
  var chats = chatsOnItem(daemon, item.ref);
  ChatState? chat;
  if (chats.length == 1) {
    chat = chats.first;
  } else if (chats.length > 1) {
    chat = await showDialog<ChatState>(
      context: context,
      builder: (_) => _PickChat(chats),
    );
    if (chat == null) return;
  }
  if (!context.mounted) return;
  if (chat == null) {
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
    chat = chats.first;
  }
  final target = chat;
  if (!context.mounted) return;
  await tryOrShow(context, () async {
    final r = await daemon.client.getGitHubPrompt(
      GetGitHubPromptRequest(ref: item.ref, kind: kind, threads: threads),
    );
    final box = target.draft.text;
    box.text = box.text.trim().isEmpty
        ? r.text
        : '${box.text.trimRight()}\n\n${r.text}';
    daemon.select(target.id);
  });
}

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
      [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context),
        ),
      ],
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
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context),
        ),
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
