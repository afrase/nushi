import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Text just revealed, from `start` to `end` of the whole message, drawn
/// at `opacity` as it fades in.
typedef FreshRun = ({int start, int end, double opacity});

// Characters of Unicode's private use area, which no one types: where the
// caret goes, and around a fresh run (its opacity in tenths after the
// opening one).
const _caret = '\u{E001}';
const _open = '\u{E002}';
const _close = '\u{E003}';

/// [tail] (the text from [at] on, raw) with [fresh] runs marked where it's
/// safe to draw them faded: within one line of prose, after something on
/// that line, outside code, links and any Markdown's syntax. Elsewhere a
/// run just shows.
String markFresh(String tail, int at, List<FreshRun> fresh) {
  if (fresh.isEmpty) return tail;
  final out = StringBuffer();
  var from = 0; // in tail
  for (final r in fresh) {
    var start = r.start - at;
    final end = r.end - at;
    if (end <= from || end > tail.length) continue;
    if (start < from) start = from;
    // Only the run's last line, and not from its start.
    final nl = tail.lastIndexOf('\n', end - 1);
    if (nl >= start) start = nl + 1;
    final lineStart = nl + 1;
    final before = tail.substring(lineStart, start);
    final run = tail.substring(start, end);
    if (run.trim().isEmpty ||
        before.trim().isEmpty ||
        _syntax.hasMatch(run) ||
        '`'.allMatches(before).length.isOdd ||
        '['.allMatches(before).length != ']'.allMatches(before).length ||
        before.trimLeft().startsWith('|')) {
      continue;
    }
    final tenths = (r.opacity * 10).round().clamp(0, 9);
    out
      ..write(tail.substring(from, start))
      ..write('$_open$tenths$run$_close');
    from = end;
  }
  out.write(tail.substring(from));
  return out.toString();
}

/// Whether [healed] (the tail, healed) can take the caret at its end: not
/// in a fence still open ([openMark] in it), not after a line break, a
/// table's row or what may yet be a rule or a heading's underline.
bool caretFits(String healed, String openMark) {
  if (healed.isEmpty || healed.endsWith('\n') || healed.contains(openMark)) {
    return false;
  }
  final last = healed.substring(healed.lastIndexOf('\n') + 1).trim();
  return last.isNotEmpty &&
      !last.startsWith('|') &&
      !RegExp(r'^[-=*_ ]+$').hasMatch(last);
}

/// [healed] with the caret's mark at its end.
String withCaret(String healed) => '$healed$_caret';

final _syntax = RegExp('[*_`~\\[\\]()<>\\\\|!#$_caret$_open$_close]');

/// The caret's and fresh runs' marks, parsed.
final streamSyntaxes = <md.InlineSyntax>[_CaretSyntax(), _FreshSyntax()];

/// The builders for [streamSyntaxes]: the [caret] in the line where the
/// text ends, taking no room; a fresh run in its paragraph's spans, at its
/// opacity, so it wraps as the rest.
Map<String, MarkdownElementBuilder> streamBuilders(Widget? caret) => {
  _CaretSyntax.tag: _CaretBuilder(caret),
  _FreshSyntax.tag: _FreshBuilder(),
};

class _CaretSyntax extends md.InlineSyntax {
  new() : super(_caret);

  static const tag = 'streamcaret';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty(tag));
    return true;
  }
}

class _FreshSyntax extends md.InlineSyntax {
  new() : super('$_open(\\d)([^$_close]*)$_close');

  static const tag = 'streamfresh';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text(tag, match[2]!)..attributes['tenths'] = match[1]!,
    );
    return true;
  }
}

class _CaretBuilder extends MarkdownElementBuilder {
  new(this.caret);

  final Widget? caret;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: caret ?? const SizedBox.shrink(),
        ),
      ],
    ),
  );
}

class _FreshBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final style = (parentStyle ?? const TextStyle()).merge(preferredStyle);
    final opacity = int.parse(element.attributes['tenths'] ?? '9') / 10;
    final color = style.color ?? const Color(0xFF000000);
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: style.copyWith(
          color: color.withValues(alpha: color.a * opacity),
        ),
      ),
    );
  }
}
