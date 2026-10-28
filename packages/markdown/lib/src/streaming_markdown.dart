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
    this.codeBlock,
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

  @override
  Widget build(BuildContext context) {
    final s = style;
    final body = s.body;
    final heading = body.copyWith(fontWeight: FontWeight.w600);
    final size = body.fontSize ?? 14;
    return MarkdownBody(
      data: streaming ? heal(text, markOpen: true) : text,
      softLineBreak: lineBreaks,
      blockSyntaxes: const [_HtmlAsText()],
      builders: {'pre': _CodeBlockBuilder(s, codeBlock)},
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

/// Highlighted code blocks, by language, code and colors: a message is
/// built again for every chunk that streams in, and only its open block
/// changes.
final _spans = <(String, String, TextStyle, Object), TextSpan>{};

/// A fenced code block: its language and a copy button over the code,
/// highlighted when the language is known.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  new(this.style, this.custom);

  final MarkdownStyle style;
  final Widget? Function(String language, String code, {required bool open})?
  custom;

  @override
  bool isBlockElement() => true;

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
    var language = cls?.startsWith('language-') ?? false
        ? cls!.substring('language-'.length)
        : '';
    // heal's mark on a block still streaming in: after the language, or
    // in its place when there's none.
    final open =
        language == openMark ||
        (element.attributes['data-metadata']?.endsWith(openMark) ?? false);
    if (language == openMark) language = '';
    var code = element.textContent;
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
    return custom?.call(language, code, open: open) ??
        CodeBlockView(language: language, code: code, style: style);
  }
}

/// A code block as [StreamingMarkdown] draws one: a bar with its language
/// ([MarkdownStyle.languageName]), [actions] and a copy button, over its
/// code highlighted, or over [body] when given; [footer] under.
class CodeBlockView extends StatelessWidget {
  /// The block of [code] in [language].
  const new({
    required this.language,
    required this.code,
    required this.style,
    super.key,
    this.actions = const [],
    this.body,
    this.footer,
  });

  /// The fence's language, as written.
  final String language;

  /// The block's text, which Copy copies.
  final String code;

  /// The markdown's colors and fonts.
  final MarkdownStyle style;

  /// More in the bar, before Copy.
  final List<Widget> actions;

  /// What shows in the code's place.
  final Widget? body;

  /// Under the code (or [body]).
  final Widget? footer;

  TextSpan _highlighted(String code, TextStyle codeStyle) {
    final key = (language, code, codeStyle, style.highlight);
    if (_spans[key] case final span?) return span;
    final span =
        style.highlight(language, code, codeStyle) ??
        TextSpan(text: code, style: codeStyle);
    if (_spans.length >= 200) _spans.remove(_spans.keys.first);
    return _spans[key] = span;
  }

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    style.languageName?.call(language) ?? language,
                    style: label,
                  ),
                ),
                ...actions,
                _CopyButton(code, color: style.muted),
              ],
            ),
          ),
        ),
        body ?? codeText(code),
        ?footer,
      ],
    );
  }

  /// [code] highlighted, scrolling sideways.
  Widget codeText(String code) {
    final codeStyle = style.code.copyWith(color: style.body.color);
    // Text draws a tab as one space.
    final span = _highlighted(code.replaceAll('\t', '    '), codeStyle);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(10),
      child: Text.rich(span, softWrap: false),
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
