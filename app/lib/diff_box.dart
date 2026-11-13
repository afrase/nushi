import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/back_swipe.dart';
import 'package:nushi/diff_box_find.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';

/// Above this many lines on a side a diff isn't computed: Myers' diff
/// keeps memory for every step, lines times edits, and a regenerated
/// lockfile would take seconds and hundreds of MB. The box says so.
const maxDiffLines = 10000;

/// Diffs at least this long (both sides, in characters) are computed off
/// the UI thread; smaller ones at once, so a short edit doesn't flicker.
const offThread = 20000;

/// Narrower than this a diff shows in one column: two panes would each be
/// too narrow to read (ADR 0107). The app's narrow width, as a pull
/// request's header and Changes' bar have it.
const double oneColumnBelow = 560;

/// Whether [d] shows in one column whatever [diffUnified] says: one of its
/// sides is empty (an added or a deleted file), so the other pane would
/// be blank (ADR 0107).
bool oneSided(FileChange d) => d.oldText.isEmpty || d.newText.isEmpty;

/// The lines a selection of unified [rows] stands for, on one side as a
/// comment is: a side with a line on every row (the new side first), else
/// the side of its last row (the new side but for a deleted line); its
/// lines of that side among the rows.
LineSelection linesOfRows(UnifiedRows u, ModelSpan rows) {
  final lines = u.linesIn(rows);
  final side = lines.neu.length == rows.length
      ? PaneSide.neu
      : lines.old.length == rows.length
      ? PaneSide.old
      : u.textSideAt(rows.end - 1);
  final span = side == PaneSide.old ? lines.old : lines.neu;
  return LineSelection(side: side, anchor: span.start, focus: span.end - 1);
}

int _lines(String s) => s.isEmpty ? 0 : '\n'.allMatches(s).length + 1;

/// Whether [d] is too long a change to diff (see [maxDiffLines]).
bool tooLongToDiff(FileChange d) =>
    _lines(d.oldText) > maxDiffLines || _lines(d.newText) > maxDiffLines;

TextDiff _diff((String, String, String) d) =>
    TextDiff.compute(d.$1, d.$2, path: d.$3);

/// Whether two changes draw the same diff: what's staged isn't part of it,
/// and staging a file mustn't lose the place in it.
bool _sameDiff(FileChange a, FileChange b) =>
    a.path == b.path && a.oldText == b.oldText && a.newText == b.newText;

/// A note of someone else's under a line of a diff (a GitHub review
/// thread): its id, its side (old: the left), its line (from 1; 0 above
/// the file).
typedef DiffNote = ({String id, bool old, int line});

/// A file's change side by side, or unified in one column ([diffUnified],
/// [oneSided], or narrower than [oneColumnBelow]; ADR 0107). With [fit] it
/// is only as tall as the change (up to fifteen rows, then it scrolls),
/// on code's surface, its corners rounded; else as tall as its box, on
/// the theme's own diff background unless [sunk]. With
/// [review], a click or a
/// drag on line numbers opens a box for a comment on those lines, and the
/// chat's comments made in that view show under their lines. Else [notes]
/// show under their lines, as [note] builds each, and a click or a drag on
/// line numbers goes to [onLines].
class DiffBox extends StatefulWidget {
  const new(
    this.change, {
    super.key,
    this.fit = true,
    this.sunk,
    this.review,
    this.notes = const [],
    this.note,
    this.onLines,
    this.line = 0,
    this.find,
  });

  final FileChange change;
  final bool fit;

  /// Whether it's drawn on code's surface (ADR 0111): as [fit] unless
  /// given. Changes' diff fills a block of that surface.
  final bool? sunk;
  final ({String chat, String where, String agent})? review;
  final List<DiffNote> notes;
  final Widget Function(String id)? note;
  final ValueChanged<LineSelection>? onLines;

  /// A line of the new side (from 1) to go to and select once the diff is
  /// in; 0 for none.
  final int line;

  /// ⌘F: its hits in this file are marked, and this box finds them.
  final TranscriptFind? find;

  @override
  State<DiffBox> createState() => _DiffBoxState();
}

/// Comments half written in a file's view that went (another file picked,
/// the file left the list), by chat, view and file, until it shows again.
final Map<String, ({LineSelection at, String text, String? editing})> _drafts =
    runMap();

