part of 'streaming_markdown.dart';

/// Highlighted code blocks, by language, code and colors: a message is
/// built again for every chunk that streams in, and only its open block
/// changes. Kept while their code is [_spansBudget] characters at most in
/// all ([_spansChars]), the oldest going first: by count, a few long blocks
/// would hold far more.
final _spans = <(String, String, TextStyle, Object), TextSpan>{};
var _spansChars = 0;
const _spansBudget = 2000000;

/// Code blocks still streaming in, the last few: each one's whole lines
/// highlighted so far, kept as more come.
final _streaming = <_Streaming>[];

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
    var code = unmarked(element.textContent);
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);
    return custom?.call(language, code, open: open) ??
        CodeBlockView(language: language, code: code, style: style, open: open);
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
    this.open = false,
  });

  /// Still streaming in: its whole lines are highlighted once each, in
  /// runs kept as more come, and its last line plain until it ends.
  final bool open;

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
    while (_spans.isNotEmpty && _spansChars + code.length > _spansBudget) {
      _spansChars -= _spans.keys.first.$2.length;
      _spans.remove(_spans.keys.first);
    }
    _spansChars += code.length;
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

  /// [code] highlighted, scrolling sideways. While [open], in groups of
  /// lines, each its own paragraph: one that's done isn't laid out again.
  Widget codeText(String code) {
    final codeStyle = style.code.copyWith(color: style.body.color);
    // Text draws a tab as one space.
    final text = code.replaceAll('\t', '    ');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(10),
      child: open
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final span in _Streaming.of(
                  text,
                  language,
                  codeStyle,
                  style,
                ).spans(text))
                  Text.rich(span, softWrap: false),
              ],
            )
          : Text.rich(_highlighted(text, codeStyle), softWrap: false),
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

/// A [CodeBlockView.open] block, highlighted a run of whole lines at a time:
/// the lines that came since, from the top level of the language, unless
/// the last run ended inside a token (a comment or a string going on to
/// the next line), which is then highlighted again with them. Runs no
/// longer last are final, and make groups of at least [_group] lines, each
/// drawn as its own paragraph. Once whole, the block is highlighted as one.
class _Streaming {
  new(this.language, this.codeStyle, this.style);

  /// The one for [code]'s block: the same language and colors, and its
  /// lines so far start [code]; else a new one.
  factory of(
    String code,
    String language,
    TextStyle codeStyle,
    MarkdownStyle s,
  ) {
    for (final b in _streaming.reversed) {
      if (b.language == language &&
          b.codeStyle == codeStyle &&
          b.style.highlight == s.highlight &&
          code.startsWith(b._done)) {
        _streaming
          ..remove(b)
          ..add(b);
        return b;
      }
    }
    if (_streaming.length >= 4) _streaming.removeAt(0);
    final b = _Streaming(language, codeStyle, s);
    _streaming.add(b);
    return b;
  }

  static const _group = 40;

  final String language;
  final TextStyle codeStyle;
  final MarkdownStyle style;
  final _runs = <_Run>[];
  var _done = ''; // the runs' text
  final _groups = <TextSpan>[]; // of the first [_grouped] runs
  var _grouped = 0;
  (String, List<TextSpan>)? _last; // the code last asked for, its spans

  /// [code]'s spans: the groups done, then the rest with its last line
  /// plain.
  List<TextSpan> spans(String code) {
    if (_last case (final c, final spans) when c == code) return spans;
    if (!code.startsWith(_done)) {
      _runs.clear();
      _groups.clear();
      _grouped = 0;
      _done = '';
    }
    final whole = code.lastIndexOf('\n') + 1;
    if (whole > _done.length) {
      var from = _done.length;
      if (_runs.length > _grouped && !_runs.last.plain) {
        from -= _runs.removeLast().text.length;
      }
      final text = code.substring(from, whole);
      final span =
          style.highlight(language, text, codeStyle) ??
          TextSpan(text: text, style: codeStyle);
      _runs.add(_Run(text, span));
      _done = code.substring(0, whole);
    }
    // Runs before the last are final: group them.
    var lines = 0;
    for (var i = _grouped; i < _runs.length - 1; i++) {
      lines += _runs[i].lines;
      if (lines < _group) continue;
      _groups.add(
        TextSpan(
          style: codeStyle,
          children: [
            for (final r in _runs.sublist(_grouped, i)) r.span,
            // The line break before the next group is the paragraph's.
            _withoutLastBreak(_runs[i].span),
          ],
        ),
      );
      _grouped = i + 1;
      lines = 0;
    }
    final spans = [
      ..._groups,
      TextSpan(
        style: codeStyle,
        children: [
          for (final r in _runs.skip(_grouped)) r.span,
          if (whole < code.length) TextSpan(text: code.substring(whole)),
        ],
      ),
    ];
    _last = (code, spans);
    return spans;
  }
}

/// Whole lines of an open block, highlighted together.
class _Run {
  new(this.text, this.span)
    : lines = '\n'.allMatches(text).length,
      plain = _endsPlain(span);

  final String text;
  final TextSpan span;
  final int lines;

  /// The highlighter ended outside any token.
  final bool plain;
}

/// Whether [span]'s last character is drawn in no style of its own (only
/// the block's): the highlighter ended outside any token.
bool _endsPlain(TextSpan span) {
  bool? last(InlineSpan s, {required bool styled}) {
    if (s is! TextSpan) return null;
    final children = s.children ?? const <InlineSpan>[];
    for (final c in children.reversed) {
      final plain = last(c, styled: styled || c.style != null);
      if (plain != null) return plain;
    }
    return s.text?.isNotEmpty ?? false ? !styled : null;
  }

  return last(span, styled: false) ?? true;
}

/// [span] without the line break its text ends with.
InlineSpan _withoutLastBreak(InlineSpan span) {
  if (span is! TextSpan) return span;
  final children = span.children ?? const <InlineSpan>[];
  for (var i = children.length - 1; i >= 0; i--) {
    if (children[i].toPlainText().isEmpty) continue;
    return TextSpan(
      text: span.text,
      style: span.style,
      children: [...children.take(i), _withoutLastBreak(children[i])],
    );
  }
  final text = span.text ?? '';
  return TextSpan(
    text: text.endsWith('\n') ? text.substring(0, text.length - 1) : text,
    style: span.style,
  );
}
