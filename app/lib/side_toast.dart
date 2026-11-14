import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
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
  showToast(
    toast,
    'Archived side chat',
    key: const ValueKey('archived-side'),
    icon: Icons.info_outline,
    action: (
      label: 'Undo',
      onPressed: () =>
          unawaited(_undo(toast, daemon, chat, archived, was: was)),
    ),
    closable: true,
    replace: true,
    duration: archivedSideFor,
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
    showToast(
      toast,
      "Couldn't undo: ${e is StateError ? e.message : errorText(e)}",
      key: const ValueKey('archived-side-undo-failed'),
      icon: Icons.error_outline,
      failed: true,
      closable: true,
      replace: true,
    );
  }
}
