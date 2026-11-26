import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/whitespace_marks.dart' show EditorLines;
import 'package:re_editor/re_editor.dart';

// Which of a find's matches the editor is given to paint. re_editor paints
// every match it's given, each frame, each by asking its line's laid-out
// text for the match's boxes, at a cost that grows with the line: in a
// dump's lines of hundreds of kilobytes, tens of thousands of matches took
// seconds a frame. So it's given those on the lines laid out (and of a
// long one, only the part in sight), with some around them,
// and the view is built again once what shows leaves that.

/// A line longer than this is painted only in part: what's in sight, and
/// half a screen's worth around it.
const _longLine = 2000;

/// The first of [matches] (in order down the text, each on one line)
/// that ends at or past [offset] of line [line], or is on a later line.
int firstFrom(List<CodeLineSelection> matches, int line, int offset) {
  var (lo, hi) = (0, matches.length);
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    final m = matches[mid];
    if (m.startIndex < line || m.startIndex == line && m.endOffset < offset) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// re_editor's scrolling, which also knows where its text is laid out,
/// so its lines can be laid out again ([relayout]).
class EditorScroll extends CodeScrollController {
  new({super.verticalScroller, super.horizontalScroller});

  GlobalKey? _field;

  @override
  void bindEditor(GlobalKey key) {
    _field = key;
    super.bindEditor(key);
  }

  /// re_editor lays its lines in sight out again, in the next frame: each
  /// from the spans it's given then, kept paragraphs for spans it laid
  /// out before. Its own way, `forceRepaint`, lays every line out anew,
  /// outside a frame's layout.
  void relayout() =>
      _field?.currentContext?.findRenderObject()?.markNeedsLayout();

  @override
  void dispose() {
    _field = null;
    super.dispose();
  }
}

/// Where matches are painted: the lines `first` to `last`; of a long line
/// laid out, only its characters in `cut`; a long line not laid out,
/// none of it.
typedef SightWindow = ({int first, int last, Map<int, TextRange> cut});

/// What of an editor's text is in sight, for its find's marks
/// ([SightWindow]): told when it leaves the window last taken.
class EditorSight extends ChangeNotifier {
  new({required this.lines, required this.down, required this.editor}) {
    lines.addListener(_laidOut);
  }

  /// The lines as re_editor laid them out.
  final EditorLines lines;

  /// The editor's scrolling down.
  final ScrollController down;

  /// The editor's text.
  final CodeLineEditingController editor;

  SightWindow? _window;
  bool _told = false;
  bool _gone = false;

  /// The window the matches are painted in, and the editor's code drawn
  /// for them (`EditorInk`): what was in sight when it was taken and some
  /// around it (a screen's worth of lines, half of a long line's). It's
  /// kept until what's in sight leaves it, so the hits painted and the
  /// code drawn on them are always of the same window.
  SightWindow take() => _window ??= _measure(around: true);

  /// What's in sight now, no more.
  @visibleForTesting
  SightWindow get inSight => _measure(around: false);

  /// The part of line [line] whose matches are painted in [window]: all
  /// of a line short enough, a long one's cut, or none.
  TextRange? paints(SightWindow window, int line) {
    if (line < window.first || line > window.last) return null;
    if (window.cut[line] case final c?) return c;
    if (line >= editor.codeLines.length) return null;
    final length = editor.codeLines[line].length;
    return length <= _longLine ? TextRange(start: 0, end: length) : null;
  }

  SightWindow _measure({required bool around}) {
    final laid = lines.value?.paragraphs ?? const [];
    if (laid.isEmpty) return (first: 0, last: 100, cut: const {});
    final high = down.hasClients ? down.position.viewportDimension : 1000.0;
    final across = lines.across;
    final wide = across.hasClients ? across.position.viewportDimension : 2000.0;
    // Across a long line's cut, half a screen each way: a whole one
    // painted three screens of its matches, each a box asked of the whole
    // line, and scroll frames cost about a third more for it; the window
    // is taken again at each paint, so what comes into sight still shows.
    final (h, w) = around ? (high / 2, wide / 2) : (0.0, 0.0);
    final cut = <int, TextRange>{};
    for (final p in laid) {
      if (p.length <= _longLine) continue;
      // The view's corners in the line's own place.
      final x = -(p.offset.dx + lines.moved);
      final y = -p.offset.dy;
      final from = p.getPosition(Offset(x - w, y - h)).offset;
      final to = p.getPosition(Offset(x + wide + w, y + high + h)).offset;
      cut[p.index] = TextRange(start: from, end: to);
    }
    final more = around ? laid.length : 0;
    return (
      first: laid.first.index - more,
      last: laid.last.index + more,
      cut: cut,
    );
  }

  /// re_editor laid its lines out again, or they moved sideways: once
  /// what's in sight has left the window, it's let go and the view is
  /// built again, after this frame (it's laying out now), for a window
  /// taken anew.
  void _laidOut() {
    final window = _window;
    if (window == null || _told) return;
    final now = _measure(around: false);
    final held =
        now.first >= window.first &&
        now.last <= window.last &&
        now.cut.entries.every(
          (e) => switch (window.cut[e.key]) {
            final c? => e.value.start >= c.start && e.value.end <= c.end,
            null => false,
          },
        );
    if (held) return;
    _told = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _told = false;
      if (_gone || _window == null) return;
      _window = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _gone = true;
    lines.removeListener(_laidOut);
    super.dispose();
  }
}
