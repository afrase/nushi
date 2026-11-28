import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';

// ⌘F in the Files pane's preview (issue 63): rendered Markdown, a read-only
// source, a CSV's table and a page each find in what they show, in the
// transcript's bar (FindBar) at the view's top right, as the editor's
// (EditorFind) does. The pane's view (FileView) holds a [FindSlot], which
// the view showing puts its find in; the phone's preview has none, so it
// has no find.

/// A preview's find: [Find], and Esc (or ×) gives the focus back to where
/// it was when the bar opened, the preview, rather than to nothing.
class PreviewFind extends Find {
  FocusNode? _back;

  @override
  void open() {
    final now = FocusManager.instance.primaryFocus;
    if (query == null && now != focus) _back = now;
    super.open();
  }

  @override
  void close() {
    final had = focus.hasFocus;
    super.close();
    final back = _back;
    _back = null;
    if (!had) return;
    if (back != null && back.context != null && back.canRequestFocus) {
      back.requestFocus();
    } else {
      focus.unfocus();
    }
  }
}

/// Where the preview's view puts its find while it shows: the Files pane's
/// viewer holds one ([FindSlotScope]) and asks it for [current] as ⌘F
/// comes; none on the phone.
class FindSlot {
  /// The find of the view drawn by Flutter (Markdown, a source, a table).
  Find? view;

  /// The find ⌘F opens: [view]'s, unless the viewer says otherwise (a
  /// page's own, in its web view).
  Find? Function()? choose;

  /// The find ⌘F opens now, if any.
  Find? get current => choose?.call() ?? view;
}

/// Gives a preview's views their [FindSlot].
class FindSlotScope extends InheritedWidget {
  const new({required this.slot, required super.child, super.key});

  final FindSlot slot;

  /// The slot above [context], if any; not depended on (it never changes).
  static FindSlot? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FindSlotScope>()?.slot;

  @override
  bool updateShouldNotify(FindSlotScope old) => slot != old.slot;
}

/// The preview's find for the focus in it: ⌘F from the menu bar or the
/// palette, as its key does, goes to the preview with the focus.
Find? focusedPreviewFind() {
  final at = FocusManager.instance.primaryFocus?.context;
  if (at == null || !at.mounted) return null;
  return FindSlotScope.maybeOf(at)?.current;
}

/// A view's [find] in [FindSlot.view] while the view lives: made when a
/// slot is above it (the Mac's and Linux's pane), none without one.
mixin FindInSlot<T extends StatefulWidget> on State<T> {
  PreviewFind? _find;
  FindSlot? _slot;

  /// The view's find, or null where it has none (the phone).
  PreviewFind? get find => _find;

  /// What the find changing does: it looks again, or steps.
  void findChanged();

  /// The view's find, made once a slot is above it.
  @protected
  PreviewFind makeFind() => PreviewFind();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slot = FindSlotScope.maybeOf(context);
    if (slot == _slot) return;
    _leave();
    _slot = slot;
    if (slot != null) {
      final f = _find ??= makeFind()..addListener(findChanged);
      slot.view = f;
    }
  }

  void _leave() {
    if (_slot case final s? when identical(s.view, _find)) s.view = null;
  }

  @override
  void dispose() {
    _leave();
    _find
      ?..removeListener(findChanged)
      ..dispose();
    super.dispose();
  }
}

/// The find bar over a preview's [child], at its top right as the editor's
/// is, while [find] is open; no bar without a find.
class FindFrame extends StatelessWidget {
  const new({
    required this.find,
    required this.child,
    super.key,
    this.hint = 'Find in the file',
  });

  final Find? find;
  final Widget child;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final f = find;
    if (f == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // No wider than the pane leaves it: a pane at its least is
        // narrower than the bar.
        Positioned(
          top: 8,
          left: NushiTheme.gutter,
          right: NushiTheme.gutter,
          child: Align(
            alignment: Alignment.topRight,
            child: ListenableBuilder(
              listenable: f,
              builder: (context, _) => f.query == null
                  ? const SizedBox.shrink()
                  : FindBar(f, hint: hint),
            ),
          ),
        ),
      ],
    );
  }
}

