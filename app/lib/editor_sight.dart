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

  /// The window for the matches painted now: what's in sight and some
  /// around it (a screen's worth of lines, half of a long line's).
  SightWindow take() => _window = _measure(around: true);

  /// What's in sight now, no more.
  @visibleForTesting
  SightWindow get inSight => _measure(around: false);

  /// No matches are painted: nothing to build again for.
  void forget() => _window = null;

  /// Whether a match on [line] from [start] to [end] is painted, in
  /// [window].
  bool shows(SightWindow window, int line, int start, int end) {
    if (line < window.first || line > window.last) return false;
    if (window.cut[line] case final c?) return end >= c.start && start <= c.end;
    return line < editor.codeLines.length &&
        editor.codeLines[line].length <= _longLine;
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
  /// what's in sight has left the window, the view is built again, after
  /// this frame (it's laying out now).
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
