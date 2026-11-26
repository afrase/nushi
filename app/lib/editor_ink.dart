import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/editor_marks.dart';
import 'package:nushi/editor_sight.dart';
import 'package:nushi/source_spans.dart';
import 'package:nushi/syntax.dart' show codeOnTintContrast;
import 'package:nushi/theme/contrast.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart' show findColors;
import 'package:re_editor/re_editor.dart';

/// The colour the file editor paints its selection in, over `base`: the
/// app's, as its other text has it. re_editor is given this one and the
/// editor's code is drawn for it ([EditorInk]).
Color editorSelectionColor(BuildContext context) =>
    DefaultSelectionStyle.of(context).selectionColor ??
    NushiTheme.of(context).t.textSelection;

/// Code's colours on the fills the file editor paints under it (ADR
/// 0086's amendment, issue 117): re_editor paints its selection and a
/// find's hits under the text it lays out from the spans `EditorSpans`
/// gives each line, so those spans draw each part on a fill in [codeOn]
/// of its colour there, as the file viewer's do. A hit's fill is
/// `findColors`' hit over `base`, the selection's [editorSelectionColor]
/// over it, a hit over the selection the hit's over that; the current
/// match is the selection (`EditorFind`), so it has the selection's.
///
/// Of the find's hits it costs what's in sight, not the line: only those
/// re_editor paints, the matches in [sight]'s window (in and around what's
/// in sight, and of a long line only its cut), each line's worked out once
/// while the matches and its part of the window are the same. A selected
/// part is drawn whole, once each time it changes on the line. The rest of
/// a line keeps its runs as its syntax gave them.
///
/// re_editor lays a line out again when its spans change and keeps each
/// paragraph by its spans: a selection's change or an edit does that for
/// the lines whose spans changed, as re_editor's own layout runs then. A
/// find's answer and a window taken anew lay out nothing, so re_editor is
/// asked to lay the lines in sight out then, only when one of them is
/// drawn otherwise: of those whose marks changed, the only ones it draws
/// again to see. An edit leaves re_editor's last answer in place,
/// painted where it was, until the next: its hits are drawn where they're
/// painted meanwhile, and nothing is laid out for them till then.
class EditorInk {
  new(this.editor, this.sight, this._relayout) {
    sight.addListener(_retaken);
  }

  /// The editor's text and selection.
  final CodeLineEditingController editor;

  /// What of the text is in sight, and the window the find's hits are
  /// painted in.
  final EditorSight sight;

  /// Has re_editor lay its lines out again ([EditorScroll.relayout]).
  final VoidCallback _relayout;

  /// The find's matches, in order down the text, and how re_editor turns
  /// one into what it paints (`convertMatchToSelection`).
  List<CodeLineSelection> _matches = const [];
  CodeLineSelection? Function(CodeLineSelection)? _shown;

  /// What line [index]'s spans are drawn for besides its text, for
  /// `EditorSpans` to keep them while it's the same: the selection's
  /// colour, and the stretches of the line it inks on each fill; the key
  /// it was last drawn for while these draw it as it was.
  Object key(BuildContext context, int index) {
    final length = editor.codeLines[index].length;
    final colour = editorSelectionColor(context);
    final selected = _selectedOn(index, length);
    final hits = _hitsOn(index);
    if (_drawn[index] case final d?
        when d.colour == colour && d.selected == selected && d.hits == hits) {
      return d.key;
    }
    return (colour, selected, hits);
  }

  /// The find's matches are [matches] now (none: closed, or looking for
  /// another word): the lines in sight are drawn for them.
  void found(
    List<CodeLineSelection> matches,
    CodeLineSelection? Function(CodeLineSelection) shown,
  ) {
    if (identical(matches, _matches)) return;
    if (_matches.isEmpty && matches.isEmpty) return;
    _matches = matches;
    _shown = shown;
    if (_drawnAnew()) _again();
  }

  /// [sight] let its window go, as what's in sight left it: the lines in
  /// sight are drawn for the one taken now, which re_editor's hits will
  /// be painted in too. Only the hits are of the window.
  void _retaken() {
    if (_matches.isEmpty) return;
    if (_drawnAnew()) _again();
  }

