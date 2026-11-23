import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/side_toast.dart';
import 'package:nushi/widgets.dart';

// The toast after a fork, with Undo (#58): Fork from here is one click on
// a message's row, easy to hit by accident, and an Undo costs less than a
// question on every fork.

/// How long the toast after a fork stays, its Undo with it: as long as
/// the app's other Undo, an archived side chat's.
const Duration forkedFor = archivedSideFor;

/// Says [fork] was made: an icon, Undo and ×, for [forkedFor], in place
/// of any toast showing (a fork's before it too). Undo runs [back], which
/// takes the user back to the chat forked from, then deletes the fork as
/// Delete does, the agent's history of its session with it (ADR 0015);
/// a worktree, which it shares with that chat, stays. The toast goes once
/// the fork moves on (a message sent or queued, a turn or a prompt), when
/// undoing would throw that away.
void showForked(
  Toasts? toasts,
  Daemon daemon,
  ChatState fork, {
  required VoidCallback back,
}) => toasts?.show(
  (close) => _ForkedLine(
    fork,
    close: close,
    undo: () {
      close();
      if (forkMovedOn(fork)) return; // pressed as a message went
      unawaited(_undo(toasts, daemon, fork, back));
    },
  ),
  key: ValueKey('forked-${fork.id}'),
  duration: forkedFor,
  replace: true,
  holds: true,
);

/// Whether [fork] has gone on from what it was forked with: a message
/// sent or waiting in its queue, a turn running, a prompt or question on
/// the user. Not `busy`: a fork is busy while the daemon puts its chat's
/// mode and picks on it.
bool forkMovedOn(ChatState fork) =>
    fork.started != null ||
    fork.waiting ||
    fork.ownTurn ||
    fork.queue.isNotEmpty ||
    fork.outbox.sending.isNotEmpty;

/// Undo: [back] to the chat forked from, then the fork deleted; when the
/// daemon refuses, a toast says why (the fork stays, in the sidebar).
Future<void> _undo(
  Toasts toasts,
  Daemon daemon,
  ChatState fork,
  VoidCallback back,
) async {
  back();
  try {
    await daemon.client.deleteChat(DeleteChatRequest(chatId: fork.id));
  } on Object catch (e) {
    showFailure(
      toasts,
      "Couldn't delete the fork: ${errorText(e)}",
      key: const ValueKey('fork-undo-failed'),
      replace: true,
    );
  }
}

/// The toast's line, which follows [fork] while it shows and goes once
/// the fork moves on ([forkMovedOn]).
class _ForkedLine extends StatefulWidget {
  const new(this.fork, {required this.close, required this.undo});

  final ChatState fork;
  final VoidCallback close;
  final VoidCallback undo;

  @override
  State<_ForkedLine> createState() => _ForkedLineState();
}

class _ForkedLineState extends State<_ForkedLine> {
  @override
  void initState() {
    super.initState();
    widget.fork.addListener(_changed);
  }

  @override
  void dispose() {
    widget.fork.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (forkMovedOn(widget.fork)) {
      widget.fork.removeListener(_changed);
      widget.close();
    }
  }

  @override
  Widget build(BuildContext context) => ToastLine(
    'Forked into a new chat',
    icon: Icons.call_split,
    action: (label: 'Undo', onPressed: widget.undo),
    onClose: widget.close,
  );
}