/// What the bar covers of a view's top: its height and the room above it.
const double findBarCover = FindBar.height + 8;

/// How [revealFound] left a match.
enum Revealed {
  /// It shows, or the view went to it.
  shown,

  /// It's at the very top, under the bar, and no scroll takes it out:
  /// the view needs room above its text while the bar is open.
  needsRoom,
}

/// Takes [scroll]'s view to [rect] of [box] (a match), a third of the way
/// down, unless it shows already clear of the find bar at [view]'s top
/// right; a code block's own sideways scroll too. A jump, as the
/// transcript's: what's between isn't worth showing.
Revealed revealFound({
  required ScrollController scroll,
  required RenderBox box,
  required Rect rect,
  required RenderBox view,
  bool roomAbove = false,
}) {
  if (!scroll.hasClients || !box.attached || !view.attached) {
    return Revealed.shown;
  }
  final p = scroll.position;
  final list = RenderAbstractViewport.of(box);
  final top = list.getOffsetToReveal(box, 0, rect: rect).offset;
  final at = MatrixUtils.transformRect(box.getTransformTo(view), rect);
  final covered = at.right > view.size.width - FindBar.width - NushiTheme.gutter
      ? findBarCover
      : 0.0;
  if (top - p.minScrollExtent < covered && !roomAbove) {
    return Revealed.needsRoom;
  }
  final shows =
      top >= p.pixels + covered &&
      top + rect.height <= p.pixels + p.viewportDimension;
  if (!shows) {
    p.jumpTo(
      list
          .getOffsetToReveal(box, 0.3, rect: rect)
          .offset
          .clamp(p.minScrollExtent, p.maxScrollExtent),
    );
  }
  // Sideways (a code block's, a wide table's, a long line's) too.
  box.showOnScreen(rect: rect);
  return Revealed.shown;
}

/// A match in a line of text a view holds whole (a source's line, a
/// table's cell): its characters, and whether it's the current one.
typedef LineHit = ({int start, int end, bool now});

/// The matches of [query] (lowered) in [text], case aside, each its
/// start and end. A few characters change length when lowered: there the
/// lowered text's offsets would be another text's, so they're found anew.
Iterable<(int, int)> hitsIn(String text, String query) {
  if (query.isEmpty || text.isEmpty) return const [];
  final lower = text.toLowerCase();
  final found = lower.length == text.length
      ? query.allMatches(lower)
      : RegExp(RegExp.escape(query), caseSensitive: false).allMatches(text);
  return found.map((m) => (m.start, m.end));
}

/// The boxes [p] draws [start] to [end] in, a line high; none when they
/// aren't drawn (past an ellipsis).
List<Rect> hitBoxes(RenderParagraph p, int start, int end) => [
  for (final b in p.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
    boxHeightStyle: BoxHeightStyle.max,
  ))
    b.toRect(),
];

/// Paints [hits] under the text of the paragraph in [child], as the
/// transcript's find does ([findColors]); a match that isn't drawn (cut
/// off past an ellipsis) tints the whole box instead, as a folded row's
/// does in the transcript.
class LineHits extends SingleChildRenderObjectWidget {
  const new({
    required this.hits,
    required this.colors,
    required Widget super.child,
    super.key,
    this.inSightAcross = false,
  });

  final List<LineHit> hits;
  final FindColors colors;

  /// Whether it paints only the matches in sight across: for a line
  /// that is painted again as it scrolls sideways (a read-only source's
  /// unwrapped line, its numbers moving with the scroll).
  final bool inSightAcross;

  /// The matches painted since a test last set it to 0.
  @visibleForTesting
  static int painted = 0;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLineHits(hits, colors, inSightAcross: inSightAcross);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderLineHits)
        ..hits = hits
        ..colors = colors
        ..inSightAcross = inSightAcross;
}

class _RenderLineHits extends RenderProxyBox {
  new(this._hits, this._colors, {required this.inSightAcross});

  /// As [LineHits.inSightAcross].
  bool inSightAcross;

