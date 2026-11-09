part of 'streaming_markdown.dart';

/// Draws a mark at the start of each heading, in its line and taking no
/// room, from the heading's level (1 to 6) and its text: where an outline
/// finds the headings it lists.
typedef HeadingMarkBuilder = Widget Function(int level, String text);

/// [text]'s headings, in order, as [StreamingMarkdown] parses them for its
/// [HeadingMarkBuilder] once [text] has finished streaming: each one's level
/// and text, as its mark has them. An outline knows from them, before the
/// text is laid out, what its marks will say.
List<(int level, String text)> markdownHeadings(String text) {
  final doc = md.Document(
    blockSyntaxes: const [
      _HtmlAsText(),
      _MarkedHeader(),
      _MarkedSetextHeader(),
    ],
    extensionSet: md.ExtensionSet.gitHubFlavored,
    encodeHtml: false,
  );
  final found = <(int, String)>[];
  void walk(List<md.Node>? nodes) {
    for (final n in nodes ?? const <md.Node>[]) {
      if (n is _HeadingMark) {
        found.add((n.level, n.text));
      } else if (n is md.Element) {
        walk(n.children);
      }
    }
  }

  walk(doc.parseLines(const LineSplitter().convert(text)));
  return found;
}

/// A heading's first child, standing for the mark: the heading itself, for
/// its level and text once its inline content is parsed.
class _HeadingMark extends md.Element {
  new(this.heading) : super.empty(markTag);

  static const markTag = 'heading-mark';

  final md.Element heading;

  /// The heading's level, 1 to 6.
  int get level => int.tryParse(heading.tag.substring(1)) ?? 1;

  /// The heading's text, once its inline content is parsed.
  String get text => heading.textContent.trim();
}

/// [node] (a heading, or nothing) with a [_HeadingMark] first.
md.Node? _marked(md.Node? node) {
  if (node is md.Element && node.children != null) {
    node.children!.insert(0, _HeadingMark(node));
  }
  return node;
}

/// An ATX heading (`## Plans`), marked.
class _MarkedHeader extends md.HeaderSyntax {
  const new();

  @override
  md.Node parse(md.BlockParser parser) => _marked(super.parse(parser))!;
}

/// A setext heading (a line underlined with `===` or `---`), marked.
class _MarkedSetextHeader extends md.SetextHeaderSyntax {
  const new();

  @override
  md.Node? parse(md.BlockParser parser) => _marked(super.parse(parser));
}

/// The mark, as a widget in the heading's text: at the top of its first
/// line.
class _HeadingMarkBuilder extends MarkdownElementBuilder {
  new(this.build);

  final HeadingMarkBuilder build;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    if (element is! _HeadingMark) return null;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: build(element.level, element.text),
          ),
        ],
      ),
    );
  }
}
