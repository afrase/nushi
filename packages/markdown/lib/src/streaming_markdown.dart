import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_view/src/blocks.dart';
import 'package:markdown_view/src/heal.dart';
import 'package:markdown_view/src/stream_marks.dart';

part 'code_block.dart';
part 'file_link.dart';

/// The colors and fonts of [StreamingMarkdown].
@immutable
class MarkdownStyle {
  /// The style with each of its colors and fonts.
  const new({
    required this.body,
    required this.code,
    required this.codeBackground,
    required this.border,
    required this.muted,
    required this.link,
    required this.highlight,
    this.inlineCode,
    this.languageName,
  });

  /// Paragraph text.
  final TextStyle body;

  /// Code, inline and in blocks.
  final TextStyle code;

  /// Behind code blocks (and tables' heads).
  final Color codeBackground;

  /// Behind inline code: a tint, since a paragraph paints its selection
  /// under the text and an opaque background would hide it. Null takes
  /// the body's color, faintly.
  final Color? inlineCode;

  /// Around code blocks and tables, and a quote's bar.
  final Color border;

  /// Quotes, a code block's language label and its copy button.
  final Color muted;

  /// Links.
  final Color link;

  /// A code block's code in its language, highlighted over the code's
  /// [TextStyle]; null leaves it plain (a language it doesn't know). Code
  /// blocks are kept by this function, so give the same one while the
  /// colors are the same.
  final TextSpan? Function(String language, String code, TextStyle style)
  highlight;

  /// A code block's language as its label shows it ("Ruby" for `rb`);
  /// null shows the fence's tag as written.
  final String Function(String language)? languageName;
}

/// Markdown that may still be streaming in: healed before it is parsed (see
/// [heal]), with highlighted code blocks that scroll sideways. Images are
/// what [imageBuilder] makes of them, or else their alt text: nothing is
/// fetched on its own. Raw HTML shows as the text it is. Put it in a
/// [SelectionArea] to select text.
///
/// While it streams, only its last block is parsed again as text comes:
/// the blocks before it ([lastBoundary]) are kept as they were parsed, in
/// pieces, each parsed once, as the cut moves on.
class StreamingMarkdown extends StatefulWidget {
  /// Markdown for [text], drawn in [style].
  const new(
    this.text, {
    required this.style,
    super.key,
    this.onTapLink,
    this.imageBuilder,
    this.streaming = true,
    this.lineBreaks = false,
    this.codeBlock,
    this.files,
    this.onTapFile,
    this.fresh = const [],
    this.caret,
  });

  /// The markdown so far.
  final String text;

  /// Its colors and fonts.
  final MarkdownStyle style;

  /// Whether [text] may still be incomplete, so it is healed first.
  final bool streaming;

  /// Whether a single newline breaks the line, as typed, rather than
  /// joining the lines into one paragraph.
  final bool lineBreaks;

  /// Runs when a link is clicked, with its destination.
  final void Function(String href)? onTapLink;

  /// Builds an image from its URL and alt text.
  final Widget Function(Uri uri, String? alt)? imageBuilder;

  /// Draws a fenced code block of its own, by its language (a diagram), or
  /// gives null for the usual [CodeBlockView]. `open` while the block is
  /// still streaming in (its closing fence not come yet).
  final Widget? Function(String language, String code, {required bool open})?
  codeBlock;

  /// Paths of files to make links of, once [text] has finished streaming:
  /// each as written, in inline code or plain text, to what [onTapFile]
  /// gets. Written elsewhere (in a word, a path or a URL) it stays text.
  final Map<String, String>? files;

  /// Runs when one of [files] is clicked, with its path.
  final void Function(String path)? onTapFile;

  /// While streaming, text just revealed, drawn faded in its paragraph
  /// where that's safe ([markFresh]); elsewhere it just shows.
  final List<FreshRun> fresh;

  /// While streaming, drawn where the text ends, in its line and taking no
  /// room, when the text ends in a line of prose ([caretFits]).
  final Widget? caret;

  @override
  State<StreamingMarkdown> createState() => _StreamingMarkdownState();
}

class _StreamingMarkdownState extends State<StreamingMarkdown> {
  // While streaming: the finished blocks so far, in the pieces they were
  // cut in, and the text they make.
  final _pieces = <String>[];
  String _head = '';

