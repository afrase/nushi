import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_column.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/review.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A comment under its lines in the diff: its lines and text, Edit (while
/// unsent) and Remove on hover; dimmed once sent. An outdated one (its
/// lines are gone) shows above the file with the lines it was on, and one
/// away from its file ([place]: where it was made) with them too.
class CommentCard extends StatelessWidget {
  const new(
    this.comment, {
    required this.onEdit,
    required this.onRemove,
    super.key,
    this.place,
  });

  final ReviewComment comment;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final String? place;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final c = comment;
    return Hover(
      builder: (context, {required hover}) => Opacity(
        opacity: c.sent ? 0.55 : 1,
        child: _Inlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (c.outdated) 'Outdated',
                        ?place,
                        c.lines,
                        if (c.sent) 'sent',
                      ].join(' · '),
                      style: theme.ui(t.textMuted, size: 11.5),
                    ),
                  ),
                  if (hover && !c.sent)
                    IconTap(
                      Icons.edit_outlined,
                      tooltip: 'Edit',
                      size: 13,
                      onTap: onEdit,
                    ),
                  if (hover)
                    IconTap(
                      Icons.close,
                      tooltip: 'Remove',
                      size: 13,
                      onTap: onRemove,
                    ),
                ],
              ),
              if (c.outdated || place != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    c.quote,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.code(t.textMuted, size: 11.5),
                  ),
                ),
              SelectableText(c.text, style: theme.ui(t.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The box to write a comment in, under the lines it's on: Enter (or ⌘⏎)
/// saves it, ⇧⏎ (⌥⏎, ⌃⏎) adds a line ([isSendKey]), Escape drops it.
class ReviewCommentBox extends StatefulWidget {
  const new({
    required this.lines,
    required this.controller,
    required this.onSave,
    required this.onCancel,
    super.key,
    this.editing = false,
    this.hint = 'Your comment',
  });

  final String lines;
  final String hint;

  /// Its text, kept by the diff so it outlives the box.
  final TextEditingController controller;
  final bool editing; // a comment made before, being changed
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<ReviewCommentBox> createState() => _ReviewCommentBoxState();
}

class _ReviewCommentBoxState extends State<ReviewCommentBox> {
  TextEditingController get _text => widget.controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The diff pane took the focus with the click; autofocus would yield.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isNotEmpty) widget.onSave(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return _Inlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(widget.lines, style: theme.ui(t.textMuted, size: 11.5)),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
            },
            child: EnterSends(
              controller: _text,
              onEnter: _save,
              child: TextField(
                controller: _text,
                focusNode: _focus,
                minLines: 1,
                maxLines: 8,
                style: theme.ui(t.text),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  isDense: true,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 6,
            children: [
              Button(label: 'Cancel', onPressed: widget.onCancel),
              Button(
                label: widget.editing ? 'Save' : 'Comment',
                kind: ButtonKind.primary,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An inline box between a diff's lines, with an accent bar on its left.
class _Inlay extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 8, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
        decoration: BoxDecoration(
          color: t.raised,
          border: Border(left: BorderSide(color: t.accent, width: 2)),
          // A tag's small corners while it has the bar: round a control's,
          // the bar curls into a bracket.
          borderRadius: BorderRadius.circular(NushiTheme.tag),
        ),
        child: child,
      ),
    );
  }
}

/// Over the composer while review comments made in Changes aren't in a
/// message yet (they're easy to forget there): how many, Send to agent
/// (reply cards in the box, as the Changes view's button) and Show them.
class UnsentReview extends StatelessWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: reviews,
      builder: (context, _, _) {
        final n = unsentComments(chat.id).length;
        if (n == 0) return const SizedBox.shrink();
        return ChatColumn(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NushiTheme.gutter,
              vertical: 4,
            ),
            child: Row(
              spacing: NushiTheme.barGap,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 13,
                        color: t.textMuted,
                      ),
                      Flexible(
                        child: Text(
                          n == 1
                              ? '1 review comment in Changes isn’t sent.'
                              : '$n review comments in Changes aren’t sent.',
                          style: theme.ui(t.textSecondary, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                LinkText(
                  'Send to agent',
                  size: 12,
                  tooltip: 'Each as a reply card in the box, to send',
                  onTap: () => reviewToBox(chat),
                ),
                LinkText(
                  'Show',
                  size: 12,
                  onTap: () => chat.tab.value = ChatTab.changes,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