class _DiffBoxState extends State<DiffBox> {
  DiffViewController? _controller; // once the diff is in
  TextDiff? _diffed;
  FileChange? _of; // the change _diffed is of, or is being computed for
  late DiffThemeData _theme;
  Tokens? _tokens; // what [_theme] was made from, and its code font
  String? _family;
  double? _dpr;
  bool _unified = false; // the view shown is the unified one
  bool _selecting = false; // the line selection changed during this click
  bool _went = false; // went to [DiffBox.line] already
  LineSelection? _draft; // the lines a comment is being written for
  ReviewComment? _editing; // the comment being changed, if one is
  final _comment = TextEditingController(); // its text; outlives a reload
  SyntaxLines? _source; // the lines of _controller
  final _found = DiffBoxFind(); // what ⌘F found in them

  @override
  void initState() {
    super.initState();
    reviews.addListener(_commentsChanged);
    widget.find?.addListener(_showFind);
    _takeDraft();
  }

  /// Finds and marks what the find asks for, and goes to its current hit.
  void _showFind() {
    final (lines, c, f) = (_source, _controller, widget.find);
    if (lines == null || c == null || f == null) return;
    _found.show(f, lines, c, () => mounted);
  }

  void _takeDraft() {
    if (_drafts.remove(_draftKey(widget.review)) case final d?) {
      _draft = d.at;
      _comment.text = d.text;
      _editing = _comments.where((c) => c.id == d.editing).firstOrNull;
    }
  }

  String? _draftKey(({String chat, String where, String agent})? r) =>
      r == null ? null : '${r.chat}\n${r.where}\n${widget.change.path}';

