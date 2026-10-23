import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/widgets.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/re_highlight.dart';

import 'theme/theme.dart';

/// The syntax colors of code, in diffs and the transcript's code blocks,
/// by capture id: the highlight.js scopes each colors, its color, and
/// whether it is italic.
const syntaxCaptures = ['keyword', 'function', 'string', 'comment'];
const _scopesOf = [
  ['keyword', 'built_in', 'type', 'literal', 'number'],
  ['title', 'title.function_', 'title.class_'],
  ['string', 'regexp', 'meta-string'],
  ['comment', 'quote'],
];
List<(Color, bool)> _colors(Tokens t) => [
  (t.keyword, false),
  (t.function, false),
  (t.string, false),
  (t.textMuted, true),
];

/// highlight.js scopes to capture ids.
final _captures = {
  for (final (i, scopes) in _scopesOf.indexed)
    for (final k in scopes) k: i,
};

/// highlight.js scopes to their styles, for code blocks.
Map<String, TextStyle> highlightStyles(Tokens t) => {
  for (final MapEntry(key: k, value: i) in _captures.entries)
    k: TextStyle(
      color: _colors(t)[i].$1,
      fontStyle: _colors(t)[i].$2 ? FontStyle.italic : null,
    ),
};

/// Past this many characters a side isn't highlighted.
const _maxText = 200000;

final _highlight = Highlight()..registerLanguages(builtinAllLanguages);

/// The language of [path] by its extension (or name: `Makefile`), if
/// highlight.js knows it.
String? languageOf(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  for (final n in [if (dot >= 0) name.substring(dot + 1), name]) {
    if (_highlight.getLanguage(n) != null) return n.toLowerCase();
  }
  return null;
}

/// The syntax spans of each line of [old] and [neu] in [language], each side
/// highlighted as a whole, so multi-line strings and comments come out
/// right. Off the UI thread; null for a side too large to highlight.
Future<List<List<Uint32List?>?>> highlightSides(
  String language,
  String old,
  String neu,
) => Isolate.run(() {
  final h = Highlight()..registerLanguages(builtinAllLanguages);
  return [
    for (final text in [old, neu]) _lines(h, language, text),
  ];
});

List<Uint32List?>? _lines(Highlight h, String language, String text) {
  if (text.length > _maxText) return null;
  final spans = _Spans();
  h.highlight(code: text, language: language).render(spans);
  final s = spans.out, out = <Uint32List?>[];
  var start = 0, k = 0;
  for (final line in text.split('\n')) {
    final end = start + line.length;
    while (k < s.length && s[k] + s[k + 1] <= start) {
      k += 3;
    }
    final mine = <int>[];
    for (var j = k; j < s.length && s[j] < end; j += 3) {
      final a = max(s[j], start), b = min(s[j] + s[j + 1], end);
      if (b > a) mine.addAll([a - start, b - a, s[j + 2]]);
    }
    out.add(mine.isEmpty ? null : Uint32List.fromList(mine));
    start = end + 1;
  }
  return out;
}

/// Collects `(start, length, capture)` triples over the whole text: a
/// text run takes its innermost scope's color, as in the transcript.
class _Spans implements HighlightRenderer {
  final out = <int>[];
  final _scopes = <String?>[];
  var _at = 0;

  @override
  void addText(String text) {
    final c = _captures[_scopes.lastOrNull];
    if (c != null) out.addAll([_at, text.length, c]);
    _at += text.length;
  }

  @override
  void openNode(DataNode node) => _scopes.add(node.scope);

  @override
  void closeNode(DataNode node) => _scopes.removeLast();
}

/// [lines] with syntax spans once they're in ([highlight]), for
/// a diff view that is shown before they are.
class SyntaxLines implements DiffLineSource {
  SyntaxLines(MemoryLineSource lines, int oldCount, int newCount)
    : _sides = [
        for (final (side, n) in [
          (PaneSide.old, oldCount),
          (PaneSide.neu, newCount),
        ])
          [for (var i = 0; i < n; i++) lines.lineAt(side, i)!],
      ];

  final List<List<DiffLine>> _sides;
  final _listeners = <void Function()>[];

  /// Gives the lines their spans, by side (null leaves a side plain).
  void highlight(List<List<Uint32List?>?> spans) {
    for (final side in PaneSide.values) {
      final s = spans[side.index];
      if (s == null) continue;
      _sides[side.index] = [
        for (final l in _sides[side.index])
          l.line < s.length && s[l.line] != null
              ? DiffLine(
                  line: l.line,
                  text: l.text,
                  kind: l.kind,
                  block: l.block,
                  ending: l.ending,
                  inner: l.inner,
                  syntax: s[l.line],
                )
              : l,
      ];
    }
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  DiffLine? lineAt(PaneSide side, int line) =>
      _sides[side.index].elementAtOrNull(line);

  @override
  void prefetch(PaneSide side, ModelSpan span) {}

  @override
  Future<List<DiffLine>> load(PaneSide side, ModelSpan span) =>
      Future.value(_sides[side.index].sublist(span.start, span.end));

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);
}

/// The diff theme for [t]: diff_view's light or dark one, with the
/// transcript's code colors.
DiffThemeData diffTheme(Tokens t) {
  final d = t.brightness == Brightness.dark
      ? DiffThemeData.dark()
      : DiffThemeData.light();
  return DiffThemeData(
    brightness: d.brightness,
    background: d.background,
    text: d.text,
    gutterBackground: d.gutterBackground,
    gutterText: d.gutterText,
    gutterTextChanged: d.gutterTextChanged,
    insertedLine: d.insertedLine,
    insertedWord: d.insertedWord,
    deletedLine: d.deletedLine,
    deletedWord: d.deletedWord,
    modifiedLine: d.modifiedLine,
    modifiedWord: d.modifiedWord,
    ribbonInserted: d.ribbonInserted,
    ribbonDeleted: d.ribbonDeleted,
    ribbonModified: d.ribbonModified,
    dividerBackground: d.dividerBackground,
    selection: d.selection,
    selectionOverCap: d.selectionOverCap,
    foldPlaceholderBackground: d.foldPlaceholderBackground,
    foldPlaceholderText: d.foldPlaceholderText,
    loadingBar: d.loadingBar,
    hoverAffordance: d.hoverAffordance,
    syntax: {
      for (final (i, (color, italic)) in _colors(t).indexed)
        syntaxCaptures[i]: SyntaxStyle(color, italic: italic),
    },
  );
}
