import 'package:flutter/material.dart';

import 'images.dart';
import 'replies.dart';
import 'theme/theme.dart';

/// The replies waiting in the composer, as small cards: a click opens one
/// to edit its text, and hovering one shows a button that removes it.
/// [onDone] runs when the editing ends (the composer takes the focus back).
class ReplyCards extends StatelessWidget {
  const ReplyCards(this.replies, {super.key, required this.onDone});

  final Replies replies;
  final VoidCallback onDone;

  void _edit(BuildContext context, int i) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(replies.value[i]),
    );
    onDone();
    if (text == null) return;
    replies.value = [...replies.value]
      ..[i] = (quote: replies.value[i].quote, text: text.trim());
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (i, r) in replies.value.indexed)
        _ReplyCard(
          r,
          onTap: () => _edit(context, i),
          onRemove: () => replies.value = [...replies.value]..removeAt(i),
        ),
    ],
  );
}

class _ReplyCard extends StatefulWidget {
  const _ReplyCard(this.reply, {required this.onTap, required this.onRemove});

  final Reply reply;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<_ReplyCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final r = widget.reply;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: t.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NushiTheme.control),
              side: BorderSide(color: t.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                width: 168,
                height: 64,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.quote.isNotEmpty)
                      QuoteBlock(
                        r.quote,
                        maxLines: r.text.isEmpty ? 2 : 1,
                        size: 11.5,
                      ),
                    if (r.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          r.text,
                          maxLines: r.quote.isEmpty ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.text, size: 11.5),
                        ),
                      ),
                    const Spacer(),
                    Text('Reply', style: theme.ui(t.textMuted, size: 10.5)),
                  ],
                ),
              ),
            ),
          ),
          if (_hover) RemoveBadge(widget.onRemove),
        ],
      ),
    );
  }
}

/// A reply opened from its card: the quote, and its text to edit. Save (or
/// Enter) returns the text; Escape keeps it as it was.
class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog(this.reply);

  final Reply reply;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final _text = TextEditingController(text: widget.reply.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    void save() => Navigator.pop(context, _text.text);
    return AlertDialog(
      backgroundColor: t.raised,
      title: Text(
        'Reply',
        style: theme.ui(t.text, size: 15, weight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: QuoteBlock(widget.reply.quote),
              ),
            ),
            TextField(
              controller: _text,
              autofocus: true,
              style: theme.ui(t.text),
              onSubmitted: (_) => save(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Reply to Claude',
                hintStyle: theme.ui(t.textMuted),
                contentPadding: const EdgeInsets.all(8),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: t.borderStrong),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.borderStrong),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: t.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: theme.ui(t.text)),
        ),
        TextButton(
          onPressed: save,
          child: Text('Save', style: theme.ui(t.link)),
        ),
      ],
    );
  }
}
