import 'package:flutter/material.dart';

import 'package:nushi/images.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The replies waiting in the composer, as small cards: a click opens one
/// to edit its text, and hovering one shows a button that removes it.
/// [onDone] runs when the editing ends (the composer takes the focus back).
class ReplyCards extends StatelessWidget {
  const new(this.replies, {required this.onDone, super.key});

  final Replies replies;
  final VoidCallback onDone;

  Future<void> _edit(BuildContext context, int i) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(replies.value[i]),
    );
    onDone();
    if (text == null) return;
    replies.value = [...replies.value]
      ..[i] = (
        quote: replies.value[i].quote,
        text: text.trim(),
        from: replies.value[i].from,
      );
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

class _ReplyCard extends StatelessWidget {
  const new(this.reply, {required this.onTap, required this.onRemove});

  final Reply reply;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final r = reply;
    return Hover(
      builder: (context, {required hover}) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 168,
            // Taller with the text (the phone's is 1.15 times the Mac's).
            height: MediaQuery.textScalerOf(context).scale(64),
            decoration: box(
              t.borderSubtle,
              fill: t.raised,
              radius: NushiTheme.control,
            ),
            child: Tap(
              onTap: onTap,
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
                      // Its lines run on, as many as fit.
                      child: Text(
                        r.text.replaceAll(RegExp(r'\s+'), ' '),
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
          if (hover) RemoveBadge(onRemove),
        ],
      ),
    );
  }
}

/// A reply opened from its card: the quote, and its text to edit, which
/// grows as the reply box's does. Save (or Enter) returns the text,
/// Shift-Enter starts a line; Escape keeps it as it was.
class _ReplyDialog extends StatefulWidget {
  const new(this.reply);

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
    void save() => Navigator.pop(context, _text.text);
    return nushiDialog(
      'Reply',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(child: QuoteBlock(widget.reply.quote)),
          ),
          ReplyField(
            _text,
            autofocus: true,
            onEnter: save,
            decoration: const InputDecoration(hintText: 'Your reply'),
          ),
        ],
      ),
      [
        Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
        Button(label: 'Save', kind: ButtonKind.primary, onPressed: save),
      ],
    );
  }
}
