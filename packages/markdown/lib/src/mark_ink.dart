part of 'text_marks.dart';

/// The colour a run in [color] is drawn in on a match's opaque [fill],
/// which is the match's tint over [background], the fill the text's
/// colours were chosen for (a code block's). A theme's code colours are
/// published for its background; on a find's tint the dimmest can all but
/// vanish, so the app moves them (Nushi: its code's contrast rule).
typedef MarkInk = Color Function(Color color, Color fill, Color background);

/// A paragraph's text again, its matches' characters in their ink and the
/// rest clear, laid out as the paragraph is: drawn over it, it recolours
/// the matches without touching the paragraph's spans (a change there
/// would lay the text out again and find the matches anew). Made once for
/// the paragraph's text and its matches, kept until either changes.
final class _Inked {
  new(this.text, this.ranges, this.constraints, this.fills, this.painter);

  final InlineSpan text;
  final List<(int, int, bool)> ranges;
  final BoxConstraints constraints;
  final Object fills; // the fills each kind of character is drawn for
  final TextPainter? painter; // null: nothing to draw again
}

extension on _RenderMarks {
  /// Each paragraph's matches painted here: (start, end, current).
  Map<RenderParagraph, List<(int, int, bool)>> _matchesByParagraph() {
    final current = _scope?._current;
    final byParagraph = <RenderParagraph, List<(int, int, bool)>>{};
    for (final m in _painted) {
      if (!m._here) continue;
      final now = identical(m, current);
      for (final p in m._parts) {
        (byParagraph[p.paragraph] ??= []).add((p.start, p.end, now));
      }
    }
    return byParagraph;
  }

  /// Draws the matches' text in ink over the paragraphs this paints marks
  /// under, where it names its background and the marks have an ink; not
  /// inside [selected], which [_inkSelected] draws for its own fills.
  void _ink(PaintingContext context, Offset offset, {Path? selected}) {
    final scope = _scope;
    final background = _background;
    final ink = scope?.ink;
    if (scope == null || background == null || ink == null) return;
    if (_painted.isEmpty) return;
    final hit = Color.alphaBlend(scope._hit, background);
    final nowFill = Color.alphaBlend(scope._now, background);
    final fills = (hit, nowFill);
    final canvas = context.canvas;
    for (final MapEntry(key: p, value: ranges)
        in _matchesByParagraph().entries) {
      if (!p.hasSize) continue;
      final inked = _inkedOf(
        _inked,
        p,
        ranges,
        fills,
        (c, {required now}) => ink(c, now ? nowFill : hit, background),
      );
      if (inked == null) continue;
      final at =
          offset +
          MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
      if (selected == null) {
        inked.paint(canvas, at);
        continue;
      }
      canvas
        ..save()
        ..clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(at & inked.size),
            selected,
          ),
        );
      inked.paint(canvas, at);
      canvas.restore();
    }
  }

  /// [p]'s text drawn again in ink, from [kept] while its text,
  /// constraints, [ranges] and [fills] are the same; [rest]: the ink of
  /// what's outside [ranges] (clear without it).
  TextPainter? _inkedOf(
    Map<RenderParagraph, _Inked> kept,
    RenderParagraph p,
    List<(int, int, bool)> ranges,
    Object fills,
    Color Function(Color color, {required bool now}) ink, {
    Color Function(Color color)? rest,
  }) {
    final had = kept[p];
    if (had != null &&
        identical(had.text, p.text) &&
        had.constraints == p.constraints &&
        had.fills == fills &&
        listEquals(had.ranges, ranges)) {
      return had.painter;
    }
    had?.painter?.dispose();
    kept.remove(p);
    final c = p.constraints;
    final text = _recoloured(p.text, ranges, ink, rest: rest);
    if (text == null) {
      kept[p] = _Inked(p.text, ranges, c, fills, null);
      return null;
    }
    final painter = TextPainter(
      text: text,
      textAlign: p.textAlign,
      textDirection: p.textDirection,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
      ellipsis: p.overflow == TextOverflow.ellipsis ? '…' : null,
      locale: p.locale,
      strutStyle: p.strutStyle,
      textWidthBasis: p.textWidthBasis,
      textHeightBehavior: p.textHeightBehavior,
    );
    final wraps = p.softWrap || p.overflow == TextOverflow.ellipsis;
    painter.layout(
      minWidth: c.minWidth,
      maxWidth: wraps ? c.maxWidth : double.infinity,
    );
    kept[p] = _Inked(p.text, ranges, c, fills, painter);
    return painter;
  }
}

const _clear = Color(0x00000000);

/// [span] with the same text and styles but each character's colour:
/// within one of [ranges] (start, end, current) its [ink], outside them
/// its [rest]; clear where that is its own colour (drawn over itself it
/// would thicken), and outside them without [rest]. Null with nothing to
/// recolour, or a widget in the text, which a painter can't lay out as
/// the paragraph does.
TextSpan? _recoloured(
  InlineSpan span,
  List<(int, int, bool)> ranges,
  Color Function(Color color, {required bool now}) ink, {
  Color Function(Color color)? rest,
}) {
  var at = 0;
  var any = false;
  var widget = false;
  InlineSpan walk(InlineSpan s, Color inherited) {
    if (s is! TextSpan) {
      widget = true;
      return s;
    }
    final color = s.style?.color ?? inherited;
    final pieces = <InlineSpan>[];
    final text = s.text;
    if (text != null && text.isNotEmpty) {
      final end = at + text.length;
      var from = at;
      while (from < end) {
        var to = end;
        Color? drawn;
        for (final (a, b, now) in ranges) {
          if (a > from && a < to) to = a;
          if (b > from && b < to) to = b;
          if (a <= from && b > from) drawn = ink(color, now: now);
        }
        drawn ??= rest?.call(color);
        var shown = _clear;
        if (drawn != null && drawn != color) {
          shown = drawn;
          any = true;
        }
        pieces.add(
          TextSpan(
            text: text.substring(from - at, to - at),
            style: TextStyle(color: shown),
          ),
        );
        from = to;
      }
      at = end;
    }
    for (final child in s.children ?? const <InlineSpan>[]) {
      pieces.add(walk(child, color));
    }
    return TextSpan(
      style: (s.style ?? const TextStyle()).copyWith(color: _clear),
      children: pieces,
    );
  }

  final out = walk(span, const Color(0xFF000000)) as TextSpan;
  return any && !widget ? out : null;
}
