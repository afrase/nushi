import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/background_commands.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/chat_pins.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/ui.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The phone's chat ⋯: what the chat runs in (its folder, branch and
/// model) and what can be done to it from a phone: Rename, Pin or Unpin,
/// Sleep, Archive or Unarchive, and Stop every subagent and background
/// command that runs. Everything else stays the Mac's.
Future<void> showChatSheet(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: NushiTheme.of(context).t.raised,
  showDragHandle: true,
  builder: (_) => ChatSheet(daemon, chat),
);

class ChatSheet extends StatefulWidget {
  const new(this.daemon, this.chat, {super.key});

  final Daemon daemon;
  final ChatState chat;

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  String? _branch; // asked of the daemon; '' when not a repository

  @override
  void initState() {
    super.initState();
    final chat = widget.chat;
    if (chat.worktree case final wt?) {
      _branch = wt.branch;
    } else if (!chat.scratch) {
      widget.daemon.client
          .getFolderStatus(GetFolderStatusRequest(folder: chat.folder))
          .then(
            (s) => mounted ? setState(() => _branch = s.branch) : null,
            onError: (_) => mounted ? setState(() => _branch = '') : null,
          )
          .ignore();
    }
  }

  /// The running subagents and background commands it can stop.
  List<String> get _running => [
    for (final s in subagentsOf(widget.chat.items))
      if (subagentStoppable(s)) s.call.id,
    for (final it in backgroundCommandsOf(widget.chat.items))
      if (commandRunning(it)) it.id,
  ];

  Future<void> _rename() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(widget.chat.title),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    await tryOrShow(
      context,
      () => widget.daemon.client.renameChat(
        RenameChatRequest(chatId: widget.chat.id, title: title.trim()),
      ),
    );
  }

  /// Runs [action], then closes the sheet.
  Future<void> _then(Future<void> Function() action) async {
    await action();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final chat = widget.chat;
    final d = widget.daemon;
    final model = chat.option('model');
    final modelName = model?.values
        .where((v) => v.value == model.current)
        .firstOrNull
        ?.name;
    final (name, parent) = folderParts(chat.folder, scratch: chat.scratch);
    final running = _running;
    Widget info(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: phoneText(context, color: t.textMuted)),
          ),
          Expanded(child: Text(value, style: phoneText(context))),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info('Folder', parent.isEmpty ? name : '$name  $parent'),
            if (_branch case final b? when b.isNotEmpty) info('Branch', b),
            if (modelName != null) info('Model', modelName),
            info('Agent', chat.agentName),
            const SizedBox(height: 12),
            for (final (label, run, destructive) in [
              ('Rename…', _rename, false),
              if (canPinChat(d, chat))
                (
                  chat.pin > 0 ? 'Unpin' : 'Pin',
                  () => _then(
                    () => tryOrShow(context, () => toggleChatPin(d, chat)),
                  ),
                  false,
                ),
              if (chat.canSleep && !chat.archived)
                (
                  'Sleep',
                  () => _then(() => sleepChat(context, chat, d)),
                  false,
                ),
              if (running.isNotEmpty)
                (
                  running.length == 1
                      ? 'Stop the background task'
                      : 'Stop ${running.length} background tasks',
                  () => _then(() async {
                    for (final id in running) {
                      await stopTask(context, d, chat, id);
                    }
                  }),
                  true,
                ),
              (
                chat.archived ? 'Unarchive' : 'Archive',
                () => _then(
                  () => tryOrShow(context, () => archiveChat(context, chat, d)),
                ),
                false,
              ),
            ])
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: PhoneButton(
                  label,
                  destructive: destructive,
                  onTap: () => unawaited(run()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rename's box, which owns its text (the dialog outlives the pick while
/// it animates away).
class _RenameDialog extends StatefulWidget {
  const new(this.title);

  final String title;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename'),
    content: TextField(
      controller: _text,
      autofocus: true,
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _text.text),
        child: const Text('Rename'),
      ),
    ],
  );
}
