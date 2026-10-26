import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_view/src/heal.dart';

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
  });

  /// Paragraph text.
  final TextStyle body;

  /// Code, inline and in blocks.
  final TextStyle code;

  /// Behind code blocks and inline code.
  final Color codeBackground;

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
}

/// Markdown that may still be streaming in: healed before it is parsed (see
/// [heal]), with highlighted code blocks that scroll sideways. Images are
/// what [imageBuilder] makes of them, or else their alt text: nothing is
/// fetched on its own. Raw HTML shows as the text it is. Put it in a
/// [SelectionArea] to select text.
class StreamingMarkdown extends StatelessWidget {
  /// Markdown for [text], drawn in [style].
  const new(
    this.text, {
    required this.style,
    super.key,
    this.onTapLink,
    this.imageBuilder,
    this.streaming = true,
    this.lineBreaks = false,
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

  @override
  Widget build(BuildContext context) {
    final s = style;
    final body = s.body;
    final heading = body.copyWith(fontWeight: FontWeight.w600);
    final size = body.fontSize ?? 14;
    return MarkdownBody(
      data: streaming ? heal(text) : text,
      softLineBreak: lineBreaks,
      builders: {'pre': _CodeBlockBuilder(s)},
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
        strong: const TextStyle(fontWeight: FontWeight.w600),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        // Inline code's background is a tint, not [codeBackground]: a
        // paragraph paints its selection under the text, and an opaque
        // background would hide the selection on code.
        code: s.code.copyWith(
          fontSize: size * 0.92,
          backgroundColor: (body.color ?? s.muted).withValues(alpha: 0.07),
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

/// Highlighted code blocks, by language, code and colors: a message is
/// built again for every chunk that streams in, and only its open block
/// changes.
final _spans = <(String, String, TextStyle, Object), TextSpan>{};

/// A fenced code block: its language and a copy button over the code,
/// highlighted when the language is known.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  new(this.style);

  final MarkdownStyle style;

  @override
  bool isBlockElement() => true;

  TextSpan _highlighted(String language, String code, TextStyle codeStyle) {
    final key = (language, code, codeStyle, style.highlight);
    if (_spans[key] case final span?) return span;
    final span =
        style.highlight(language, code, codeStyle) ??
        TextSpan(text: code, style: codeStyle);
    if (_spans.length >= 200) _spans.remove(_spans.keys.first);
    return _spans[key] = span;
  }

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeElement = element.children?.firstOrNull;
    final cls = codeElement is md.Element
        ? codeElement.attributes['class']
        : null;
    final language = cls?.startsWith('language-') ?? false
        ? cls!.substring('language-'.length)
        : '';
    var code = element.textContent;
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
    final codeStyle = style.code.copyWith(color: style.body.color);
    // Text draws a tab as one space.
    final shown = code.replaceAll('\t', '    ');
    final span = _highlighted(language, shown, codeStyle);
    final label = style.code.copyWith(fontSize: 11, color: style.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectionContainer.disabled(
          child: Container(
            height: 26,
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: style.border)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(language, style: label)),
                _CopyButton(code, color: style.muted),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(10),
          child: Text.rich(span, softWrap: false),
        ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  const new(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _copied ? 'Copied' : 'Copy',
    iconSize: 13,
    color: widget.color,
    visualDensity: VisualDensity.compact,
    onPressed: _copy,
    icon: Icon(_copied ? Icons.check : Icons.copy),
  );
}