  /// Keeps the comment being written for when the view shows again.
  void _keepDraft(({String chat, String where, String agent})? r) {
    if (_draft case final at? when _comment.text.trim().isNotEmpty) {
      if (_draftKey(r) case final key?) {
        _drafts[key] = (at: at, text: _comment.text, editing: _editing?.id);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final NushiTheme(:t, codePicked: family) = NushiTheme.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (identical(t, _tokens) && family == _family && dpr == _dpr) return;
    final first = _tokens == null;
    _tokens = t;
    _family = family;
    _dpr = dpr;
    // In the transcript, on a card and in Changes it sits on code's
    // surface (ADR 0111).
    _theme = diffTheme(
      t,
      surface: widget.sunk ?? widget.fit ? t.codeBlock : null,
      family: family,
    );
    final c = _controller;
    if (first || c == null) {
      _build();
      return;
    }
    // A new theme or screen: the same view repainted, where it was
    // scrolled, not made again.
    c.configure(theme: _theme, devicePixelRatio: dpr);
  }

  @override
  void didUpdateWidget(DiffBox old) {
    super.didUpdateWidget(old);
    // Another view of the same path (another commit picked, a related
    // worktree's file): its own comments, whether or not its text is the
    // same; the box half written for the last one waits for it.
    final otherView = old.review != widget.review;
    if (otherView) {
      _keepDraft(old.review);
      _draft = _editing = null;
      _comment.clear();
      _takeDraft();
    }
    if (!_sameDiff(old.change, widget.change)) {
      _build();
    } else if (otherView || old.notes != widget.notes) {
      _showComments();
    }
  }

  /// The box's height when it fits the change: at most 15 rows, of the
  /// view shown ([unified]: one per line shown, a changed line's two).
  double _height({required bool unified}) {
    final d = widget.change;
    final c = _controller;
    final rows = unified && c != null
        ? c.unifiedRows.rowCount
        : max(_lines(d.oldText), _lines(d.newText));
    return _theme.lineHeightFor(MediaQuery.devicePixelRatioOf(context)) *
            rows.clamp(1, 15) +
        6;
  }

  /// Diffs the change (once per change), then makes the view.
  void _build() {
    final d = widget.change;
    if (_of case final of? when _sameDiff(of, d)) {
      if (_diffed case final diff?) _view(diff);
      return;
    }
    _of = d;
    if (tooLongToDiff(d)) {
      _controller?.dispose();
      _controller = null;
      return;
    }
    final args = (d.oldText, d.newText, d.path);
    if (d.oldText.length + d.newText.length < offThread) {
      _view(_diffed = _diff(args));
      return;
    }
    compute(_diff, args).then((diff) {
      if (!mounted || _of != d) return;
      setState(() => _view(_diffed = diff));
    }).ignore();
  }

  void _view(TextDiff diff) {
    final d = widget.change;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final doc = diff.document;
    final lines = _source = SyntaxLines(
      diff.lines,
      doc.oldLineCount,
      doc.newLineCount,
    );
    _controller?.dispose();
    _controller = DiffViewController(
      document: doc,
      lines: lines,
      theme: _theme,
      captureNames: syntaxCaptures,
      devicePixelRatio: dpr,
    )..selectionChanges.addListener(() => _selecting = true);
    // Its panes scroll sideways without a Scrollable: a swipe back over
    // it is the diff's while it moves.
    _controller!.horizontal.addListener(() {
      if (mounted) const SideScrolled().dispatch(context);
    });
    // A comment being written stays, on the same lines while there are
    // that many.
    if (_draft case final d?) {
      final count = d.side == PaneSide.old
          ? doc.oldLineCount
          : doc.newLineCount;
      _draft = count == 0
          ? null
          : LineSelection(
              side: d.side,
              anchor: min(d.anchor, count - 1),
              focus: min(d.focus, count - 1),
            );
      if (_draft == null) _editing = null;
    }
    _showComments();
    if (widget.line > 0 && !_went && doc.newLineCount > 0) {
      _went = true;
      final at = min(widget.line, doc.newLineCount) - 1;
      // Selected in both views: either may be the one laid out, or come
      // with a switch.
      _controller!
        ..jumpToLine(PaneSide.neu, at)
        ..selection.start(PaneSide.neu, at)
        ..unifiedSelection.start(
          _controller!.unifiedRows.rowOf(PaneSide.neu, at),
        );
      _selecting = false; // selected here, not by a click
    }
    _showFind();
    // Plain until the colors are in (a moment, off the UI thread).
    final controller = _controller;
    if (languageOf(d.path) case final language?) {
      highlightSides(language, d.oldText, d.newText).then((spans) {
        if (mounted && _controller == controller) lines.highlight(spans);
      }).ignore();
    }
  }

  @override
  void dispose() {
    _keepDraft(widget.review);
    reviews.removeListener(_commentsChanged);
    widget.find?.removeListener(_showFind);
    _controller?.dispose();
    _comment.dispose();
    super.dispose();
  }

  List<ReviewComment> get _comments => switch (widget.review) {
    final r? => [
      for (final c in commentsOf(r.chat))
        if (c.where == r.where && c.path == widget.change.path) c,
    ],
    null => const [],
  };

  /// Comments were made, changed or removed: they show as they are.
  void _commentsChanged() => _showComments();

  /// Puts the comments, and the box being written in, under their lines,
  /// or above the file when they're gone. Changes has already moved each
  /// with its lines for the files it shows ([filesRead]).
  void _showComments() {
    final c = _controller;
    if (c == null) return;
    final doc = c.document;
    int below(int line, {required bool old}) =>
        min(line, (old ? doc.oldLineCount : doc.newLineCount)) - 1;
    final d = _draft;
    c.inlays = [
      for (final m in _comments)
        if (m != _editing)
          InlaySpec(
            id: m.id,
            side: m.old ? PaneSide.old : PaneSide.neu,
            afterLine: m.outdated ? -1 : below(m.end, old: m.old),
          ),
      if (d != null)
        InlaySpec(
          id: '',
          side: d.side,
          // An outdated one is changed where it shows: above the file.
          afterLine: _editing?.outdated ?? false ? -1 : d.span.end - 1,
        ),
      for (final n in widget.notes)
        InlaySpec(
          id: 'note:${n.id}',
          side: n.old ? PaneSide.old : PaneSide.neu,
          afterLine: n.line <= 0 ? -1 : below(n.line, old: n.old),
        ),
    ];
  }

  /// The lines selected in the view shown, on one side.
  LineSelection? get _selected {
    final c = _controller;
    if (c == null || !_unified) return c?.selection.value;
    final rows = c.unifiedSelection.value?.span;
    return rows == null ? null : linesOfRows(c.unifiedRows, rows);
  }

  /// Clears both views' selections.
  void _unselect() {
    _controller!
      ..selection.clear()
      ..unifiedSelection.clear();
    _selecting = false;
  }

  /// A click or drag on line numbers ended: a comment on those lines.
  void _pointerUp(PointerUpEvent _) {
    final sel = _selected;
    if (_selecting && sel != null && widget.onLines != null) {
      _unselect();
      widget.onLines!(sel);
      return;
    }
    if (!_selecting || sel == null || widget.review == null) return;
    _draft = sel;
    _editing = null;
    _comment.clear();
    // The box takes the keys (Shift-arrows, ⌘C), not the diff's selection.
    _unselect();
    _showComments();
  }

  void _closeDraft() {
    _draft = _editing = null;
    _comment.clear();
    _unselect();
    _showComments();
  }

  void _save(String comment) {
    final r = widget.review!;
    final d = _draft!;
    final edited = _editing;
    final span = d.span;
    final side = d.side;
    String text(int from, int to) => [
      for (var i = max(from, 0); i < to; i++)
        if (_controller!.lines.lineAt(side, i) case final line?) line.text,
    ].join('\n');
    edited?.text = comment;
    final made =
        edited ??
              ReviewComment(
                id: '${DateTime.now().microsecondsSinceEpoch}',
                where: r.where,
                path: widget.change.path,
                old: side == PaneSide.old,
                start: span.start + 1,
                end: span.end,
                quote: text(span.start, span.end),
                before: text(span.start - 2, span.start),
                after: text(span.end, span.end + 2),
                text: comment,
              )
          ..see(
            side == PaneSide.old
                ? widget.change.oldText
                : widget.change.newText,
          );
    _closeDraft();
    setComments(r.chat, [
      for (final c in commentsOf(r.chat))
        if (c != edited) c,
      made,
    ]);
  }

  static Widget _noInlay(BuildContext context, InlaySpec spec) =>
      const SizedBox.shrink();

  Widget _inlay(BuildContext context, InlaySpec spec) {
    if (spec.id.startsWith('note:')) {
      return widget.note?.call(spec.id.substring(5)) ?? const SizedBox.shrink();
    }
    final r = widget.review!;
    if (spec.id.isEmpty) {
      final d = _draft!;
      final s = d.span;
      return ReviewCommentBox(
        key: ValueKey(_editing?.id ?? 'new'),
        lines: s.length == 1
            ? 'Line ${s.start + 1}'
            : 'Lines ${s.start + 1}–${s.end}',
        controller: _comment,
        // It goes to the agent (Send to agent), never to GitHub.
        hint: 'Comment for ${r.agent}',
        editing: _editing != null,
        onSave: _save,
        onCancel: _closeDraft,
      );
    }
    final c = _comments.where((c) => c.id == spec.id).firstOrNull;
    if (c == null) return const SizedBox.shrink(); // gone meanwhile
    return CommentCard(
      c,
      onEdit: () {
        final side = c.old ? PaneSide.old : PaneSide.neu;
        _draft = LineSelection(
          side: side,
          anchor: c.start - 1,
          focus: c.end - 1,
        );
        _editing = c;
        _comment.text = c.text;
        _showComments();
      },
      onRemove: () => setComments(r.chat, [
        for (final m in commentsOf(r.chat))
          if (m != c) m,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: diffUnified,
    builder: (context, unified, _) => LayoutBuilder(
      builder: (context, box) => _box(
        unified ||
            oneSided(widget.change) ||
            kIsWeb ||
            box.maxWidth < oneColumnBelow,
      ),
    ),
  );

  Widget _box(bool unified) {
    final theme = NushiTheme.of(context);
    final d = widget.change;
    if (_controller == null) {
      final long = tooLongToDiff(d);
      final placeholder = Center(
        child: Text(
          long
              ? 'Too long to diff here: '
                    '${_lines(d.oldText)} → ${_lines(d.newText)} lines'
              : '',
          style: theme.ui(theme.t.textMuted, size: 12),
        ),
      );
      return widget.fit
          ? SizedBox(
              height: long ? 40 : _height(unified: unified),
              child: placeholder,
            )
          : placeholder;
    }
    final c = _controller!;
    // A switch of views keeps the find's current hit where it was.
    if (widget.find case final f? when unified != _unified) {
      _found.keepHit(
        f,
        c,
        unified: _unified,
        current: () => mounted && _controller == c,
      );
    }
    _unified = unified; // what a click on line numbers selects in
    final scroll = unified ? c.unifiedScroll : c.scroll(PaneSide.neu);
    final inlays = widget.review == null && widget.note == null
        ? _noInlay
        : _inlay;
    final diff = Listener(
      onPointerUp: _pointerUp,
      // diff_view's views have no scrollbar; one at the right edge, for
      // the unified view or the right pane (the left follows it).
      child: MacScrollbar(
        controller: scroll,
        notificationPredicate: (n) =>
            n.context != null &&
            Scrollable.maybeOf(n.context!)?.widget.controller == scroll,
        child: unified
            ? UnifiedDiff(controller: c, theme: _theme, inlayBuilder: inlays)
            : SideBySideDiff(
                controller: c,
                theme: _theme,
                inlayBuilder: inlays,
              ),
      ),
    );
    if (!widget.fit) return diff;
    return SizedBox(
      height: _height(unified: unified),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NushiTheme.control),
        child: diff,
      ),
    );
  }
}