  List<LineHit> _hits;
  List<LineHit> get hits => _hits;
  set hits(List<LineHit> v) {
    if (_hits.isEmpty && v.isEmpty) return;
    _hits = v;
    markNeedsPaint();
  }

  FindColors _colors;
  FindColors get colors => _colors;
  set colors(FindColors v) {
    if (v == _colors) return;
    _colors = v;
    markNeedsPaint();
  }

  RenderParagraph? _paragraph() {
    RenderParagraph? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderParagraph) {
        found = o;
      } else {
        o.visitChildren(visit);
      }
    }

    if (child case final c?) visit(c);
    return found;
  }

  /// The part of [p]'s text the clips above leave in sight across, a
  /// character more each side: an unwrapped long line's matches past the
  /// view's edges cost a box each to paint for nothing. All of it unless
  /// [inSightAcross], for a few matches, or a paragraph of more than one
  /// row: a list doesn't paint a line again as it scrolls up or down, so
  /// a tall wrapped line's rows coming into sight would come unmarked.
  (int, int) _shownText(RenderParagraph p) {
    const all = (0, 1 << 30);
    if (!inSightAcross || _hits.length < 8) return all;
    // The clips of the boxes above, each in their own place, then here.
    final toHere = Matrix4.identity();
    Rect? shown;
    RenderObject child = this;
    for (var up = parent; up != null; child = up, up = up.parent) {
      up.applyPaintTransform(child, toHere);
      final clip = up.describeApproximatePaintClip(child);
      if (clip == null) continue;
      final back = Matrix4.tryInvert(toHere);
      if (back == null) return all;
      final here = MatrixUtils.transformRect(back, clip);
      shown = shown?.intersect(here) ?? here;
    }
    if (shown == null) return all;
    final at = MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
    final left = shown.left - at.dx;
    final right = shown.right - at.dx;
    if (left <= 0 && right >= p.size.width) return all;
    final row = p.getFullHeightForCaret(const TextPosition(offset: 0));
    if (p.size.height >= row * 2) return all;
    final y = p.size.height / 2;
    final first = p.getPositionForOffset(Offset(left, y)).offset;
    final last = p.getPositionForOffset(Offset(right, y)).offset;
    return (first - 1, last + 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final p = _hits.isEmpty ? null : _paragraph();
    if (p != null && p.hasSize) {
      final canvas = context.canvas;
      final at =
          offset +
          MatrixUtils.transformPoint(p.getTransformTo(this), Offset.zero);
      final edge = Paint()
        ..color = _colors.edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final (from, to) = _shownText(p);
      for (final h in _hits) {
        if (h.end < from || h.start > to) continue;
        LineHits.painted++;
        final fill = Paint()..color = h.now ? _colors.now : _colors.hit;
        final boxes = hitBoxes(p, h.start, h.end);
        if (boxes.isEmpty) {
          final row = offset & size;
          canvas.drawRect(row, fill);
          if (h.now) canvas.drawRect(row.deflate(0.5), edge);
          continue;
        }
        for (final box in boxes) {
          // A found word's box, its corners small whatever the app's, as
          // the transcript's marks are (TextMarks).
          final r = RRect.fromRectAndRadius(
            box.shift(at).inflate(1),
            // The transcript's find box (TextMarks), as the markdown
            // package draws it, without the app's theme.
            // not a corner: a found word's box, the transcript's size
            const Radius.circular(3),
          );
          canvas.drawRRect(r, fill);
          if (h.now) canvas.drawRRect(r, edge);
        }
      }
    }
    super.paint(context, offset);
  }
}

/// The paragraph whose matches the [nth] [LineHits] under [root] (from 0,
/// in paint order) paints, if one is laid out there.
RenderParagraph? hitParagraphIn(RenderObject root, [int nth = 0]) {
  RenderParagraph? found;
  var seen = 0;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is _RenderLineHits) {
      if (seen++ == nth) found = o._paragraph();
    } else {
      o.visitChildren(visit);
    }
  }

  visit(root);
  return found;
}
