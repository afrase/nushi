import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/widgets.dart';

// Move chat here (ADR 0150): a chat keeps one folder, and the agent's own
// tool call that entered a worktree offers to move the chat into it.

/// The call of [chat]'s whose row offers Move chat here, if one does: the
/// latest call that says where the agent works, when it entered a
/// worktree the chat isn't in already (its folder, or its worktree's
/// path). A later call that left it ends the offer, and so does a move
/// there. A call says so only once it completed (the daemon has its word
/// an update earlier, while its row still spins), so the button comes as
/// the spinner goes and never shifts. None in an archived chat or a
/// [side] chat, whose folder is its chat's. The daemon keeps it only on
/// the main agent's calls.
Item? moveOffer(ChatState chat, {required bool side}) {
  if (chat.archived || side) return null;
  for (final it in chat.items.reversed) {
    if (!it.hasWorksIn() || it.status != 'completed') continue;
    final path = it.worksIn.path;
    final here = path == chat.folder || path == chat.worktree?.path;
    return path.isEmpty || here ? null : it;
  }
  return null;
}

/// A call's Move chat here, in its row's trailing part, the gap before it
/// its own: shown while [item] is the chat's [moveOffer], nothing else.
/// While the agent works or waits on the user it stays, disabled, saying
/// when it can (the folder button's rule), so it never comes late or
/// moves the row as it enables. A press runs the folder button's move,
/// its question included.
class MoveHereButton extends StatelessWidget {
  const new(this.item, this.chat, this.daemon, {super.key});

  final Item item;
  final ChatState chat;
  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) {
      final offer = moveOffer(chat, side: daemon.sideOf(chat.id) != null);
      if (offer?.id != item.id) return const SizedBox.shrink();
      final path = item.worksIn.path;
      final enabled = !chat.busy && !chat.waiting;
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: PillButton(
          label: 'Move chat here',
          icon: Icons.drive_file_move_outline,
          small: true,
          tooltip: enabled
              ? 'Move this chat to ${tildePath(path)}'
              : 'The chat can move once the agent is done',
          onPressed: enabled
              ? () => moveChat(context, daemon, chat, to: path)
              : null,
        ),
      );
    },
  );
}
