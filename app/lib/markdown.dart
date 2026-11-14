import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/browser_address.dart' show isWebPage;
import 'package:nushi/browser_local.dart' show isLocalNetwork;
import 'package:nushi/github_link_chip.dart';
import 'package:nushi/images.dart';
import 'package:nushi/mermaid.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/preview.dart' show Previews;
import 'package:nushi/settings.dart' show linksInBrowserTab;
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart'
    show openInBrowserOrSay, openLinkOrSay, openOrSay;
import 'package:nushi/web_views.dart' show openInDefaultBrowser, webEmbedded;
import 'package:nushi/widgets.dart';

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

/// Opens a web link the user clicked in a chat (its messages, its tool
/// calls' output: what [AgentMarkdown] shows): a page on this Mac or the
/// local network in a browser tab beside the chat ([linkInTab]), else in
/// the default browser ([openWebOutside]).
/// Outside a chat's [Previews] (Jira, GitHub, the phone), it's the browser.
/// Without the app's own web views (Linux, ADR 0104) it's always the
/// browser, opened as every page there is ([openInBrowserOrSay]), which
/// says why when none opens.
Future<void> openWebLink(BuildContext context, Uri url) async {
  if (!kIsWeb && !webEmbedded) {
    await openInBrowserOrSay(context, url);
    return;
  }
  final previews = context.getInheritedWidgetOfExactType<Previews>();
  final browse = previews?.browse;
  final fits = previews?.browseFits?.call() ?? false;
  if (browse != null &&
      linkInTab(url, setting: linksInBrowserTab.value, fits: fits)) {
    browse(url);
    return;
  }
  await openOrSay(context, () => openWebOutside(url));
}

/// Whether a web link opens in a browser tab (ADR 0094): with Open local
/// links in built-in browser on ([setting]), the pane able to show beside
/// the chat ([fits]: a window too narrow for it would put it over the box),
/// and a page a tab loads (`isWebPage`: no user name) on this Mac or the
/// local network (`isLocalNetwork`: a dev server, a device). A site on the
/// internet opens in the browser (the owner, 2026-11-09).
bool linkInTab(Uri url, {required bool setting, required bool fits}) =>
    setting && fits && isWebPage(url) && isLocalNetwork(url.host);

/// Opens a web link in the default browser. Tests set their own.
Future<void> Function(Uri url) openWebOutside = openInDefaultBrowser;

/// Opens [url] in the browser, when it's a [webLink], saying under
/// [context] why when it doesn't open ([openLinkOrSay]).
void openWeb(BuildContext context, String url) {
  if (webLink(url) case final u?) unawaited(openLinkOrSay(context, u));
}

/// The host a link's [text] names when it reads as an address on another
/// host than [target]'s (`[https://github.com/…](https://evil.example)`),
/// else null: other people's text (a GitHub comment, a Jira issue, an
/// agent's reply) can dress one address as another.
String? linkTextElsewhere(String text, Uri target) {
  // What wraps an address in text (`<…>`, backticks, quotes) and ends a
  // sentence isn't part of it.
  final t = text.trim().replaceAll(
    RegExp(r'''^[<`'"(\[]+|[>`'")\].,;:!?]+$'''),
    '',
  );
  // An address: with its scheme, from www., a host and a path, or a bare
  // host ("github.com"; "a.md" is a file's name).
  final address =
      t.contains('://') ||
      t.toLowerCase().startsWith('www.') ||
      RegExp(r'^[^/]+\.[^/]+/').hasMatch(t) ||
      _bareHost(t);
  if (!address || t.contains(RegExp(r'\s'))) return null;
  final shown = Uri.tryParse(t.contains('://') ? t : 'https://$t');
  String bare(String host) =>
      host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (shown == null || !shown.host.contains('.')) return null;
  if (!const {'http', 'https'}.contains(shown.scheme)) return shown.host;
  return bare(shown.host) == bare(target.host) ? null : shown.host;
}

/// Whether [t] reads as a host alone: dot-separated names whose last is
/// letters, not a file's extension (README.md, main.go).
bool _bareHost(String t) {
  final m = RegExp(
    r'^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.([a-z]{2,24})$',
    caseSensitive: false,
  ).firstMatch(t);
  return m != null && !_extensions.contains(m[1]!.toLowerCase());
}

/// File extensions a file's name in a reply often ends in, some of them
/// top-level domains too (.md, .sh, .rs): such text is a file's name.
const _extensions = {
  'bash', 'bat', 'bin', 'c', 'cc', 'cfg', 'cjs', 'conf', 'cpp', 'cs', //
  'css', 'csv', 'dart', 'db', 'diff', 'dmg', 'env', 'exe', 'fish', 'gif',
  'go', 'gradle', 'gz', 'h', 'heic', 'hpp', 'htm', 'html', 'ico', 'ini',
  'ipynb', 'jar', 'java', 'jpeg', 'jpg', 'js', 'json', 'jsonl', 'jsx',
  'kt', 'kts', 'less', 'lock', 'log', 'lua', 'md', 'mdx', 'mjs', 'mk',
  'mod', 'mov', 'mp3', 'mp4', 'patch', 'pdf', 'php', 'pl', 'plist', 'png',
  'proto', 'ps1', 'py', 'rb', 'rs', 'rst', 'sass', 'scss', 'sh', 'sql',
  'sqlite', 'sum', 'svg', 'swift', 'tar', 'tgz', 'toml', 'ts', 'tsx',
  'txt', 'wasm', 'wav', 'webp', 'xml', 'yaml', 'yml', 'zip', 'zsh',
};

