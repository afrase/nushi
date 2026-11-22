import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_cards.dart';
import 'package:nushi/images.dart';
import 'package:nushi/output_card.dart';
import 'package:nushi/reply_cards.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The cards over the box's text: the subagent it goes to, the replies,
/// the outputs, the files and the images of [draft]. Shown only when
/// there are some.
class DraftCards extends StatelessWidget {
  const new(
    this.draft, {
    required this.chat,
    required this.daemon,
    required this.onDone,
    super.key,
  });

  final Draft draft;
  final ChatState chat;
  final Daemon daemon;

  /// A reply card done with (the focus back to the box).
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (draft.toSubagent.value case (_, final agent)?)
          _ToChip(
            'To $agent, through ${chat.agentName}',
            onRemove: () => draft.toSubagent.value = null,
          ),
        // Only when there are some: an empty one still takes a spacing,
        // which put the first row 6pt right of the rows wrapped under it.
        if (draft.replies.value.isNotEmpty)
          ReplyCards(draft.replies, onDone: onDone),
        for (final o in draft.outputs.value)
          OutputCard(
            o,
            chat: chat,
            daemon: daemon,
            onRemove: () => draft.outputs.value = [
              ...draft.outputs.value.where((n) => n != o),
            ],
          ),
        for (final f in draft.files.value)
          FileCard(
            f,
            onRemove: () =>
                draft.files.value = [...draft.files.value.where((n) => n != f)],
          ),
        if (draft.images.value.isNotEmpty)
          Thumbnails(draft.images.value, onRemove: draft.images.removeAt),
      ],
    ),
  );
}

/// Whom the box's message is for, when not the chat's agent: a pill on the
/// card's lifted fill, with its ×.
class _ToChip extends StatelessWidget {
  const new(this.label, {required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.text, size: 12),
            ),
          ),
          IconTap(Icons.close, size: 13, tooltip: 'Remove', onTap: onRemove),
        ],
      ),
    );
  }
}
