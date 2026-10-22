import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat.dart';
import 'daemon.dart';
import 'theme/theme.dart';

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

/// The chat's menu at [at] (global): Rename, Archive or Unarchive, Remove.
Future<void> showChatMenu(
  BuildContext context,
  Offset at,
  ChatState chat,
  Daemon daemon, {
  required VoidCallback onRename,
}) async {
  final theme = NushiTheme.of(context);
  // An older daemon lacks these: they show, unavailable.
  final can = daemon.canManageChats;
  PopupMenuItem<String> item(String value, String label) => PopupMenuItem(
    value: value,
    height: 30,
    enabled: can,
    child: Text(label, style: theme.ui(can ? theme.t.text : theme.t.textMuted)),
  );
  final picked = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
    items: [
      item('rename', 'Rename'),
      item('archive', chat.archived ? 'Unarchive' : 'Archive'),
      item('remove', 'Remove…'),
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
    case 'remove':
      if (await _confirmRemove(context, chat) && context.mounted) {
        await tryOrShow(context, () => daemon.removeChat(chat.id));
      }
  }
}

Future<bool> _confirmRemove(BuildContext context, ChatState chat) async {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final title = chat.title.isEmpty ? 'this chat' : '“${chat.title}”';
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: t.raised,
          title: Text(
            'Remove $title?',
            style: theme.ui(t.text, size: 15, weight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 420,
            child: Text(
              'Nushi forgets the chat and stops its agent. Claude keeps its '
              'own history of the session, so you can still resume it in a '
              'terminal in its folder: claude --resume ${chat.sessionId}',
              style: theme.ui(t.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: theme.ui(t.text)),
            ),
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove', style: theme.ui(t.crashed)),
            ),
          ],
        ),
      ) ??
      false;
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
