import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'chat_menu.dart';
import 'daemon.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The chats, grouped by folder: the folder with the newest chat first, and
/// in each folder the newest chat first. Archived chats are in a collapsed
/// group at the bottom.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.daemon});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? _starting; // the folder a chat is starting in
  bool _showArchived = false;

  Future<void> _start(String? folder) async {
    folder ??= await getDirectoryPath(confirmButtonText: 'Start chat');
    if (folder == null) return;
    setState(() => _starting = folder);
    try {
      await widget.daemon.startChat(folder);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final groups = <String, List<ChatState>>{};
    final byNewest = widget.daemon.chats.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final archived = [
      for (final c in byNewest)
        if (c.archived) c,
    ];
    for (final c in byNewest) {
      if (!c.archived) (groups[c.folder] ??= []).add(c);
    }
    if (_starting != null) groups.putIfAbsent(_starting!, () => []);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(right: BorderSide(color: t.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Button(
              label: 'New chat in a folder…',
              icon: Icons.add,
              kind: ButtonKind.primary,
              height: 28,
              onPressed: _starting == null ? () => _start(null) : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 10),
              children: [
                for (final MapEntry(key: folder, value: chats)
                    in groups.entries) ...[
                  _FolderHeader(
                    folder,
                    onNew: _starting == null ? () => _start(folder) : null,
                  ),
                  if (_starting == folder)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                      child: Text(
                        'Starting…',
                        style: theme.ui(t.textMuted, size: 12),
                      ),
                    ),
                  for (final c in chats) _ChatRow(c, daemon: widget.daemon),
                ],
                if (archived.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(NushiTheme.control),
                      onTap: () =>
                          setState(() => _showArchived = !_showArchived),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showArchived
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 16,
                              color: t.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Archived  ${archived.length}',
                              style: theme.ui(t.textSecondary, size: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showArchived)
                    for (final c in archived)
                      _ChatRow(c, daemon: widget.daemon),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader(this.folder, {required this.onNew});

  final String folder;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, weight: FontWeight.w600),
                ),
                Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.textMuted, size: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'New chat here',
            iconSize: 16,
            color: t.textSecondary,
            visualDensity: VisualDensity.compact,
            onPressed: onNew,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// A chat in the list: click opens it, double-click renames it, and a
/// right-click opens its menu.
class _ChatRow extends StatefulWidget {
  const _ChatRow(this.chat, {required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _renaming = false;
  DateTime _lastTap = DateTime(0);

  void _tap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < kDoubleTapTimeout) {
      setState(() => _renaming = true);
    }
    _lastTap = now;
    widget.daemon.select(widget.chat.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
    final daemon = widget.daemon;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Material(
          color: daemon.selectedId == chat.id ? t.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(NushiTheme.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(NushiTheme.control),
            onTap: _tap,
            onSecondaryTapUp: (d) => showChatMenu(
              context,
              d.globalPosition,
              chat,
              daemon,
              onRename: () => setState(() => _renaming = true),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: _renaming ? 1 : 5,
              ),
              child: Row(
                children: [
                  ChatDot(chat: chat),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _renaming
                        ? RenameField(
                            chat: chat,
                            daemon: daemon,
                            onDone: () => setState(() => _renaming = false),
                          )
                        : Text(
                            chat.title.isEmpty ? 'New chat' : chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.ui(
                              chat.archived ? t.textSecondary : t.text,
                            ),
                          ),
                  ),
                  if (chat.waiting)
                    Text('needs you', style: theme.ui(t.needs, size: 11.5)),
                  if (chat.archived)
                    Text(
                      chat.folder.split('/').last,
                      style: theme.ui(t.textMuted, size: 11.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
