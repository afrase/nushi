import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/composer_parts.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A reply to a part of the transcript: the quoted text, and what the user
/// says about it (either may be empty, not both); `from` says whose the
/// quoted text is and where it's from ("My review comments on your
/// changes:", "Review comments from @octo on PR afrase/nushi#12 (GitHub),
/// my pull request:"), the lead line of its group in the message, or ''.
/// An agent told only "Review comments" took the user's own for a
/// reviewer's and answered as the pull request's author.
typedef Reply = ({String quote, String text, String from});

/// The replies waiting in a composer, as cards, sent with its next message.
typedef Replies = ValueNotifier<List<Reply>>;

final _marker = RegExp(r'^<!-- reply \d+ -->\n', multiLine: true);

/// A group's lead line, before its first reply's marker.
final _from = RegExp(r'^<!-- from -->\n(.*)\n\n', multiLine: true);
const _end = '<!-- end of replies -->';
final _endLine = RegExp('^$_end\$', multiLine: true);

/// A message's text: each reply as `<!-- reply n -->`, its quote as `> `
/// lines and its text (its lines as written) after a blank line, then
/// [text]. When the last reply's text has a blank line of its own,
/// `<!-- end of replies -->` says where the replies end. Replies from the
/// same place in a row are a group, its lead ((its `from`)) once before
/// it, after `<!-- from -->`.
String withReplies(List<Reply> replies, String text) => [
  for (final (i, r) in replies.indexed) ...[
    if (r.from.isNotEmpty && (i == 0 || replies[i - 1].from != r.from))
      // One line, whatever it holds: a lead over two isn't read back.
      '<!-- from -->\n${r.from.replaceAll(RegExp(r'\s+'), ' ').trim()}',
    [
      '<!-- reply ${i + 1} -->\n',
      [
        for (final line in r.quote.trim().split('\n'))
          if (line.isEmpty) '>' else '> $line',
      ].join('\n'),
      if (r.text.trim().isNotEmpty) '\n\n${r.text.trim()}',
    ].join(),
  ],
  if (replies.lastOrNull?.text.trim().contains('\n\n') ?? false) _end,
  if (text.isNotEmpty) text,
].join('\n\n');

/// The replies [message] starts with, and the rest of it ([withReplies]
/// backwards). Without `<!-- end of replies -->`, the last reply's text
/// ends at its first blank line. A group's lead goes to its first reply.
(List<Reply>, String) splitReplies(String message) {
  // The leads out, each kept for the reply after it (by its number).
  final leads = <int, String>{};
  var all = message;
  if (_from.matchAsPrefix(all) != null || _marker.matchAsPrefix(all) != null) {
    all = all.replaceAllMapped(_from, (m) {
      leads[_marker.allMatches(message.substring(0, m.start)).length] = m[1]!;
      return '';
    });
  }
  if (_marker.matchAsPrefix(all) == null) return (const [], message);
  var head = all;
  String? rest;
  if (_endLine.firstMatch(all) case final m?) {
    head = all.substring(0, m.start);
    rest = all.substring(m.end);
  }
  final blocks = head.split(_marker).skip(1).toList();
  final replies = <Reply>[];
  for (final (i, block) in blocks.indexed) {
    final lines = block.split('\n');
    final quoted = lines.takeWhile((l) => l.startsWith('>')).toList();
    var text = lines.skip(quoted.length).join('\n').trim();
    if (rest == null && i == blocks.length - 1) {
      final cut = text.indexOf('\n\n');
      rest = cut < 0 ? '' : text.substring(cut + 2);
      if (cut >= 0) text = text.substring(0, cut);
    }
    replies.add((
      quote: [
        for (final l in quoted)
          if (l.startsWith('> ')) l.substring(2) else l.substring(1),
      ].join('\n'),
      text: text,
      from: leads[i] ?? '',
    ));
  }
  return (replies, (rest ?? '').trim());
}

/// Quoted text, dimmed, with a bar on its left; in a user message's band's
/// colors when [band].
class QuoteBlock extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.maxLines,
    this.size = 12.5,
    this.band = false,
  });

  final String text;
  final int? maxLines;
  final double size;
  final bool band;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: band ? t.userBandBorder : t.borderStrong,
            width: 2,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: theme.ui(band ? t.userBandMuted : t.textMuted, size: size),
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
              if (r.from.isNotEmpty)
                Text(
                  r.from,
                  style: NushiTheme.of(context)
                      .ui(NushiTheme.of(context).t.userBandMuted, size: 12),
                ),
              if (r.quote.isNotEmpty)
                QuoteBlock(
                  r.quote,
                  size: TouchTargets.of(context) ? 13.5 : 14,
                  band: true,
                ),
              if (r.text.isNotEmpty)
                AgentMarkdown(r.text, typed: true, transcript: true),
            ],
          ),
        if (rest.isNotEmpty) AgentMarkdown(rest, typed: true, transcript: true),
      ],
    );
  }
}

/// The dark pill over a selection: "Side chat | Reply".
class SelectionToolbar extends StatelessWidget {
  const new({super.key, this.onSide, this.onReply});

  final VoidCallback? onSide;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final fg = t.selectionBarText;
    Widget action(String label, VoidCallback run) => Tap(
      onTap: run,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(label, style: theme.ui(fg, size: 12.5)),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.selectionBar,
        shape: StadiumBorder(side: BorderSide(color: t.selectionBarBorder)),
        shadows: [BoxShadow(color: t.shadow, blurRadius: 6)],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onSide case final run?) action('Side chat', run),
            if (onSide != null && onReply != null)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 6,
                endIndent: 6,
                color: t.selectionBarDivider,
              ),
            if (onReply case final run?) action('Reply', run),
          ],
        ),
      ),
    );
  }
}

/// Writing a reply to a selection: the quote, and the reply, which wraps
/// and grows to [ReplyField.lines] lines, then scrolls. Enter (or the send
/// button) hands the reply over, Shift-Enter starts a line; Escape closes.
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
    widget.onReply((
      quote: widget.quote.trim(),
      text: _text.text.trim(),
      from: '',
    ));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Container(
        width: 400,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
        decoration: ShapeDecoration(
          color: t.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: t.borderStrong),
          ),
          shadows: [BoxShadow(color: t.shadow, blurRadius: 6)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuoteBlock(widget.quote.trim(), maxLines: 2, size: 12),
              // In a short window the field gives way, and scrolls.
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ReplyField(
                        _text,
                        focus: _focus,
                        onEnter: _send,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reply's text field, in the reply box and the dialog that edits it:
/// it wraps and grows from one line to [lines], then scrolls; Enter runs
/// [onEnter] and Shift-Enter starts a line, as in the composer
/// ([isSendKey]).
class ReplyField extends StatelessWidget {
  const new(
    this.controller, {
    required this.onEnter,
    required this.decoration,
    super.key,
    this.focus,
    this.autofocus = false,
  });

  static const lines = 8;

  final TextEditingController controller;
  final VoidCallback onEnter;
  final InputDecoration decoration;
  final FocusNode? focus;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return EnterSends(
      controller: controller,
      onEnter: onEnter,
      child: TextField(
        controller: controller,
        focusNode: focus,
        autofocus: autofocus,
        minLines: 1,
        maxLines: lines,
        style: theme.ui(theme.t.text),
        decoration: decoration,
      ),
    );
  }
}
