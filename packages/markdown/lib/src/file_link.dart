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
    // A widget span: the spans of a paragraph's text are made again as
    // they're merged, without their hover.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FileLink(
              text,
              style: (parentStyle ?? const TextStyle()).merge(preferredStyle),
              onTap: () => onTap(path),
            ),
          ),
        ],
      ),
    );
  }
}

/// A file's name in a message, as a link: the hand over it, underlined
/// while the pointer is.
class FileLink extends StatefulWidget {
  /// [text] in [style], running [onTap] when clicked.
  const new(this.text, {required this.style, required this.onTap, super.key});

  /// The path as written.
  final String text;

  /// The text's style where it's written (inline code's, or the body's).
  final TextStyle style;

  /// Opens the file.
  final VoidCallback onTap;

  @override
  State<FileLink> createState() => _FileLinkState();
}

class _FileLinkState extends State<FileLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Text(
        widget.text,
        style: _hover
            ? widget.style.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: widget.style.color,
              )
            : widget.style,
      ),
    ),
  );
}
