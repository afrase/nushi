part of 'streaming_markdown.dart';

/// A file's path in plain text, written exactly as one of the paths given, with
/// nothing of a word, a path or a URL around it.
class _FilePathSyntax extends md.InlineSyntax {
  new(Iterable<String> paths) : super(_pattern(paths));

  static const tag = 'filepath';

  static String _pattern(Iterable<String> paths) {
    final longest = paths.toList()..sort((a, b) => b.length - a.length);
    return '(?<![\\w/.~:@-])(?:${longest.map(RegExp.escape).join('|')})(?![\\w/])';
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(tag, match[0]!));
    return true;
  }
}

/// One of the files a message names, in inline code or plain text, as a
/// link (its text in place, so it flows with the line); inline code that
/// isn't one stays as it was.
class _FileLinkBuilder extends MarkdownElementBuilder {
  new(this.files, this.onTap);

  final Map<String, String> files;
  final void Function(String path) onTap;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    final path = files[text.trim()];
    if (path == null) return null;
    // Widget spans: the spans of a paragraph's text are made again as
    // they're merged, without their hover. One a line tall each, cut after
    // its slashes: a paragraph's lines are all the one height, so a span
    // that wrapped would run into the line below it.
    final style = (parentStyle ?? const TextStyle()).merge(preferredStyle);
    final hover = ValueNotifier(false);
    return Text.rich(
      TextSpan(
        children: [
          for (final piece in _pieces(text))
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FileLink(
                piece,
                style: style,
                hover: hover,
                onTap: () => onTap(path),
              ),
            ),
        ],
      ),
    );
  }

  /// [path] cut after each slash, where a line may break: "a/b" is "a/"
  /// and "b".
  static Iterable<String> _pieces(String path) =>
      RegExp('[^/]*/|[^/]+').allMatches(path).map((m) => m[0]!);
}

/// A piece of a file's name in a message, as a link: the hand over it,
/// underlined, with the name's other pieces, while the pointer is over
/// one of them.
class FileLink extends StatelessWidget {
  /// [text] in [style], running [onTap] when clicked.
  const new(
    this.text, {
    required this.style,
    required this.hover,
    required this.onTap,
    super.key,
  });

  /// The piece as written.
  final String text;

  /// The text's style where it's written (inline code's, or the body's).
  final TextStyle style;

  /// Whether the pointer is over the name: shared by its pieces.
  final ValueNotifier<bool> hover;

  /// Opens the file.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => hover.value = true,
    onExit: (_) => hover.value = false,
    child: GestureDetector(
      onTap: onTap,
      child: ValueListenableBuilder(
        valueListenable: hover,
        builder: (context, over, _) => Text(
          text,
          style: over
              ? style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: style.color,
                )
              : style,
        ),
      ),
    ),
  );
}
