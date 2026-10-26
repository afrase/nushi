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
