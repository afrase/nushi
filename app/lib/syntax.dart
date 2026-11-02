import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/diff_find.dart';
import 'package:nushi/syntax_languages.dart';
import 'package:nushi/theme/theme.dart';
import 'package:re_highlight/re_highlight.dart';

/// highlight.js's scopes, as the common languages emit them, to the
/// captures they take; a dotted scope not listed takes its parent's
/// (`title.function` is `title`'s). null is plain: a string's
/// interpolation, operators. A scope not listed at all (`function` and
/// `class` around a declaration, an embedded `language:markdown`) takes
/// the capture of the scope it's in.
const Map<String, Capture?> _scopes = {
  'keyword': Capture.keyword,
  'built_in': Capture.keyword,
  'literal': Capture.keyword,
  'variable.language': Capture.keyword,
  'char.escape': Capture.keyword,
  'template-tag': Capture.keyword,
  'template-variable': Capture.keyword,
  'section': Capture.keyword,
  'bullet': Capture.keyword,
  'title': Capture.declaration,
  'title.function.invoke': null,
  'title.class.inherited': Capture.type,
  'link': Capture.declaration,
  'type': Capture.type,
  'string': Capture.string,
  'meta-string': Capture.string,
  'meta.string': Capture.string,
  'code': Capture.string,
  'subst': null,
  'number': Capture.number,
  'regexp': Capture.regexp,
  'variable.constant': Capture.constant,
  'variable': Capture.field,
  'property': Capture.field,
  'attr': Capture.field,
  'attribute': Capture.field,
  'symbol': Capture.symbol,
  'params': Capture.parameter,
  'meta': Capture.meta,
  'tag': Capture.tag,
  'name': Capture.tag,
  'selector-tag': Capture.tag,
  'selector-class': Capture.tag,
  'selector-id': Capture.tag,
  'selector-attr': Capture.tag,
  'selector-pseudo': Capture.tag,
  'comment': Capture.comment,
  'quote': Capture.comment,
  'doctag': Capture.docTag,
  'operator': null,
  'punctuation': null,
};

/// diff_view's capture names, by capture id ([Capture.index]).
final List<String> syntaxCaptures = [
  for (final c in Capture.values) c.name,
  _findCapture,
  _findNowCapture,
];

/// The captures of a find's hits in a diff, past the syntax's own.
const _findCapture = 'find';
const _findNowCapture = 'findNow';

/// Whether [scope] is listed (itself or a parent), and its capture.
(bool, Capture?) _lookup(String scope) {
  var s = scope;
  while (true) {
    if (_scopes.containsKey(s)) return (true, _scopes[s]);
    final dot = s.lastIndexOf('.');
    if (dot < 0) return (false, null);
    s = s.substring(0, dot);
  }
}

/// Highlights a code block in a language over its style, in [t]'s colors
/// (a diff's), or gives null for a language highlight.js doesn't know, or
/// a block over [maxBlock] characters. The same function for the same [t],
/// since code blocks are kept by it.
TextSpan? Function(String language, String code, TextStyle style)
codeHighlighter(Tokens t) =>
    _highlighters[t] ??= (language, code, style) =>
        _highlightCode(t, language, code, style);

final _highlighters = <Tokens, TextSpan? Function(String, String, TextStyle)>{};

TextSpan? _highlightCode(
  Tokens t,
  String language,
  String code,
  TextStyle style,
) {
  if (code.length > maxBlock || _highlight.getLanguage(language) == null) {
    return null;
  }
  final spans = _Spans();
  _highlight.highlight(code: code, language: language).render(spans);
  final s = spans.out;
  final children = <TextSpan>[];
  var at = 0;
  for (var i = 0; i < s.length; i += 3) {
    if (s[i] > at) children.add(TextSpan(text: code.substring(at, s[i])));
    final ink = t.ink(Capture.values[s[i + 2]]);
    children.add(
      TextSpan(
        text: code.substring(s[i], s[i] + s[i + 1]),
        style: TextStyle(
          color: ink.color,
          fontStyle: ink.italic ? FontStyle.italic : null,
          fontWeight: ink.bold ? FontWeight.w700 : null,
        ),
      ),
    );
    at = s[i] + s[i + 1];
  }
  if (at < code.length) children.add(TextSpan(text: code.substring(at)));
  return TextSpan(style: style, children: children);
}

/// Past this many characters a side isn't highlighted.
const _maxText = 200000;

/// Past this many characters a message's code block shows plain: it's
/// highlighted on the UI thread (20,000 took about 55 ms in a debug test,
/// ```console a little more, 200,000 1.5 s).
const maxBlock = 20000;

final Highlight _highlight = _highlighter();

Highlight _highlighter() {
  final h = Highlight()..registerLanguages(syntaxLanguages);
  syntaxAliases.forEach((language, tags) => h.registerAliases(tags, language));
  return h;
}