/// Agent markdown in the theme's fonts and colors. Links open in a
/// browser tab or the browser ([openWebLink]), http and https only, a link
/// whose text names another address only once the user saw where it goes;
/// images as [markdownImage] shows them;
/// ```` ```mermaid ```` blocks as diagrams ([MermaidBlock]).
class AgentMarkdown extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.typed = false,
    this.live = false,
    this.images = markdownImage,
    this.files,
    this.onTapFile,
    this.shown,
    this.transcript = false,
    this.codeBlock,
    this.headingMark,
    this.chips = false,
  });

  /// It's a message: a pull request's or an issue's address in it is a
  /// chip with a hover card, under a [GitHubLinks] (ADR 0117). Tool output
  /// and code stay as written.
  final bool chips;

  final String text;

  /// A whole fenced block other than a diagram as it shows instead, or
  /// null for the usual one (an agent's shell block, which runs).
  final Widget? Function(String language, String code, MarkdownStyle style)?
  codeBlock;

  /// While it's paced ([Paced]): what shows, faded in, and the caret.
  final Shown? shown;

  /// It's a message in a transcript: on the Mac, a size and a line up from
  /// other Markdown (ADR 0072).
  final bool transcript;

  /// Marks each heading where it starts, for an outline (a preview's,
  /// `markdown_outline.dart`).
  final HeadingMarkBuilder? headingMark;

  /// What an image shows as (Jira's text: only its attachments).
  final Widget Function(Uri uri, String? alt) images;

  /// The user typed it: its line breaks stay as typed, and it shows as a
  /// user message's band does, a size up, semibold, in the band's colors.
  final bool typed;

  /// It is still streaming in: half-written syntax is healed until it ends.
  /// A finished message shows as written ("[1, 2, 3]", "a*b").
  final bool live;

  /// Paths of files that are links, as written, to what [onTapFile] opens
  /// ([StreamingMarkdown.files]).
  final Map<String, String>? files;
  final void Function(String path)? onTapFile;

  static Future<void> _open(
    BuildContext context,
    String href,
    String text,
  ) async {
    final uri = webLink(href);
    if (uri == null) return;
    if (linkTextElsewhere(text, uri) case final shown?) {
      if (!await confirm(
            context,
            'Open ${uri.host}?',
            'The link reads $shown, but it goes to $uri.',
            'Open',
          ) ||
          !context.mounted) {
        return;
      }
    }
    await openWebLink(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final large = transcript && !TouchTargets.of(context);
    final size = large ? 14.0 : 13.0;
    final style = MarkdownStyle(
      body: theme
          .ui(typed ? t.userBandText : t.agentText, size: size)
          .copyWith(height: large ? 22 / 14 : 1.5),
      code: theme.code(typed ? t.userBandText : t.agentText, size: 12),
      codeBackground: typed ? t.userBandCodeBlock : t.codeBlock,
      // A control's corners, as a diff and a quote have.
      codeRadius: NushiTheme.control,
      inlineCode: typed ? t.userBandCode : t.inlineCode,
      inlineCodeColor: t.inlineCodeText,
      border: t.line,
      quote: t.quote,
      muted: typed ? t.userBandMuted : t.textMuted,
      link: t.link,
      highlight: codeHighlighter(t),
      languageName: languageName,
    );
    final shown = this.shown;
    // Inside whatever it's on: a message's bubble.
    return Marks(
      child: StreamingMarkdown(
        shown?.text ?? text,
        streaming: live || shown != null,
        fresh: shown?.fresh ?? const [],
        caret: shown == null || shown.caret <= 0
            ? null
            : SoftCaret(opacity: shown.caret),
        lineBreaks: typed,
        onTapLink: (href, text) => unawaited(_open(context, href, text)),
        imageBuilder: images,
        style: style,
        files: files,
        onTapFile: onTapFile,
        headingMark: headingMark,
        linkBuilder: chips && mayHoldGitHubLinks(text)
            ? (context, href, text, style) => githubLink(
                context,
                href,
                text,
                style,
                typed: typed,
                onOpen: () => unawaited(_open(context, href, text)),
              )
            : null,
        codeBlock: (language, code, {required open}) => language == 'mermaid'
            ? MermaidBlock(code, style: style, open: open)
            : open
            ? null
            : codeBlock?.call(language, code, style),
      ),
    );
  }
}
