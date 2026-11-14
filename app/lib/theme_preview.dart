import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';

/// A small picture of Nushi in one set of a theme (ADR 0086), for its
/// picker (Settings › Appearance, the phone's Settings): the window's
/// background with the sidebar on it and the main pane beside it (ADR
/// 0111), a few chats (the open one, status dots, a chat's color), a
/// message of yours in its bubble, the agent's text with inline code, a
/// tool call's row, a subagent's line, a review's findings, and a code
/// block in the set's syntax colors. Drawn at [size] under a theme of
/// [tokens], then scaled to the width it's given, so every part takes its
/// colors and fonts as the app does, and a theme file's changes show.
class ThemePreview extends StatelessWidget {
  const new(this.tokens, {required this.dark, super.key});

  /// The set drawn.
  final Tokens tokens;

  /// The theme's dark set, for what's dark in both.
  final Tokens dark;

  /// The picture's size before it's scaled.
  static const size = Size(280, 168);

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: size.aspectRatio,
    child: FittedBox(
      child: SizedBox.fromSize(
        size: size,
        // Its own text size whatever the phone's: it's a picture. And the
        // bundled fonts whatever the app's (ADR 0114): its rows are laid
        // out to their measures, and what it shows is a theme's colors.
        child: MediaQuery.withNoTextScaling(
          child: Theme(
            data: NushiTheme(tokens, dark: dark).toThemeData(),
            child: const ExcludeSemantics(child: _Window()),
          ),
        ),
      ),
    ),
  );
}

/// A corner of the app's at the picture's scale: its rows are 17 high for
/// the app's 28, so about 0.6 of it.
double _small(double radius) => radius * 0.6;

/// A step of the app's type scale (docs/design.md) at the picture's scale.
double _type(double size) => _small(size);

class _Window extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ColoredBox(
      color: t.window,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 88, child: _Sidebar()),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 5, 5, 5),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.base,
                borderRadius: BorderRadius.circular(_small(NushiTheme.panel)),
              ),
              child: const _Transcript(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 8, 5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 0, 0, 3),
            child: Text(
              'lumen',
              style: theme.ui(
                t.textMuted,
                size: _type(13),
                weight: FontWeight.w600,
              ),
            ),
          ),
          _ChatRow('Paginate the feed', dot: t.running, open: true),
          _ChatRow('Atom feed summary', dot: t.needs, bar: t.avatars[3]),
          _ChatRow('Resize images', dot: t.done),
          _ChatRow('Dark default theme', dot: t.crashed, bar: t.avatars[2]),
          _ChatRow('Rewrite the quickstart', dot: t.idle),
        ],
      ),
    );
  }
}

/// A chat's row: its status [dot], its title, [open]'s fill, and a
/// chat's color as the chip at its end ([bar]).
class _ChatRow extends StatelessWidget {
  const new(this.title, {required this.dot, this.open = false, this.bar});

  final String title;
  final Color dot;
  final bool open;
  final Color? bar;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      height: 17,
      decoration: BoxDecoration(
        color: open ? t.accentSoft : null,
        borderRadius: BorderRadius.circular(_small(NushiTheme.control)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          spacing: 5,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(
                  open ? t.text : t.textSecondary,
                  size: _type(14),
                ),
              ),
            ),
            if (bar case final c?)
              Container(
                width: 7,
                height: 4,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(NushiTheme.pill),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final text = theme.ui(t.agentText, size: _type(14));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 5,
        children: [
          // A message of yours: a bubble at the right (ADR 0111).
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(
                color: t.userBand,
                borderRadius: BorderRadius.circular(_small(NushiTheme.panel)),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Paginate it with a cursor, '),
                    _code(context, '20', t.userBandCode),
                    const TextSpan(text: ' a page.'),
                  ],
                ),
                maxLines: 1,
                style: theme.ui(t.userBandText, size: _type(14)),
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                _code(context, 'ListPosts', t.inlineCode),
                const TextSpan(text: ' reads the whole table.'),
              ],
            ),
            maxLines: 1,
            style: text,
          ),
          _Row(
            fill: t.raised,
            icon: Icons.layers_outlined,
            accent: t.toolAccent,
            ink: t.textSecondary,
            lead: 'Read 2 files, ran 1 search',
          ),
          _Row(
            fill: t.subagentTint,
            icon: Icons.smart_toy_outlined,
            accent: t.subagentAccent,
            ink: t.subagentAccent,
            lead: 'Explore:',
            rest: ' Find every template',
          ),
          _Row(
            fill: t.raised,
            icon: Icons.fact_check_outlined,
            accent: t.findingsAccent,
            ink: t.text,
            lead: 'Review: 1 finding',
            trail: 'feed.go:42',
          ),
          const _Code(),
        ],
      ),
    );
  }
}

/// Inline code on its chip: [fill] behind the set's code ink.
InlineSpan _code(BuildContext context, String code, Color fill) {
  final theme = NushiTheme.of(context);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_small(NushiTheme.tag)),
      ),
      child: Text(
        code,
        style: theme.code(theme.t.inlineCodeText, size: _type(13)),
      ),
    ),
  );
}

/// A transcript's row (ADR 0111): a tool call's, a card's fill; a
/// subagent's line, its tint; the findings' head, a card's. Its [fill], an
/// [icon] in its [accent], [lead] in [ink] (semibold before [rest], in the
/// text's color) and [trail], a file, in the findings' accent at its end.
class _Row extends StatelessWidget {
  const new({
    required this.fill,
    required this.icon,
    required this.accent,
    required this.ink,
    required this.lead,
    this.rest,
    this.trail,
  });

  final Color fill;
  final IconData icon;
  final Color accent;
  final Color ink;
  final String lead;
  final String? rest;
  final String? trail;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(_small(NushiTheme.control)),
      ),
      child: Row(
        spacing: 4,
        children: [
          Icon(icon, size: 9, color: accent),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: rest == null
                        ? null
                        : const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (rest case final r?)
                    TextSpan(
                      text: r,
                      style: TextStyle(color: t.textSecondary),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.ui(ink, size: _type(13)),
            ),
          ),
          if (trail case final f?)
            Text(f, style: theme.code(t.findingsAccent, size: _type(12))),
        ],
      ),
    );
  }
}

/// A code block's sliver: a few lines in the set's syntax colors.
class _Code extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    TextSpan span(String text, [Capture? c]) {
      final ink = c == null ? null : t.ink(c);
      return TextSpan(
        text: text,
        style: TextStyle(
          color: ink?.color ?? t.text,
          fontStyle: (ink?.italic ?? false) ? FontStyle.italic : null,
          fontWeight: (ink?.bold ?? false) ? FontWeight.bold : null,
        ),
      );
    }

    final lines = [
      [span('// A page after the cursor.', Capture.comment)],
      [
        span('func ', Capture.keyword),
        span('Page', Capture.declaration),
        span('(after '),
        span('string', Capture.type),
        span(', n '),
        span('int', Capture.type),
        span(') {'),
      ],
      [
        span('  return '),
        span('q', Capture.parameter),
        span('.'),
        span('Limit', Capture.field),
        span('('),
        span('20', Capture.number),
        span(', '),
        span('"id"', Capture.string),
        span(')'),
      ],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: t.codeBlock,
        borderRadius: BorderRadius.circular(_small(NushiTheme.control)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (final (i, l) in lines.indexed) ...[
              if (i > 0) const TextSpan(text: '\n'),
              ...l,
            ],
          ],
        ),
        maxLines: lines.length,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: theme.code(t.text, size: _type(12)),
      ),
    );
  }
}