/// A code block's language by name ("Ruby" for `rb`), if there's a grammar
/// of its own; else the tag as written.
String languageName(String tag) => switch (tag) {
  'mermaid' => 'Mermaid',
  _ when syntaxAliases.values.any((a) => a.contains(tag.toLowerCase())) => tag,
  _ => _highlight.getLanguage(tag)?.name ?? tag,
};

/// The language of [path] by its extension (or name: `Makefile`), if
/// there's one for it.
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
  final h = _highlighter();
  return [
    for (final text in [old, neu]) _lines(h, language, text),
  ];
});

List<Uint32List?>? _lines(Highlight h, String language, String text) {
  if (text.length > _maxText) return null;
  final spans = _Spans();
  h.highlight(code: text, language: language).render(spans);
  final s = spans.out;
  final out = <Uint32List?>[];
  var start = 0;
  var k = 0;
  for (final line in text.split('\n')) {
    final end = start + line.length;
    while (k < s.length && s[k] + s[k + 1] <= start) {
      k += 3;
    }
    final mine = <int>[];
    for (var j = k; j < s.length && s[j] < end; j += 3) {
      final a = max(s[j], start);
      final b = min(s[j] + s[j + 1], end);
      if (b > a) mine.addAll([a - start, b - a, s[j + 2]]);
    }
    out.add(mine.isEmpty ? null : Uint32List.fromList(mine));
    start = end + 1;
  }
  return out;
}

/// Collects `(start, length, capture)` triples over the whole text, in
/// order: a text run takes the capture of the innermost scope it's in that
/// is listed in [_scopes].
class _Spans implements HighlightRenderer {
  final out = <int>[];
  final _in = <Capture?>[];
  var _at = 0;

  @override
  void addText(String text) {
    if (_in.lastOrNull case final c?) {
      final n = out.length;
      // The same capture just before (a scope's text split by a plain
      // child's): one span.
      if (n > 0 && out[n - 1] == c.index && out[n - 3] + out[n - 2] == _at) {
        out[n - 2] += text.length;
      } else {
        out.addAll([_at, text.length, c.index]);
      }
    }
    _at += text.length;
  }

  @override
  void openNode(DataNode node) {
    final (listed, c) = switch (node.scope) {
      final s? => _lookup(s),
      null => (false, null),
    };
    _in.add(listed ? c : _in.lastOrNull);
  }

  @override
  void closeNode(DataNode node) => _in.removeLast();
}

/// `lines` with syntax spans once they're in (`highlight`), for
/// a diff view that is shown before they are.
class SyntaxLines implements DiffLineSource {
  new(MemoryLineSource lines, int oldCount, int newCount)
    : _sides = [
        for (final (side, n) in [
          (PaneSide.old, oldCount),
          (PaneSide.neu, newCount),
        ])
          [for (var i = 0; i < n; i++) lines.lineAt(side, i)!],
      ];

  final List<List<DiffLine>> _sides;
  final _listeners = <void Function()>[];
  List<DiffHit> _hits = const [];
  DiffHit? _now;
  // The lines with hits on them, as drawn, by side and line.
  Map<(PaneSide, int), DiffLine> _marked = const {};

  /// Marks a find's [hits], [now] the current one (none clears them).
  void mark(List<DiffHit> hits, DiffHit? now) {
    _hits = hits;
    _now = now;
    _mark();
    _tell();
  }

  void _mark() {
    final byLine = <(PaneSide, int), List<DiffHit>>{};
    for (final h in _hits) {
      (byLine[(h.side, h.line)] ??= []).add(h);
    }
    _marked = {
      for (final MapEntry(key: (side, line), value: hits) in byLine.entries)
        (side, line): markHits(
          _sides[side.index][line],
          hits,
          _now,
          mark: Capture.values.length,
          markNow: Capture.values.length + 1,
        ),
    };
  }

  void _tell() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  /// Gives the lines their spans, by side (null leaves a side plain).
  void highlight(List<List<Uint32List?>?> spans) {
    for (final side in PaneSide.values) {
      final s = spans[side.index];
      if (s == null) continue;
      _sides[side.index] = [
        for (final l in _sides[side.index])
          if (l.line < s.length && s[l.line] != null)
            DiffLine(
              line: l.line,
              text: l.text,
              kind: l.kind,
              block: l.block,
              ending: l.ending,
              inner: l.inner,
              syntax: s[l.line],
            )
          else
            l,
      ];
    }
    _mark();
    _tell();
  }

  @override
  DiffLine? lineAt(PaneSide side, int line) =>
      _marked[(side, line)] ?? _sides[side.index].elementAtOrNull(line);

  @override
  void prefetch(PaneSide side, ModelSpan span) {}

  @override
  Future<List<DiffLine>> load(PaneSide side, ModelSpan span) => Future.value([
    for (var i = span.start; i < span.end; i++) lineAt(side, i)!,
  ]);

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
      for (final MapEntry(key: c, value: ink) in t.syntax.entries)
        c.name: SyntaxStyle(ink.color, italic: ink.italic, bold: ink.bold),
      _findCapture: SyntaxStyle(t.needs, bold: true),
      _findNowCapture: SyntaxStyle(t.accentInk, bold: true),
    },
  );
}
