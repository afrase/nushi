import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Rename branch…, from the Environment card of a worktree chat; true
/// once renamed.
Future<bool> renameBranch(
  BuildContext context,
  ChatState chat,
  Daemon daemon,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => RenameBranchDialog(chat: chat, daemon: daemon),
    ) ??
    false;

/// The branch's name to edit. The daemon checks it as git does, and refuses
/// a branch that's on a remote (renamed here, it would no longer match
/// it); the dialog shows why. The worktree's folder keeps its name.
class RenameBranchDialog extends StatefulWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<RenameBranchDialog> createState() => _RenameBranchDialogState();
}

class _RenameBranchDialogState extends State<RenameBranchDialog> {
  late final Worktree _wt = widget.chat.worktree!;
  late final _name = TextEditingController(text: _wt.branch)
    ..selection = TextSelection(baseOffset: 0, extentOffset: _wt.branch.length);
  String? _error;
  bool _renaming = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _new => _name.text.trim();

  bool get _can => !_renaming && _new.isNotEmpty && _new != _wt.branch;

  Future<void> _rename() async {
    if (!_can) return;
    setState(() => _renaming = true);
    try {
      await widget.daemon.client.renameBranch(
        RenameBranchRequest(chatId: widget.chat.id, branch: _new),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _renaming = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final folder = _wt.path.split('/').last;
    return nushiDialog(
      'Rename branch',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            style: theme.code(t.text),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _rename(),
          ),
          if (_error case final e?)
            Text(e, style: theme.ui(t.crashed, size: 12)),
          Text(
            'Its worktree stays in .worktrees/$folder, and the chat’s title '
            'no longer names it.',
            style: theme.ui(t.textMuted, size: 12),
          ),
        ],
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(
          label: 'Rename',
          kind: ButtonKind.primary,
          onPressed: _can ? _rename : null,
        ),
      ],
    );
  }
}
