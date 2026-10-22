import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';

/// The chats, grouped by folder: the folder with the newest chat first, and
/// in each folder the newest chat first.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.daemon});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String? _starting; // the folder a chat is starting in

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
    final theme = Theme.of(context);
    final groups = <String, List<ChatState>>{};
    final byNewest = widget.daemon.chats.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    for (final c in byNewest) {
      (groups[c.folder] ??= []).add(c);
    }
    if (_starting != null) groups.putIfAbsent(_starting!, () => []);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _start(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New chat in a folder…'),
          ),
        ),
        for (final MapEntry(key: folder, value: chats) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: folder,
                    child: Text(
                      folder.split('/').last,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New chat here',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: _starting == null ? () => _start(folder) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (_starting == folder)
            const ListTile(
              dense: true,
              title: Text('Starting…'),
              trailing: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          for (final c in chats) _ChatTile(c, daemon: widget.daemon),
        ],
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile(this.chat, {required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) => ListTile(
      dense: true,
      selected: daemon.selectedId == chat.id,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: Text(
        chat.title.isEmpty ? 'New chat' : chat.title,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: chat.busy
          ? const SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : null,
      onTap: () => daemon.select(chat.id),
    ),
  );
}
