import 'package:flutter/material.dart';

import 'agent_mark.dart';
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
  const new(
    this.chat,
    this.daemon, {
    required this.changes,
    required this.onChanges,
    required this.panel,
    required this.onPanel,
    super.key,
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
    final titleStyle = theme.ui(t.text, weight: FontWeight.w600);
    // The title and the model (a Codex model id is long) share what the
    // rest of the row leaves (it takes about 420 points), so a narrow
    // window cuts them short rather than overflow.
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth - 420;
        final title = (room * 0.6).clamp(80.0, 320.0);
        return _row(
          context,
          titleStyle,
          meta,
          modelName,
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
    String? modelName, {
    required double titleMax,
    required double modelMax,
  }) {
    final t = NushiTheme.of(context).t, theme = NushiTheme.of(context);
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
