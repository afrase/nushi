import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The messages waiting for the agent, as pills over the composer: a click
/// takes one back to edit ([onEdit]), × drops it ([onRemove]).
class QueuePills extends StatelessWidget {
  const new(
    this.chat, {
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final ChatState chat;
  final void Function(QueuedMessage) onEdit;
  final void Function(QueuedMessage) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in chat.queue)
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: ShapeDecoration(
                color: t.raised,
                shape: StadiumBorder(side: BorderSide(color: t.borderStrong)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Tap(
                      onTap: () => onEdit(m),
                      tooltip: 'Edit',
                      radius: 14,
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: [
                          Icon(Icons.schedule, size: 13, color: t.textMuted),
                          Flexible(
                            child: Text(
                              _label(m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.ui(t.textSecondary, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconTap(
                    Icons.close,
                    size: 13,
                    tooltip: 'Remove',
                    onTap: () => onRemove(m),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A queued message in one line: its text, or what it holds.
String _label(QueuedMessage m) {
  final (replies, text) = splitReplies(m.text);
  final line = (text.isEmpty ? replies.firstOrNull?.text ?? '' : text)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (line.isNotEmpty) {
    return m.relayTo.isEmpty ? line : 'To ${m.relayTo}: $line';
  }
  if (replies.isNotEmpty) return 'Reply';
  return m.images.length == 1 ? 'An image' : '${m.images.length} images';
}
