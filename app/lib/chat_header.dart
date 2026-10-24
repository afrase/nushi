import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'menu.dart';
import 'status.dart';
import 'terminal_panel.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The chat's header: its title (double-click renames it), the agent, its
/// model and status, the folder while the details panel is hidden, the
/// Chat | Changes switch, the terminal's and the panel's buttons and the
/// chat's menu.
class ChatHeader extends StatefulWidget {
  const ChatHeader(
    this.chat,
    this.daemon, {
    super.key,
    required this.changes,
    required this.onChanges,
    required this.panel,
    required this.onPanel,
  });

  final ChatState chat;
  final Daemon daemon;
  final bool changes;
  final ValueChanged<bool> onChanges;
  final bool panel; // the details panel shows, with the folder in it
  final VoidCallback? onPanel; // shows or hides it; null when it can't show

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  bool _renaming = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final chat = widget.chat;
    final meta = theme.ui(t.textSecondary, size: 12);
    final model = chat.config.where((o) => o.category == 'model').firstOrNull;
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    final titleStyle = theme.ui(t.text, size: 13, weight: FontWeight.w600);
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
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
          const SizedBox(width: 14),
          _Monogram(chat),
          const SizedBox(width: 8),
          Text(
            chat.agentName,
            style: theme.ui(t.text, size: 12, weight: FontWeight.w500),
          ),
          if (modelName != null) ...[
            const SizedBox(width: 10),
            Text(modelName, style: meta),
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
          Segmented(
            value: widget.changes,
            segments: const [(false, 'Chat'), (true, 'Changes')],
            onChanged: widget.onChanges,
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
          Menu(
            tooltip: 'Chat menu',
            entries: chatMenu(
              context,
              chat,
              widget.daemon,
              onRename: () => setState(() => _renaming = true),
            ),
            child: Icon(Icons.more_horiz, size: 16, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The agent's monogram: its letter on its color (Claude's, or the accent).
class _Monogram extends StatelessWidget {
  const _Monogram(this.chat);

  final ChatState chat;

  static const size = 16.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: chat.agent == 'claude' ? t.claude : t.accent,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Text(
        chat.agentName[0],
        style: TextStyle(
          fontFamily: NushiTheme.uiFont,
          fontSize: size * 0.64,
          height: 1,
          fontWeight: FontWeight.w600,
          color: t.monogramText,
        ),
      ),
    );
  }
}
