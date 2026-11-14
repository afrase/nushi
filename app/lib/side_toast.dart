import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// How long the toast that says a side chat was archived stays, its Undo
/// with it (ADR 0115).
const archivedSideFor = Duration(seconds: 10);

/// Says [chat]'s side chat was archived as [archived], as Claude's desktop
/// app does: an info icon, Undo and ×, for [archivedSideFor]. Undo brings
/// it back beside [chat] with [was]'s draft, or says why it can't.
void showArchivedSide(
  ScaffoldMessengerState toast,
  Daemon daemon,
  ChatState chat,
  String archived, {
  ChatState? was,
}) {
  toast
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('archived-side'),
        content: ToastLine(
          Icons.info_outline,
          'Archived side chat',
          onUndo: () {
            toast.hideCurrentSnackBar();
            unawaited(_undo(toast, daemon, chat, archived, was: was));
          },
          onClose: toast.hideCurrentSnackBar,
        ),
        duration: archivedSideFor,
      ),
    );
}

/// Undo of an archived side chat: [chat]'s side chat again, [chat] shown;
/// when it can't be (the chat was deleted or archived, or has a side chat
/// open, or the daemon refuses), a toast says why.
Future<void> _undo(
  ScaffoldMessengerState toast,
  Daemon daemon,
  ChatState chat,
  String archived, {
  ChatState? was,
}) async {
  final why = switch (daemon.chats[chat.id]) {
    null => 'the chat it came from was deleted',
    final c when c.archived => 'the chat it came from is archived',
    final c when c.side.value != null => 'the chat has another side chat open',
    _ => null,
  };
  try {
    if (why != null) throw StateError(why);
    await daemon.restoreSide(chat, archived, was: was);
    if (daemon.selectedId != chat.id) daemon.select(chat.id);
  } on Object catch (e) {
    toast
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('archived-side-undo-failed'),
          content: ToastLine(
            Icons.error_outline,
            "Couldn't undo: ${e is StateError ? e.message : errorText(e)}",
            failed: true,
            onClose: toast.hideCurrentSnackBar,
          ),
        ),
      );
  }
}

/// A toast's line: [icon] (the failure's color when [failed]), [text],
/// then Undo when [onUndo] is given and × ([onClose]), from the app's own
/// controls.
class ToastLine extends StatelessWidget {
  const new(
    this.icon,
    this.text, {
    required this.onClose,
    this.onUndo,
    this.failed = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onUndo;
  final VoidCallback onClose;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 16, color: failed ? t.crashed : t.textSecondary),
        Expanded(child: Text(text)),
        if (onUndo case final undo?) Button(label: 'Undo', onPressed: undo),
        IconTap(Icons.close, size: 14, tooltip: 'Dismiss', onTap: onClose),
      ],
    );
  }
}