  // Each line as last drawn, while it's kept: its runs, what they became
  // and the marks they were drawn for. A line scrolled out and back keeps
  // its spans (EditorSpans) and so its entry here.
  final _drawn = <int, _Drawn>{};
  BuildContext? _context;

  /// Whether a line in sight is drawn otherwise now; the others keep
  /// their paragraphs, laid out for the spans they still have. A line
  /// whose marks are as it was drawn for is; only one whose marks
  /// changed is drawn again, to see.
  bool _drawnAnew() {
    final context = _context;
    final laid = sight.lines.value?.paragraphs;
    if (context == null || !context.mounted || laid == null) return true;
    for (final p in laid) {
      final drawn = _drawn[p.index];
      if (drawn == null || p.index >= editor.codeLines.length) return true;
      final length = editor.codeLines[p.index].length;
      final selected = _selectedOn(p.index, length);
      final hits = _hitsOn(p.index);
      if (selected == drawn.selected && hits == drawn.hits) continue;
      _compared++;
      final now = _inked(context, drawn.runs, selected, hits);
      if (!identical(now, drawn.out) && !listEquals(now, drawn.out)) {
        return true;
      }
      // Drawn as it was: it keeps its spans, and its key with them.
      _drawn[p.index] = (
        runs: drawn.runs,
        out: drawn.out,
        key: drawn.key,
        colour: drawn.colour,
        selected: selected,
        hits: hits,
      );
    }
    return false;
  }

  bool _gone = false;

  /// What drawing the code has cost, for tests that count it: the lines
  /// built with a part on a fill, the find's hits inked in them, the
  /// times re_editor was made to lay the lines in sight out again, the
  /// lines drawn only to see whether they're drawn otherwise, and the
  /// hits worked out (asked of re_editor as it paints them).
  @visibleForTesting
  ({int lines, int hits, int forced, int compared, int worked}) get cost => (
    lines: _linesInked,
    hits: _hitsInked,
    forced: _forced,
    compared: _compared,
    worked: _worked,
  );
  int _linesInked = 0;
  int _hitsInked = 0;
  int _forced = 0;
  int _compared = 0;
  int _worked = 0;

  /// [cost] counts from nothing again.
  @visibleForTesting
  void countAfresh() =>
      _linesInked = _hitsInked = _forced = _compared = _worked = 0;

  /// re_editor lays the lines in sight out again, from the spans it's
  /// given then: only those whose spans changed are laid out anew, the
  /// rest from the paragraphs it kept. Asked for now, unless a frame is
  /// being built or laid out, else once it is.
  void _again() => _soon(afresh: false);

  /// The same, every line laid out anew: re_editor lets go of every
  /// paragraph it kept.
  void _afresh() => _soon(afresh: true);

  // What's asked for once the frame is done: nothing, a layout, or one
  // from nothing.
  bool? _after;

