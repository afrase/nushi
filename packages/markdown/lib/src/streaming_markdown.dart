import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

import 'heal.dart';

/// The colors and fonts of [StreamingMarkdown].
@immutable
class MarkdownStyle {
  const MarkdownStyle({
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
  final Color codeBackground;
  final Color border;

  /// Quotes, a code block's language label and its copy button.
  final Color muted;
  final Color link;

  /// Syntax colors by highlight.js class (`keyword`, `string`, ...).
  final Map<String, TextStyle> highlight;
}

/// Markdown that may still be streaming in: healed before it is parsed (see
/// [heal]), with highlighted code blocks that scroll sideways. Images are
/// never fetched; their alt text shows instead. Put it in a [SelectionArea]
/// to select text.
class StreamingMarkdown extends StatelessWidget {
  const StreamingMarkdown(
    this.text, {
    super.key,
    required this.style,
    this.onTapLink,
  });

  final String text;
  final MarkdownStyle style;

  /// Runs when a link is clicked, with its destination.
  final void Function(String href)? onTapLink;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final body = s.body;
    final heading = body.copyWith(fontWeight: FontWeight.w600);
    final size = body.fontSize ?? 14;
    return MarkdownBody(
      data: heal(text),
      builders: {'pre': _CodeBlockBuilder(s)},
      onTapLink: (_, href, _) {
        if (href != null) onTapLink?.call(href);
      },
      imageBuilder: (uri, title, alt) =>
          Text('[image: ${alt ?? uri}]', style: body.copyWith(color: s.muted)),
      styleSheet: MarkdownStyleSheet(
        p: body,
        a: body.copyWith(color: s.link, decoration: TextDecoration.underline),
        em: const TextStyle(fontStyle: FontStyle.italic),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        code: s.code.copyWith(
          fontSize: size * 0.92,
          backgroundColor: s.codeBackground,
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

final _highlighter = Highlight()..registerLanguages(builtinAllLanguages);

/// A fenced code block: its language and a copy button over the code,
/// highlighted when the language is known.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder(this.style);

  final MarkdownStyle style;

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
    final cls = codeElement is md.Element ? codeElement.attributes['class'] : null;
    final language = cls?.startsWith('language-') ?? false
        ? cls!.substring('language-'.length)
        : '';
    var code = element.textContent;
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
    final codeStyle = style.code.copyWith(color: style.body.color);
    // Text draws a tab as one space.
    final shown = code.replaceAll('\t', '    ');
    TextSpan span = TextSpan(text: shown, style: codeStyle);
    if (_highlighter.getLanguage(language) != null) {
      final renderer = TextSpanRenderer(codeStyle, style.highlight);
      _highlighter.highlight(code: shown, language: language).render(renderer);
      span = renderer.span ?? span;
    }
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
  const _CopyButton(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
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
