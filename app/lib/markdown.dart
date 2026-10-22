import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Agent markdown, selectable, with code in a monospace font.
class AgentMarkdown extends StatelessWidget {
  const AgentMarkdown(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: text,
      selectable: true,
      // Agent text may come from anywhere: never fetch the images it names.
      imageBuilder: (uri, title, alt) => Text('[image: ${alt ?? uri}]'),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        code: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
