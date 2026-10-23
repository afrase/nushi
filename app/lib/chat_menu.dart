import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'menu.dart';
import 'terminals.dart';
import 'theme/theme.dart';
import 'widgets.dart';
import 'worktree.dart';
import 'inline_edit.dart';

/// The chat's menu: Rename, Archive or Unarchive, MCP servers…, Delete….
List<MenuEntry> chatMenu(
  BuildContext context,
  ChatState chat,
  Daemon daemon, {
  required VoidCallback onRename,
}) => [
  MenuEntry('Rename', onPick: onRename),
  MenuEntry(
    chat.archived ? 'Unarchive' : 'Archive',
    onPick: () => tryOrShow(
      context,
      () => daemon.client.archiveChat(
        ArchiveChatRequest(chatId: chat.id, archived: !chat.archived),
      ),
    ),
  ),
  MenuEntry('MCP servers…', onPick: () => daemon.showMcp(chat.folder)),
  MenuEntry(
    'Delete…',
    onPick: () => showDialog<void>(
      context: context,
      builder: (_) => _DeleteDialog(chat, daemon),
    ),
  ),
];

/// Asks before deleting a chat, listing what goes, then deletes it.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late final _plan = widget.daemon.client
      .planDeleteChat(PlanDeleteChatRequest(chatId: widget.chat.id))
      .then((p) {
        _worktrees = p.worktrees;
        for (final w in _worktrees) {
          _choices[w.worktree.path] = WorktreeChoices.defaults(w);
        }
        return p;
      });
  var _worktrees = <WorktreePlan>[];
  final _choices = <String, (bool, bool)>{}; // by path: remove, delete branch
  bool _deleting = false;
  String _error = '';

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await _plan;
      final choices = [
        for (final w in _worktrees)
          WorktreeChoices.choice(
            w,
            remove: _choices[w.worktree.path]!.$1,
            branch: _choices[w.worktree.path]!.$2,
          ),
      ];
      await widget.daemon.client.deleteChat(
        DeleteChatRequest(chatId: widget.chat.id, worktrees: choices),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final name = widget.chat.agentName;
    final title = widget.chat.title.isEmpty
        ? 'this chat'
        : '“${widget.chat.title}”';
    Widget line(String text, {bool mono = false}) => Padding(
      padding: EdgeInsets.only(top: mono ? 2 : 8, left: mono ? 10 : 0),
      child: Text(
        text,
        style: mono
            ? theme.code(t.textMuted, size: 11.5)
            : theme.ui(t.textSecondary),
      ),
    );
    Iterable<Widget> sessions(PlanDeleteChatResponse p) => [
      for (final s in p.sessions) ...[
        line(s.sessionId, mono: true),
        line(
          s.folder == p.scratchFolder
              ? '  in its scratch folder'
              : '  in ${tildePath(s.folder)}',
          mono: true,
        ),
      ],
    ];
    return nushiDialog(
      'Delete $title?',
      FutureBuilder(
        future: _plan,
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) {
            return line(
              snap.hasError ? '${snap.error}' : 'Checking what goes…',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line('This deletes, for good:'),
              // claude --resume: Claude's CLI, the only agent so far.
              if (p.deletesHistory) ...[
                line(
                  p.sessions.length == 1
                      ? '• $name’s history of the chat, so claude --resume '
                            'no longer finds it:'
                      : '• $name’s history of its ${p.sessions.length} '
                            'sessions (it moved), so claude --resume no '
                            'longer finds them:',
                ),
                ...sessions(p),
              ],
              if (p.scratchFolder.isNotEmpty) ...[
                line('• Its scratch folder, with any files made there:'),
                line(tildePath(p.scratchFolder), mono: true),
              ],
              line('• Nushi’s record of the chat.'),
              if (p.terminals.isNotEmpty) ...[
                line('• Its terminals, and what still runs in them:'),
                for (final term in p.terminals)
                  line(terminalName(term), mono: true),
              ],
              for (final (i, w) in _worktrees.indexed) ...[
                if (i > 0 || widget.chat.worktree == null)
                  line('A worktree it ran in before it moved:')
                else
                  const SizedBox(height: 12),
                WorktreeChoices(
                  plan: w,
                  remove: _choices[w.worktree.path]!.$1,
                  branch: _choices[w.worktree.path]!.$2,
                  onChanged: (remove, branch) => setState(
                    () => _choices[w.worktree.path] = (remove, branch),
                  ),
                ),
              ],
              if (!p.deletesHistory) ...[
                line(
                  '$name can’t delete its history from here, so it '
                  'stays: claude --resume still opens',
                ),
                ...sessions(p),
              ],
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error, style: theme.ui(t.crashed)),
                ),
            ],
          );
        },
      ),
      [
        Button(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          onPressed: () => Navigator.pop(context),
        ),
        FutureBuilder(
          future: _plan,
          builder: (context, snap) => Button(
            label: _deleting ? 'Deleting…' : 'Delete',
            kind: ButtonKind.danger,
            autofocus: true,
            onPressed: snap.hasData && !_deleting ? _delete : null,
          ),
        ),
      ],
    );
  }
}

/// Renames a chat in place (see InlineEdit); [onDone] when it's over.
class RenameField extends StatelessWidget {
  const RenameField({
    super.key,
    required this.chat,
    required this.daemon,
    required this.onDone,
    this.style,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onDone;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InlineEdit(
    text: chat.title,
    style: style,
    onDone: (title) {
      if (title != null && title != chat.title) {
        tryOrShow(
          context,
          () => daemon.client.renameChat(
            RenameChatRequest(chatId: chat.id, title: title),
          ),
        );
      }
      onDone();
    },
  );
}
