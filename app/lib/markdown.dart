import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'images.dart';
import 'theme/theme.dart';

/// Agent markdown in the theme's fonts and colors. Links open in the
/// browser, http and https only; images as [markdownImage] shows them.
class AgentMarkdown extends StatelessWidget {
  const AgentMarkdown(
    this.text, {
    super.key,
    this.typed = false,
    this.live = false,
  });

  final String text;

  /// The user typed it: its line breaks stay as typed.
  final bool typed;

  /// It is still streaming in: half-written syntax is healed until it ends.
  /// A finished message shows as written ("[1, 2, 3]", "a*b").
  final bool live;

  static void _open(String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    TextStyle c(Color color, {FontStyle? style}) =>
        TextStyle(color: color, fontStyle: style);
    return StreamingMarkdown(
      text,
      streaming: live,
      lineBreaks: typed,
      onTapLink: _open,
      imageBuilder: markdownImage,
      style: MarkdownStyle(
        body: theme.ui(t.text, size: 13.5).copyWith(height: 1.5),
        code: theme.code(t.text, size: 12.5),
        codeBackground: typed ? t.base : t.raised, // a message box is raised
        border: t.borderSubtle,
        muted: t.textMuted,
        link: t.link,
        highlight: {
          for (final k in ['keyword', 'built_in', 'type', 'literal', 'number'])
            k: c(t.keyword),
          for (final k in ['title', 'title.function_', 'title.class_'])
            k: c(t.function),
          for (final k in ['string', 'regexp', 'meta-string']) k: c(t.string),
          for (final k in ['comment', 'quote'])
            k: c(t.textMuted, style: FontStyle.italic),
        },
      ),
    );
  }
}
