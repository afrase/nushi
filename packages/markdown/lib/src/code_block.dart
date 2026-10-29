part of 'streaming_markdown.dart';

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