  void _soon({required bool afresh}) {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      _ask(afresh: afresh);
      return;
    }
    final waiting = _after != null;
    _after = afresh || (_after ?? false);
    if (waiting) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final after = _after;
      _after = null;
      if (!_gone && after != null) _ask(afresh: after);
    });
  }

  void _ask({required bool afresh}) {
    _forced++;
    afresh ? editor.forceRepaint() : _relayout();
  }

  // re_editor keeps every paragraph it laid out, by its spans, until its
  // style or width changes or it's told to build again: a drag over a
  // line's dim code leaves one for each step. Past about a megabyte of
  // such lines it's told to, which keeps only those in sight.
  final _lastSelected = <int, Stretches>{};
  int _keptChars = 0;
  static const int _keptBudget = 1 << 20;

  /// Line [index]'s [runs] as the editor draws them on its fills.
  List<TextSpan> line(BuildContext context, int index, List<TextSpan> runs) {
    _context = context;
    final length = editor.codeLines[index].length;
    final selected = _selectedOn(index, length);
    final hits = _hitsOn(index);
    final out = _inked(context, runs, selected, hits, counted: true);
    if (_drawn.length > 1024) _drawn.clear();
    final colour = editorSelectionColor(context);
    _drawn[index] = (
      runs: runs,
      out: out,
      key: (colour, selected, hits),
      colour: colour,
      selected: selected,
      hits: hits,
    );
    if (!identical(out, runs) && _lastSelected[index] != selected) {
      _keptChars += length;
      if (_keptChars > _keptBudget) {
        _keptChars = 0;
        _lastSelected.clear();
        _afresh();
      }
    }
    if (_lastSelected.length > 1024) _lastSelected.clear();
    _lastSelected[index] = selected;
    return out;
  }

  /// [runs] drawn on the fills of the [selected] parts and the [hits].
  List<TextSpan> _inked(
    BuildContext context,
    List<TextSpan> runs,
    Stretches selected,
    Stretches hits, {
    bool counted = false,
  }) {
    if (selected.all.isEmpty && hits.all.isEmpty) return runs;
    if (counted) {
      _linesInked++;
      _hitsInked += hits.all.length;
    }
    final t = NushiTheme.of(context).t;
    final hit = Color.alphaBlend(findColors(t).hit, t.base);
    final selection = Color.alphaBlend(editorSelectionColor(context), t.base);
    final hitSelected = Color.alphaBlend(findColors(t).hit, selection);
    return onFills(
      runs,
      filled(
        selected.all,
        hits.all,
        hit: hit,
        selection: selection,
        both: hitSelected,
      ),
      plain: t.text,
      ink: (c, fill) =>
          codeOn(c, fill, background: t.base, floor: codeOnTintContrast),
    );
  }

  /// The selection's part of line [index], [length] long, drawn on its
  /// fill: all of it, as it doesn't hang on what's in sight.
  Stretches _selectedOn(int index, int length) {
    final s = editor.selection;
    if (s.isCollapsed || index < s.startIndex || index > s.endIndex) {
      return Stretches.none;
    }
    final from = min(index == s.startIndex ? s.startOffset : 0, length);
    final to = min(index == s.endIndex ? s.endOffset : length, length);
    if (from >= to) return Stretches.none;
    return Stretches([(from, to)]);
  }

  // Each line's hits as last worked out, while the matches, the line's
  // part of the window and its length are the same.
  final _hits = <int, LineHits>{};

  /// The find's matches on line [index] that re_editor is given to paint
  /// (`EditorFind`'s marking), as it paints them: those in [sight]'s
  /// window but the one the selection is on. Worked out once while what
  /// they come from is the same, for the marking and the ink alike.
  List<CodeLineSelection> paintedOn(int index) =>
      _lineHits(index)?.paintedBut(editor.selection) ?? const [];

  LineHits? _lineHits(int index) {
    final shown = _shown;
    final matches = _matches;
    if (shown == null || matches.isEmpty) return null;
    if (index >= editor.codeLines.length) return null;
    final part = sight.paints(sight.take(), index);
    if (part == null) return null;
    final length = editor.codeLines[index].length;
    var hits = _hits[index];
    if (hits == null ||
        !identical(hits.matches, matches) ||
        hits.part != part ||
        hits.length != length) {
      if (_hits.length > 1024) _hits.clear();
      hits = _hits[index] = LineHits.of(
        index,
        length,
        part,
        matches,
        shown,
        was: hits,
      );
      _worked += hits.asked;
    }
    return hits;
  }

  /// The stretches of line [index] on the find's hits re_editor paints,
  /// but the one the selection is on. The same while what they come from
  /// is.
  Stretches _hitsOn(int index) {
    final hits = _lineHits(index);
    if (hits == null) return Stretches.none;
    final s = editor.selection;
    if (s.isCollapsed || s.startIndex != index) return hits.all;
    return hits.without(s);
  }

  /// No more drawing for an editor that's gone.
  void dispose() {
    _gone = true;
    sight.removeListener(_retaken);
  }
}

/// A line as last drawn: its runs, what they became, its key in
/// `EditorSpans` and the marks it's drawn for, the selection's colour and
/// stretches on each fill.
typedef _Drawn = ({
  List<TextSpan> runs,
  List<TextSpan> out,
  Object key,
  Color colour,
  Stretches selected,
  Stretches hits,
});
