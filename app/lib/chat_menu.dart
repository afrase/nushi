import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'worktree.dart';

/// Runs a call, showing its error, if any, in a snack bar.
Future<void> tryOrShow(
  BuildContext context,
  Future<void> Function() call,
) async {
  try {
    await call();
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// The chat's menu at [at] (global): Rename, Archive or Unarchive, Delete.
Future<void> showChatMenu(
  BuildContext context,
  Offset at,
  ChatState chat,
  Daemon daemon, {
  required VoidCallback onRename,
}) async {
  final theme = NushiTheme.of(context);
  // An older daemon lacks these: they show, unavailable.
  PopupMenuItem<String> item(String value, String label, bool can) =>
      PopupMenuItem(
        value: value,
        height: 30,
        enabled: can,
        child: Text(
          label,
          style: theme.ui(can ? theme.t.text : theme.t.textMuted),
        ),
      );
  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      item('rename', 'Rename', daemon.canManageChats),
      item(
        'archive',
        chat.archived ? 'Unarchive' : 'Archive',
        daemon.canManageChats,
      ),
      item('delete', 'Delete…', daemon.canDeleteChats),
    ],
  );
  if (!context.mounted) return;
  switch (picked) {
    case 'rename':
      onRename();
    case 'archive':
      await tryOrShow(
        context,
        () => daemon.archiveChat(chat.id, archived: !chat.archived),
      );
    case 'delete':
      await showDialog<void>(
        context: context,
        builder: (_) => _DeleteDialog(chat, daemon),
      );
  }
}

/// Asks before deleting a chat, listing what goes, then deletes it.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog(this.chat, this.daemon);

  final ChatState chat;
  final Daemon daemon;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  late final _plan = widget.daemon.planDeleteChat(widget.chat.id).then((p) {
    if (p.hasWorktree()) {
      final (remove, branch) = WorktreeChoices.defaults(p);
      _remove = remove;
      _branch = branch;
    }
    return p;
  });
  bool _remove = false, _branch = false; // the worktree, its branch
  bool _deleting = false;
  String _error = '';

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      final req = DeleteChatRequest(chatId: widget.chat.id);
      final p = await _plan;
      await widget.daemon.deleteChat(
        p.hasWorktree()
            ? WorktreeChoices.request(req, p, remove: _remove, branch: _branch)
            : req,
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
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
    return AlertDialog(
      backgroundColor: t.raised,
      title: Text(
        'Delete $title?',
        style: theme.ui(t.text, size: 15, weight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 460,
        child: FutureBuilder(
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
                if (p.deletesHistory) ...[
                  line(
                    p.sessions.length == 1
                        ? '• Claude’s history of the chat, so claude --resume '
                              'no longer finds it:'
                        : '• Claude’s history of its ${p.sessions.length} '
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
                if (p.hasWorktree()) ...[
                  const SizedBox(height: 12),
                  WorktreeChoices(
                    plan: p,
                    remove: _remove,
                    branch: _branch,
                    onChanged: (remove, branch) => setState(() {
                      _remove = remove;
                      _branch = branch;
                    }),
                  ),
                ],
                if (!p.deletesHistory) ...[
                  line(
                    'Claude can’t delete its history from here, so it '
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: theme.ui(t.text)),
        ),
        FutureBuilder(
          future: _plan,
          builder: (context, snap) => TextButton(
            autofocus: true,
            onPressed: snap.hasData && !_deleting ? _delete : null,
            child: Text(
              _deleting ? 'Deleting…' : 'Delete',
              style: theme.ui(snap.hasData ? t.crashed : t.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renames a chat in place: Enter or leaving the box saves, Escape cancels.
class RenameField extends StatefulWidget {
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
  State<RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<RenameField> {
  late final _text = TextEditingController(text: widget.chat.title);
  final _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(save: true);
    });
    // Focusing the box puts the cursor at the end; select all after it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _finish({required bool save}) {
    if (_done) return;
    _done = true;
    final title = _text.text.trim();
    if (save && title != widget.chat.title) {
      tryOrShow(context, () => widget.daemon.renameChat(widget.chat.id, title));
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _finish(save: false),
      },
      child: TextField(
        controller: _text,
        focusNode: _focus,
        autofocus: true,
        style: widget.style ?? theme.ui(theme.t.text),
        onSubmitted: (_) => _finish(save: true),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: theme.t.focus),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: theme.t.focus, width: 1.5),
          ),
        ),
      ),
    );
  }
}
