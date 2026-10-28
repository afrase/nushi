import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/images.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// [href] as a link the app opens: http and https only. A file:, a
/// javascript: or an app's own scheme (an issue's text, an agent's reply)
/// could open something on the Mac.
Uri? webLink(String href) {
  final uri = Uri.tryParse(href.trim());
  return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

/// Agent markdown in the theme's fonts and colors. Links open in the
/// browser, http and https only; images as [markdownImage] shows them;
/// ```` ```mermaid ```` blocks as diagrams ([MermaidBlock]).
class AgentMarkdown extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.typed = false,
    this.live = false,
    this.images = markdownImage,
  });

  final String text;

  /// What an image shows as (Jira's text: only its attachments).
  final Widget Function(Uri uri, String? alt) images;

  /// The user typed it: its line breaks stay as typed, and it shows as a
  /// user message's band does, a size up, semibold, in the band's colors.
  final bool typed;

  /// It is still streaming in: half-written syntax is healed until it ends.
  /// A finished message shows as written ("[1, 2, 3]", "a*b").
  final bool live;

  static void _open(String href) {
    if (webLink(href) case final uri?) unawaited(launchUrl(uri));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = MarkdownStyle(
      body: typed
          ? theme.ui(t.userBandText, size: 13.5).copyWith(height: 1.5)
          : theme.ui(t.agentText, size: 13.5).copyWith(height: 1.5),
      code: theme.code(typed ? t.userBandText : t.agentText, size: 12.5),
      codeBackground: typed ? t.userBandCodeBlock : t.codeBlock,
      inlineCode: typed ? t.userBandCode : t.inlineCode,
      border: typed ? t.userBandBorder : t.borderSubtle,
      muted: typed ? t.userBandMuted : t.textMuted,
      link: t.link,
      highlight: codeHighlighter(t),
      languageName: languageName,
    );
    return StreamingMarkdown(
      text,
      streaming: live,
      lineBreaks: typed,
      onTapLink: _open,
      imageBuilder: images,
      style: style,
      codeBlock: (language, code, {required open}) => language == 'mermaid'
          ? MermaidBlock(code, style: style, open: open)
          : null,
    );
  }
}
