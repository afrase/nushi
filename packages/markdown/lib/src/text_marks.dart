import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

part 'marks.dart';

/// Where a [WidgetSpan] sits in a paragraph's plain text.
const _placeholder = '￼';

/// What of a match is in one paragraph; a match over widget spans (a file's
/// link, cut after its slashes) has a part in each.
typedef _Part = ({RenderParagraph paragraph, int start, int end});

/// A paragraph's plain text and the same lowered, by its span: a paragraph
/// that wasn't built again keeps its span.
final _texts = Expando<(String, String)>();

/// The matches of a query in [text], whose lowered form is [lower]. A few
/// characters change length when lowered: there [lower]'s offsets would be
/// of another text.
Iterable<Match> _matches(String query, String text, String lower) =>
    lower.length == text.length
    ? query.allMatches(lower)
    : RegExp(RegExp.escape(query), caseSensitive: false).allMatches(text);

/// One match of [TextMarks.query]: characters in a paragraph, or something
/// folded away in a [FoldedMarks].
class TextMark {
  new _(this.key, this.entry, this._by, this._parts);

  /// Its name: its [Marks.entry] and its place among that entry's marks.
  final String key;

  /// The entry it's in.
  final RenderBox entry;

  final _RenderMarks _by; // what paints it
  final List<_Part> _parts; // none: it's folded away in [_by]
  List<Rect>? _rects;

  /// Whether it's folded away, its row marked instead of its characters.
  bool get folded => _parts.isEmpty;

  /// Whether its text is still there: laid out again, it's a frame until
  /// the marks are found anew.
  bool get _here => _by.attached && _parts.every((p) => p.paragraph.attached);

  /// Its boxes in the coordinates of what paints it, once asked for: one
  /// to a line, whatever styles or spans it crosses (a tint laid twice
  /// would show where they meet).
  List<Rect> get _boxes {
    if (_rects case final rects?) return rects;
    final rects = <Rect>[];
    for (final p in _parts) {
      final to = p.paragraph.getTransformTo(_by);
      for (final box in _boxesOf(p)) {
        final r = MatrixUtils.transformRect(to, box.toRect());
        final last = rects.lastOrNull;
        if (last != null && r.top < last.bottom && r.bottom > last.top) {
          rects.last = last.expandToInclude(r);
        } else {
          rects.add(r);
        }
      }
    }
    return _rects = rects;
  }

  /// The box it shows in and where in that box, to bring it into view.
  (RenderBox, Rect) get place {
    if (_parts.isEmpty) return (_by, Offset.zero & _by.size);
    final part = _parts.first;
    final boxes = _boxesOf(part);
    return (
      part.paragraph,
      boxes.isEmpty
          ? Offset.zero & part.paragraph.size
          : boxes.map((b) => b.toRect()).reduce((a, b) => a.expandToInclude(b)),
    );
  }

  static List<TextBox> _boxesOf(_Part p) => p.paragraph.getBoxesForSelection(
    TextSelection(baseOffset: p.start, extentOffset: p.end),
  );
}

/// What a find marks in text under a [TextMarksScope]: every match of
/// [query], in the order of its entries ([look]), case aside, drawn under
/// the text by [Marks]. It reads the text as laid out and never touches it:
/// no span changes, so nothing is laid out again and a selection, a copy and
/// the text's own widgets are as they were. Painting under the text needs
/// nothing opaque between a [Marks] and the text.
///
/// Matches are found after a frame, in the entries that were laid out again:
/// [onFound] gets all of them then, in reading order.
class TextMarks {
  String _query = '';
  Color _hit = const Color(0x00000000);
  Color _now = const Color(0x00000000);
  Color _edge = const Color(0x00000000);
  List<String> _order = const [];
  final _roots = <String, _RenderMarks>{};
  List<TextMark> _marks = const [];
  TextMark? _current;
  bool _waiting = false;
  bool _gone = false;

  /// Takes every match after a frame that may have changed them.
  ValueChanged<List<TextMark>>? onFound;

  /// What's looked for, lowered; empty marks nothing.
  String get query => _query;

  /// Every match, in reading order.
  List<TextMark> get marks => _marks;

  /// The match drawn as the current one.
  TextMark? get current => _current;

  /// Looks for [query] in the entries named [order] (each a [Marks.entry],
  /// in reading order); a match is drawn in [hit], the current one in [now]
  /// with an [edge] around it.
  void look(
    String query,
    List<String> order, {
    required Color hit,
    required Color now,
    required Color edge,
  }) {
    final q = query.toLowerCase();
    if (q.isEmpty && _query.isEmpty) return;
    if (q != _query || hit != _hit || now != _now || edge != _edge) {
      _query = q;
      _hit = hit;
      _now = now;
      _edge = edge;
      _current = null;
      for (final r in _roots.values) {
        r._stale = true;
      }
      _order = order;
      _later();
    } else if (!listEquals(order, _order)) {
      _order = order;
      _later();
    }
  }

  /// Draws [mark] as the current one.
  void pick(TextMark? mark) {
    if (identical(mark, _current)) return;
    if (_current case final was? when was._by.attached) {
      was._by.markNeedsPaint();
    }
    _current = mark;
    if (mark != null && mark._by.attached) mark._by.markNeedsPaint();
  }

