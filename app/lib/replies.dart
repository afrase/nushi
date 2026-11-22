import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/composer_parts.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/sent_commands.dart';
import 'package:nushi/settings.dart';
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

/// A line [splitReplies] reads as one of its marks: a reply's, a lead's or
/// the end's.
final _markLine = RegExp(
  '^(<!-- reply \\d+ -->|<!-- from -->|$_end)\$',
  multiLine: true,
);

/// Whether [text] has a line [splitReplies] would read as one of its own
/// marks. Words that go into every card unseen (what a card asks) mustn't:
/// the sent message would read back as other cards than were sent.
bool hasReplyMarks(String text) => _markLine.hasMatch(text);

/// A message's text: each reply as `<!-- reply n -->` (n its place in the
/// message, from 1: the number the agent answers by, which the cards show
/// when there are two or more, [ReplyNumber]; the comment is the only
/// structure added, so nothing reads as words the user didn't write), its
/// quote as `> ` lines and its text (its lines as written) after a blank
/// line, then
/// [text]. `<!-- end of replies -->` says where the replies end whenever
/// [text] follows them (an agent read the user's own message as more of
/// the last comment, about that comment's file), and when the last
/// reply's text has a blank line of its own. Replies from the
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
  if (replies.isNotEmpty &&
      (text.isNotEmpty || replies.last.text.trim().contains('\n\n')))
    _end,
  if (text.isNotEmpty) text,
].join('\n\n');

/// The replies [message] starts with, and the rest of it ([withReplies]
/// backwards). Without `<!-- end of replies -->`, the last reply's text
/// ends at its first blank line. A group's lead goes to its first reply.
/// The number in each mark isn't kept: a card's is its place in the list.
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

/// Quoted text, dimmed, on the quotes' soft fill, no bar down its side
/// (ADR 0111); in a user message's band's colors when [band].
class QuoteBlock extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.maxLines,
    this.size = 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.quote,
        borderRadius: BorderRadius.circular(NushiTheme.control),
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

/// A reply card's number, [n] from 1, at the card's start, when its message
/// carries two or more ([numbered]): the agent answers "#1 … #2 …" by the
/// marks [withReplies] writes, and the user reads the same numbers here.
/// A small numeral on the quotes' fill, round; on a user message's band,
/// in its colors when [band].
class ReplyNumber extends StatelessWidget {
  const new(this.n, {super.key, this.band = false});

  final int n;
  final bool band;

  /// Whether [count] cards are numbered: one alone isn't.
  static bool numbered(int count) => count > 1;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      key: ValueKey('reply-number-$n'),
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: t.quote,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: Text(
        '$n',
        textAlign: TextAlign.center,
        style: theme
            .ui(
              band ? t.userBandMuted : t.textMuted,
              size: 11.5,
              weight: FontWeight.w600,
            )
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// A user message: its replies, each a quote with the reply under it (and
/// its number before them when there are two or more), then the rest of
/// its text, then the commands it carried, each a card ([SentCommandCard]).
class UserMessageText extends StatelessWidget {
  const new(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final (body, commands) = splitCommands(message);
    final (replies, rest) = splitReplies(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        for (final (i, r) in replies.indexed)
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
              _numbered(
                context,
                ReplyNumber.numbered(replies.length) ? i + 1 : null,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    if (r.quote.isNotEmpty)
                      QuoteBlock(
                        r.quote,
                        size: TouchTargets.of(context) ? 13 : 14,
                        band: true,
                      ),
                    if (r.text.isNotEmpty)
                      AgentMarkdown(
                        r.text,
                        typed: true,
                        transcript: true,
                        chips: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        // Where the cards end and the typed message begins, for the reader
        // as the end's line is for the agent: a comment's own words and
        // the message's looked like one run of paragraphs. A short rule: the
        // bubble is as wide as its widest part, which a full one would be.
        if (replies.isNotEmpty && rest.isNotEmpty)
          Container(
            key: const ValueKey('replies-end'),
            width: 48,
            height: 1,
            color: NushiTheme.of(context).t.userBandMuted
                .withValues(alpha: 0.6),
          ),
        if (rest.isNotEmpty)
          AgentMarkdown(rest, typed: true, transcript: true, chips: true),
        for (final c in commands) SentCommandCard(c),
      ],
    );
  }
}

/// A card's [body], after its number [n] when it has one; as wide as the
/// body, not the bubble (a full-width row would widen it).
Widget _numbered(BuildContext context, int? n, Widget body) => n == null
    ? body
    : Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            // Level with the quote's first line.
            padding: const EdgeInsets.only(top: 3),
            child: ReplyNumber(n, band: true),
          ),
          Flexible(child: body),
        ],
      );

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
    Widget action(String label, VoidCallback run) => Theme(
      // The pill is dark in both themes, so its hover is the dark theme's.
      data: theme.withTokens(theme.dark, dark: theme.dark).toThemeData(),
      child: Tap(
        onTap: run,
        // A whole round end, inset evenly in the pill's.
        radius: NushiTheme.pill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(label, style: theme.ui(fg)),
      ),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.selectionBar,
        shape: StadiumBorder(side: BorderSide(color: t.selectionBarBorder)),
        shadows: floatShadows(t),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              if (onSide case final run?) action('Side chat', run),
              if (onSide != null && onReply != null)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 3,
                  endIndent: 3,
                  color: t.selectionBarDivider,
                ),
              if (onReply case final run?) action('Reply', run),
            ],
          ),
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
        // As tall as it was with the quote's bar: its fill's own padding
        // comes out of the box's.
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 2),
        decoration: floatBox(t),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QuoteBlock(widget.quote.trim(), maxLines: 2),
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
                    // The key follows "Enter starts a new line".
                    ValueListenableBuilder(
                      valueListenable: enterStartsLine,
                      builder: (context, _, _) => IconTap(
                        Icons.arrow_upward,
                        tooltip: withKey('Add to the message', sendKeyLabel),
                        onTap: _send,
                      ),
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
/// it wraps and grows from one line to [lines], then scrolls; the send
/// key runs [onEnter] and a line key starts a line, as in the composer
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
