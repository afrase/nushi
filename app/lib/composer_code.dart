import 'package:flutter/painting.dart';
import 'package:nushi/theme/theme.dart';

/// Code in the composer's text, which shows in the code font: a closed pair
/// of single backticks on one line, or a fenced block from its opening
/// fence's line to its closing one. `open` and `close` are how long its
/// markers are at each end: a backtick for inline code, a fence's line for
/// a block.
typedef CodeRun = ({int start, int end, int open, int close});

/// A fenced block, as Markdown writes one: ``` at a line's start (three
/// spaces in at most), and the next line that is only a fence.
final _fence = RegExp(
  r'^ {0,3}```[^`\n]*\n[\s\S]*?^ {0,3}```[ \t]*$',
  multiLine: true,
);

/// Inline code: one backtick each side, not two or three (a fence's, or
/// Markdown's longer inline delimiters, left as typed).
final _inline = RegExp(r'(?<!`)`[^`\n]+`(?!`)');

/// The code in [text], in order: fenced blocks, then the inline code outside
/// them. An open backtick or fence isn't code yet, so typing one doesn't
/// turn the rest of the box into code.
List<CodeRun> codeRuns(String text) {
  final runs = <CodeRun>[];
  for (final m in _fence.allMatches(text)) {
    final open = text.indexOf('\n', m.start) + 1 - m.start;
    final close = m.end - text.lastIndexOf('\n', m.end - 1) - 1;
    runs.add((start: m.start, end: m.end, open: open, close: close));
  }
  final blocks = runs.length;
  var block = 0;
  for (final m in _inline.allMatches(text)) {
    while (block < blocks && runs[block].end <= m.start) {
      block++;
    }
    if (block < blocks && runs[block].start < m.end) continue;
    runs.add((start: m.start, end: m.end, open: 1, close: 1));
  }
  return runs..sort((a, b) => a.start.compareTo(b.start));
}

/// One style over part of a text, merged over what's under it.
typedef SpanPaint = (int start, int end, TextStyle style);

/// Whether [c] is inline code whose backticks show for [selection]: the
/// caret, or either end of a selection, strictly between them. Elsewhere
/// they're hidden, as Obsidian's live preview hides them, so closing the
/// code hides both and arrowing back in shows them.
bool showsTicks(CodeRun c, TextSelection selection) {
  bool inside(int at) => c.start < at && at < c.end;
  return selection.isValid &&
      (inside(selection.baseOffset) || inside(selection.extentOffset));
}

/// [code] painted as code in [base]'s place: the code font a size down, as
/// the transcript's inline code is, in its ink on its chip; the backticks
/// muted while [selection] is in it ([showsTicks]) and hidden otherwise; a
/// block's lines without the chip, its fence lines muted. Only the font
/// and its colors change: the box's line height is fixed by its strut (a
/// `TextField`'s default), so a line of code is as tall as one of prose and
/// the caret, the selection and the box's height are where they'd be.
///
/// A hidden backtick is still in the text, drawn at no size: it takes no
/// width and paints nothing, while what's sent, copied, undone and spell
/// checked is the text as typed, and the caret still steps over it.
List<SpanPaint> codePaints(
  List<CodeRun> code,
  TextStyle base,
  NushiTheme theme, {
  TextSelection selection = const TextSelection.collapsed(offset: -1),
}) {
  final t = theme.t;
  final mono = TextStyle(
    fontFamily: theme.codeFamily,
    fontFamilyFallback: theme.codeFallback,
    fontSize: (base.fontSize ?? 13) * 0.92,
    fontFeatures: const [
      FontFeature.disable('liga'),
      FontFeature.disable('calt'),
    ],
  );
  final inline = mono.copyWith(
    color: t.inlineCodeText,
    backgroundColor: t.inlineCode,
  );
  final marker = inline.copyWith(color: t.textMuted);
  // No size and no spacing: the box's text inherits the theme's letter
  // spacing, which a glyph of no size would still take.
  final hidden = marker.copyWith(fontSize: 0, letterSpacing: 0);
  final fence = mono.copyWith(color: t.textMuted);
  return [
    for (final c in code)
      if (c.open == 1) ...[
        (c.start, c.start + 1, showsTicks(c, selection) ? marker : hidden),
        (c.start + 1, c.end - 1, inline),
        (c.end - 1, c.end, showsTicks(c, selection) ? marker : hidden),
      ] else ...[
        (c.start, c.start + c.open, fence),
        (c.start + c.open, c.end - c.close, mono),
        (c.end - c.close, c.end, fence),
      ],
  ];
}

/// [text] as spans under [style], each of [layers]' paints merged over the
/// layers before it. A layer's paints are in order and don't overlap.
TextSpan paintedSpan(
  String text,
  TextStyle? style,
  List<List<SpanPaint>> layers,
) {
  final cuts = <int>{0, text.length};
  for (final layer in layers) {
    for (final (start, end, _) in layer) {
      cuts
        ..add(start)
        ..add(end);
    }
  }
  final at = cuts.toList()..sort();
  final next = List.filled(layers.length, 0);
  final spans = <TextSpan>[];
  for (var i = 0; i + 1 < at.length; i++) {
    final (from, to) = (at[i], at[i + 1]);
    if (from == to) continue;
    TextStyle? painted;
    for (var l = 0; l < layers.length; l++) {
      final layer = layers[l];
      while (next[l] < layer.length && layer[next[l]].$2 <= from) {
        next[l]++;
      }
      if (next[l] < layer.length && layer[next[l]].$1 <= from) {
        painted = painted?.merge(layer[next[l]].$3) ?? layer[next[l]].$3;
      }
    }
    spans.add(TextSpan(text: text.substring(from, to), style: painted));
  }
  return TextSpan(style: style, children: spans);
}
