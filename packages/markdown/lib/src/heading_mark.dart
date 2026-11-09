part of 'streaming_markdown.dart';

/// Draws a mark at the start of each heading, in its line and taking no
/// room, from the heading's level (1 to 6) and its text: where an outline
/// finds the headings it lists.
typedef HeadingMarkBuilder = Widget Function(int level, String text);

/// A heading's first child, standing for the mark: the heading itself, for
/// its level and text once its inline content is parsed.
class _HeadingMark extends md.Element {
  new(this.heading) : super.empty(markTag);

  static const markTag = 'heading-mark';

  final md.Element heading;
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
    final heading = element.heading;
    final level = int.tryParse(heading.tag.substring(1)) ?? 1;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: build(level, heading.textContent.trim()),
          ),
        ],
      ),
    );
  }
}