  /// No more scans; what's scheduled does nothing.
  void dispose() {
    _gone = true;
    onFound = null;
  }

  void _later() {
    if (_waiting) return;
    _waiting = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _waiting = false;
      if (!_gone) _scan();
    });
  }

  void _scan() {
    if (_query.isEmpty) {
      for (final m in _marks) {
        m._by._clear();
      }
      for (final r in _roots.values) {
        r._all = const [];
      }
      _marks = const [];
      _current = null;
      onFound?.call(_marks);
      return;
    }
    final all = <TextMark>[];
    for (final key in _order) {
      final root = _roots[key];
      if (root == null) continue;
      if (root._stale) _find(root);
      all.addAll(root._all);
    }
    _marks = all;
    onFound?.call(all);
  }

  /// [root]'s matches: each paragraph's, painted by the [Marks] nearest it,
  /// and a fold's. A paragraph's that are cut off (a row's long title) count
  /// as folded away in the row around them; with none, they don't show and
  /// aren't counted.
  void _find(_RenderMarks root) {
    root._stale = false;
    final key = root._entry!;
    final out = <TextMark>[];
    var by = root;
    _RenderMarks? fold;

    void add(_RenderMarks to, List<TextMark> list, List<_Part> parts) {
      final mark = TextMark._('$key ${out.length}', root, to, parts);
      list.add(mark);
      out.add(mark);
    }

    void place(RenderParagraph p, List<_Part> parts) {
      final cut = p.didExceedMaxLines && TextMark._boxesOf(parts.first).isEmpty;
      if (!cut) {
        add(by, by._painted, parts);
      } else if (fold case final f?) {
        add(f, f._folded, const []);
      }
    }

    void paragraph(RenderParagraph p) {
      if (p.registrar == null) return; // not the text's: a block's label
      final (text, lower) = _texts[p.text] ??= _lowered(
        p.text.toPlainText(includeSemanticsLabels: false),
      );
      if (!text.contains(_placeholder)) {
        for (final m in _matches(_query, text, lower)) {
          place(p, [(paragraph: p, start: m.start, end: m.end)]);
        }
        return;
      }
      final parts = <_Part>[];
      final (flat, flatLower) = _flatten(p, parts);
      final starts = _starts(parts);
      for (final m in _matches(_query, flat, flatLower)) {
        final inside = _slice(parts, starts, m.start, m.end);
        if (inside.isNotEmpty) place(p, inside);
      }
    }

    void visit(RenderObject o) {
      switch (o) {
        case _RenderUnmarked():
          return;
        case RenderParagraph():
          paragraph(o);
        case _RenderMarks():
          final (wasBy, wasFold) = (by, fold);
          o._begin();
          by = o;
          if (o._fold != null) fold = o;
          o.visitChildren(visit);
          if (o._fold != null) {
            final (text, lower) = o._lowered;
            for (final _ in _matches(_query, text, lower)) {
              add(o, o._folded, const []);
            }
          }
          o._end();
          (by, fold) = (wasBy, wasFold);
        default:
          o.visitChildren(visit);
      }
    }

    root
      .._begin()
      ..visitChildren(visit)
      .._end()
      .._all = out;
  }

  /// The text of [p] with that of the paragraphs in its widget spans in
  /// their place, lowered too, and each paragraph's [parts] of it.
  (String, String) _flatten(RenderParagraph p, List<_Part> parts) {
    final flat = StringBuffer();
    void add(RenderParagraph p) {
      final text = p.text.toPlainText(includeSemanticsLabels: false);
      final spans = <RenderObject>[];
      p.visitChildren(spans.add);
      var at = 0;
      for (final span in spans) {
        final end = text.indexOf(_placeholder, at);
        if (end < 0) break;
        parts.add((paragraph: p, start: at, end: end));
        flat.write(text.substring(at, end));
        if (_first(span) case final inner?) add(inner);
        at = end + 1;
      }
      parts.add((paragraph: p, start: at, end: text.length));
      flat.write(text.substring(at));
    }

    add(p);
    return _lowered(flat.toString());
  }

  static (String, String) _lowered(String text) => (text, text.toLowerCase());

  /// The first paragraph under [o].
  static RenderParagraph? _first(RenderObject o) {
    if (o is RenderParagraph) return o;
    RenderParagraph? found;
    o.visitChildren((c) => found ??= _first(c));
    return found;
  }

  /// Where each of [parts] starts in the flat text.
  static List<int> _starts(List<_Part> parts) {
    final out = <int>[];
    var at = 0;
    for (final p in parts) {
      out.add(at);
      at += p.end - p.start;
    }
    return out;
  }

  /// What of the flat text from [start] to [end] is in each of [parts].
  static List<_Part> _slice(
    List<_Part> parts,
    List<int> starts,
    int start,
    int end,
  ) => [
    for (final (i, p) in parts.indexed)
      if (start < starts[i] + p.end - p.start && end > starts[i])
        (
          paragraph: p.paragraph,
          start: p.start + (start - starts[i]).clamp(0, p.end - p.start),
          end: p.start + (end - starts[i]).clamp(0, p.end - p.start),
        ),
  ];
}
