import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A reply to a part of the transcript: the quoted text, and what the user
/// says about it (either may be empty, not both).
typedef Reply = ({String quote, String text});

/// The replies waiting in a composer, as cards, sent with its next message.
typedef Replies = ValueNotifier<List<Reply>>;

final _marker = RegExp(r'^<!-- reply \d+ -->\n', multiLine: true);

/// A message's text: each reply as `<!-- reply n -->`, its quote as `> `
/// lines and its text after a blank line, then [text].
String withReplies(List<Reply> replies, String text) => [
  for (final (i, r) in replies.indexed)
    [
      '<!-- reply ${i + 1} -->\n',
      [
        for (final line in r.quote.trim().split('\n'))
          if (line.isEmpty) '>' else '> $line',
      ].join('\n'),
      if (r.text.trim().isNotEmpty) '\n\n${r.text.trim()}',
    ].join(),
  if (text.isNotEmpty) text,
].join('\n\n');

/// The replies [message] starts with, and the rest of it ([withReplies]
/// backwards). A reply's text ends at its first blank line.
(List<Reply>, String) splitReplies(String message) {
  if (_marker.matchAsPrefix(message) == null) return (const [], message);
  final blocks = message.split(_marker).skip(1).toList();
  final replies = <Reply>[];
  var rest = '';
  for (final (i, block) in blocks.indexed) {
    final lines = block.split('\n');
    final quoted = lines.takeWhile((l) => l.startsWith('>')).toList();
    var text = lines.skip(quoted.length).join('\n').trim();
    if (i == blocks.length - 1) {
      final cut = text.indexOf('\n\n');
      if (cut >= 0) {
        rest = text.substring(cut + 2);
        text = text.substring(0, cut);
      }
    }
    replies.add((
      quote: [
        for (final l in quoted)
          if (l.startsWith('> ')) l.substring(2) else l.substring(1),
      ].join('\n'),
      text: text,
    ));
  }
  return (replies, rest.trim());
}

/// Quoted text, dimmed, with a bar on its left.
class QuoteBlock extends StatelessWidget {
  const new(this.text, {super.key, this.maxLines, this.size = 12.5});

  final String text;
  final int? maxLines;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.t.borderStrong, width: 2)),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: theme.ui(theme.t.textMuted, size: size),
      ),
    );
  }
}

/// A user message: its replies, each a quote with the reply under it, then
/// the rest of its text.
class UserMessageText extends StatelessWidget {
  const new(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final (replies, rest) = splitReplies(message);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final r in replies)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              if (r.quote.isNotEmpty) QuoteBlock(r.quote),
              if (r.text.isNotEmpty) AgentMarkdown(r.text, typed: true),
            ],
          ),
        if (rest.isNotEmpty) AgentMarkdown(rest, typed: true),
      ],
    );
  }
}

/// The dark pill over a selection: "Start a side chat | Reply".
class SelectionToolbar extends StatelessWidget {
  const new({super.key, this.onSide, this.onReply});

  final VoidCallback? onSide;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    const fg = Color(0xFFE8E9EC);
    Widget action(String label, VoidCallback run) => Tap(
      onTap: run,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(label, style: theme.ui(fg, size: 12.5)),
    );
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: Color(0xFF26272B),
        shape: StadiumBorder(side: BorderSide(color: Color(0x22FFFFFF))),
        shadows: [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSide case final run?) action('Start a side chat', run),
            if (onSide != null && onReply != null)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 6,
                endIndent: 6,
                color: Color(0x33FFFFFF),
              ),
            if (onReply case final run?) action('Reply', run),
          ],
        ),
      ),
    );
  }
}

/// Writing a reply to a selection: the quote, and one line to reply in.
/// Enter (or the send button) hands the reply over; Escape closes.
class ReplyBox extends StatefulWidget {
  const new({
    required this.quote,
    required this.onReply,
    required this.onClose,
    super.key,
  });

  final String quote;
  final void Function(Reply) onReply;
  final VoidCallback onClose;

  @override
  State<ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<ReplyBox> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus would leave the focus where it is (the transcript).
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    widget.onReply((quote: widget.quote.trim(), text: _text.text.trim()));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
        decoration: ShapeDecoration(
          color: t.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: t.borderStrong),
          ),
          shadows: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuoteBlock(widget.quote.trim(), maxLines: 2, size: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      style: theme.ui(t.text),
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Your reply',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  IconTap(
                    Icons.arrow_upward,
                    tooltip: 'Add to the message (⏎)',
                    onTap: _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
