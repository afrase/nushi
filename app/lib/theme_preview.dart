import 'package:flutter/material.dart';

import 'package:nushi/theme/theme.dart';

/// A small picture of Nushi in one set of a theme (ADR 0086), for its
/// picker (Settings › Appearance, the phone's Settings): the sidebar with
/// a few chats (the open one, status dots, a chat's color bar), a user
/// band, the agent's text with inline code, a tool call's row, a
/// subagent's line, a review's findings, and a code block in the set's
/// syntax colors. Drawn at [size] under a theme of [tokens], then scaled
/// to the width it's given, so every part takes its colors and fonts as
/// the app does, and a theme file's changes show.
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
        // Its own text size whatever the phone's: it's a picture.
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

class _Window extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ColoredBox(
      color: t.base,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 88,
            decoration: BoxDecoration(
              color: t.raised,
              border: Border(right: BorderSide(color: t.borderSubtle)),
            ),
            child: const _Sidebar(),
          ),
          const Expanded(child: _Transcript()),
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
              style: theme.ui(t.text, size: 9, weight: FontWeight.w600),
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
/// chat's color as the [bar] at its left.
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
        borderRadius: BorderRadius.circular(NushiTheme.tagWas3),
      ),
      child: Stack(
        children: [
          Padding(
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
                    style: theme.ui(open ? t.text : t.textSecondary, size: 8.5),
                  ),
                ),
              ],
            ),
          ),
          if (bar case final c?)
            Positioned(
              left: 0,
              top: 3,
              bottom: 3,
              child: Container(width: 2, color: c),
            ),
        ],
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
    final text = theme.ui(t.agentText, size: 8.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: t.userBand,
            border: Border(bottom: BorderSide(color: t.userBandBorder)),
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
            style: theme.ui(t.userBandText, size: 8.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
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
                fill: t.toolTint,
                border: t.toolBorder,
                icon: Icons.layers_outlined,
                accent: t.toolAccent,
                lead: 'Read 2 files, ran 1 search',
              ),
              _Row(
                fill: t.subagentTint,
                border: t.subagentBorder,
                icon: Icons.smart_toy_outlined,
                accent: t.subagentAccent,
                lead: 'Explore:',
                rest: ' Find every template',
              ),
              _Row(
                fill: t.findingsTint,
                border: t.findingsBorder,
                icon: Icons.fact_check_outlined,
                accent: t.findingsAccent,
                lead: 'Review: 1 finding',
                trail: 'feed.go:42',
              ),
              const _Code(),
            ],
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(NushiTheme.tagWas2),
      ),
      child: Text(code, style: theme.code(theme.t.inlineCodeText, size: 8)),
    ),
  );
}

/// A transcript's row: a tool call's, a subagent's line, the findings'
/// head; its [fill] and [border], an [icon] in its [accent], [lead] (and
/// [rest] after it) and [trail], a file, in the accent at its end.
class _Row extends StatelessWidget {
  const new({
    required this.fill,
    required this.border,
    required this.icon,
    required this.accent,
    required this.lead,
    this.rest,
    this.trail,
  });

  final Color fill;
  final Color border;
  final IconData icon;
  final Color accent;
  final String lead;
  final String? rest;
  final String? trail;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: box(border, fill: fill, radius: NushiTheme.tagWas3),
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
                  if (rest case final r?) TextSpan(text: r),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.ui(t.text, size: 8),
            ),
          ),
          if (trail case final f?)
            Text(f, style: theme.code(t.findingsAccent, size: 7.5)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: box(
        t.borderSubtle,
        fill: t.codeBlock,
        radius: NushiTheme.tagWas3,
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
        style: theme.code(t.text, size: 7.5),
      ),
    );
  }
}
