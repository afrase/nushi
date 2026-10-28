import 'package:flutter/material.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/status.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What shows in a chat's place: its transcript, its changes, or its pull
/// request.
enum ChatTab { chat, changes, pull }

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the folder while the details panel is hidden, the
/// files it wrote that preview (Artifacts, while there are some, counting
/// those pinned or recent), the
/// Chat | Changes (| Pull request, while it has one) switch, the
/// terminal's and the panel's buttons and the chat's menu.
class ChatHeader extends StatefulWidget {
  const new(
    this.chat,
    this.daemon, {
    required this.tab,
    required this.onTab,
    required this.panel,
    required this.onPanel,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final ChatTab tab;
  final ValueChanged<ChatTab> onTab;
  final bool panel; // the details panel shows, with the folder in it
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  bool _renaming = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.config.where((o) => o.category == 'model').firstOrNull;
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    final titleStyle = theme.ui(t.text, weight: FontWeight.w600);
    final files = widget.daemon.daemonApi >= previewApi
        ? chatFiles(chat.items)
        : const <String>[];
    // The title and the model (a Codex model id is long) share what the
    // rest of the row leaves (it takes about 420 points, Artifacts 95
    // more, the Pull request tab 85), so a narrow window cuts them short
    // rather than overflow; with Artifacts or the tab, the title gets
    // shorter still (at 720 points wide it would overflow).
    return LayoutBuilder(
      builder: (context, box) {
        final more = (files.isEmpty ? 0 : 95) + (chat.pull == null ? 0 : 85);
        final room = box.maxWidth - 420 - more;
        final title = (room * 0.6).clamp(more == 0 ? 80.0 : 40.0, 320.0);
        return _row(
          context,
          titleStyle,
          meta,
          modelName,
          files,
          titleMax: title,
          modelMax: (room - title).clamp(40.0, 200.0),
        );
      },
    );
  }

  Widget _row(
    BuildContext context,
    TextStyle titleStyle,
    TextStyle meta,
    String? modelName,
    List<String> files, {
    required double titleMax,
    required double modelMax,
  }) {
    final t = NushiTheme.of(context).t;
    final theme = NushiTheme.of(context);
    final chat = widget.chat;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: titleMax),
            child: _renaming
                ? RenameField(
                    chat: chat,
                    daemon: widget.daemon,
                    style: titleStyle,
                    onDone: () => setState(() => _renaming = false),
                  )
                : GestureDetector(
                    onDoubleTap: () => setState(() => _renaming = true),
                    child: Text(
                      chat.title.isEmpty ? 'New chat' : chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
          ),
          if (chat.jiraKey.isNotEmpty) ...[
            const SizedBox(width: 10),
            LinkText(
              chat.jiraKey,
              mono: true,
              size: 12,
              tooltip: 'Show ${chat.jiraKey} in Jira',
              onTap: () =>
                  showIssue(widget.daemon, chat.jiraSite, chat.jiraKey),
            ),
          ],
          if (chat.github case final link?) ...[
            const SizedBox(width: 10),
            GitHubChip(
              key: ValueKey(link.id),
              daemon: widget.daemon,
              link: link,
            ),
          ],
          const SizedBox(width: 14),
          AgentMark(chat.agent, size: 16, color: t.text),
          const SizedBox(width: 8),
          Text(
            chat.agentName,
            style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
          ),
          if (modelName != null) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: modelMax),
              child: Text(
                modelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
          ],
          const SizedBox(width: 10),
          if (chat.archived)
            Text('archived', style: meta)
          else ...[
            ChatDot(chat: chat),
            const SizedBox(width: 5),
            ChatStatusWord(chat, style: meta),
          ],
          const SizedBox(width: 16),
          Expanded(
            // The folder, unless the panel has it or there's no room.
            child: LayoutBuilder(
              builder: (context, box) => widget.panel || box.maxWidth < 90
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: FolderButton(chat: chat, daemon: widget.daemon),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          if (files.isNotEmpty) ...[
            FilesMenu(
              chat: chat,
              tooltip: (a) =>
                  'Artifacts: the files this chat wrote, to preview '
                  '(${a.pinned.length + a.recent.length} pinned or recent, '
                  '${files.length} in all)',
              label: (a) => Text.rich(
                TextSpan(
                  text: 'Artifacts',
                  children: [
                    TextSpan(
                      text: ' ${a.pinned.length + a.recent.length}',
                      style: TextStyle(color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Segmented(
            value: widget.tab,
            segments: [
              (ChatTab.chat, 'Chat'),
              (ChatTab.changes, 'Changes'),
              if (chat.pull != null) (ChatTab.pull, 'Pull request'),
            ],
            onChanged: widget.onTab,
          ),
          const SizedBox(width: 4),
          TerminalButton(chat: chat, daemon: widget.daemon),
          IconTap(
            Icons.view_sidebar_outlined,
            tooltip: widget.onPanel == null
                ? 'The window is too narrow'
                : widget.panel
                ? 'Hide details'
                : 'Show details',
            color: widget.panel ? t.text : t.textSecondary,
            onTap: widget.onPanel,
          ),
          MenuIcon(
            Icons.more_horiz,
            tooltip: 'Chat menu',
            entries: chatMenu(
              context,
              chat,
              widget.daemon,
              onRename: () => setState(() => _renaming = true),
            ),
          ),
        ],
      ),
    );
  }
}