  /// Moves the cut on to the last finished block, if it moved; back to
  /// none when the text isn't the same up to it (another message).
  void _cut(String text) {
    if (!text.startsWith(_head)) {
      _pieces.clear();
      _head = '';
    }
    if (hasReferences(text)) {
      // A link anywhere may refer to it: the whole is parsed as one.
      _pieces.clear();
      _head = '';
      return;
    }
    final at = lastBoundary(text, from: _head.length);
    if (at == null) return;
    _pieces.add(text.substring(_head.length, at));
    _head = text.substring(0, at);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (!w.streaming) {
      _pieces.clear();
      _head = '';
      return _body(w.text, streaming: false);
    }
    _cut(w.text);
    if (_pieces.isEmpty) return _body(_last(w.text, 0));
    final gap = SizedBox(height: (w.style.body.fontSize ?? 14) * 0.75);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, piece) in _pieces.indexed) ...[
          if (i > 0) gap,
          KeyedSubtree(key: ValueKey(i), child: _body(piece)),
        ],
        gap,
        KeyedSubtree(
          key: const ValueKey('last'),
          child: _body(_last(w.text.substring(_head.length), _head.length)),
        ),
      ],
    );
  }

  /// The open block, [tail] (from [at] in the text), healed, with its
  /// fresh runs and caret marked.
  String _last(String tail, int at) {
    final w = widget;
    final healed = heal(markFresh(tail, at, w.fresh), markOpen: true);
    return w.caret != null && caretFits(healed, openMark)
        ? withCaret(healed)
        : healed;
  }

  /// [data] as one Markdown body: parsed again only when it, or the style
  /// sheet, changes.
  Widget _body(String data, {bool streaming = true}) {
    final w = widget;
    final s = w.style;
    final body = s.body;
    final files = streaming || w.onTapFile == null ? null : w.files;
    final linking = files != null && files.isNotEmpty;
    final heading = body.copyWith(fontWeight: FontWeight.w600);
    final size = body.fontSize ?? 14;
    final onTapLink = w.onTapLink;
    final imageBuilder = w.imageBuilder;
    return MarkdownBody(
      // The body parses again only for new text or a new style sheet:
      // other links, another body.
      key: linking ? ValueKey(Object.hashAllUnordered(files.keys)) : null,
      data: data,
      softLineBreak: w.lineBreaks,
      blockSyntaxes: const [_HtmlAsText()],
      inlineSyntaxes: [
        if (linking) _FilePathSyntax(files.keys),
        if (streaming) ...streamSyntaxes,
      ],
      builders: {
        'pre': _CodeBlockBuilder(s, w.codeBlock),
        if (streaming) ...streamBuilders(w.caret),
        if (linking) ...{
          'code': _FileLinkBuilder(files, w.onTapFile!),
          _FilePathSyntax.tag: _FileLinkBuilder(files, w.onTapFile!),
        },
      },
      // A task list's box ("- [x]"), as text so it lines up with the item.
      checkboxBuilder: (checked) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(checked ? '☑' : '☐', style: body.copyWith(color: s.muted)),
      ),
      onTapLink: (_, href, _) {
        if (href != null) onTapLink?.call(href);
      },
      imageBuilder: (uri, title, alt) =>
          imageBuilder?.call(uri, alt) ??
          Text('[image: ${alt ?? uri}]', style: body.copyWith(color: s.muted)),
      styleSheet: MarkdownStyleSheet(
        p: body,
        a: body.copyWith(color: s.link, decoration: TextDecoration.underline),
        em: const TextStyle(fontStyle: FontStyle.italic),
        // Bolder than the body, also when the body is semibold.
        strong: TextStyle(
          fontWeight: (body.fontWeight ?? FontWeight.normal).value >= 600
              ? FontWeight.w800
              : FontWeight.w600,
        ),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        code: s.code.copyWith(
          fontSize: size * 0.92,
          backgroundColor:
              s.inlineCode ?? (body.color ?? s.muted).withValues(alpha: 0.07),
        ),
        h1: heading.copyWith(fontSize: size * 1.45),
        h2: heading.copyWith(fontSize: size * 1.25),
        h3: heading.copyWith(fontSize: size * 1.1),
        h4: heading,
        h5: heading,
        h6: heading,
        h1Padding: const EdgeInsets.only(top: 6),
        h2Padding: const EdgeInsets.only(top: 6),
        h3Padding: const EdgeInsets.only(top: 4),
        blockSpacing: size * 0.75,
        listIndent: size * 1.6,
        listBullet: body,
        blockquote: body.copyWith(color: s.muted),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: s.border, width: 3)),
        ),
        codeblockDecoration: BoxDecoration(
          color: s.codeBackground,
          border: Border.all(color: s.border),
          borderRadius: BorderRadius.circular(6),
        ),
        tableHead: const TextStyle(fontWeight: FontWeight.w600),
        tableBody: body,
        tableBorder: TableBorder.all(color: s.border),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        tableHeadCellsDecoration: BoxDecoration(color: s.codeBackground),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: s.border)),
        ),
      ),
    );
  }
}

/// An HTML block (a line that starts with a tag, such as
/// `<persisted-output>`, through the next blank line) as a paragraph of
/// its lines, as written: the default makes it a bare text node, which
/// draws nothing.
class _HtmlAsText extends md.HtmlBlockSyntax {
  const new();

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = parseChildLines(parser)
        .map((l) => l.content.trimRight())
        .toList();
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return md.Element('p', [
      for (final (i, line) in lines.indexed) ...[
        if (i > 0) md.Element.empty('br'),
        md.Text(line),
      ],
    ]);
  }
}
