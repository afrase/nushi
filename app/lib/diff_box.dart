import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/syntax.dart';
import 'package:nushi/theme/theme.dart';

/// Above this many lines on a side a diff isn't computed: Myers' diff
/// keeps memory for every step, lines times edits, and a regenerated
/// lockfile would take seconds and hundreds of MB. The box says so.
const maxDiffLines = 10000;

/// Diffs at least this long (both sides, in characters) are computed off
/// the UI thread; smaller ones at once, so a short edit doesn't flicker.
const offThread = 20000;

int _lines(String s) => s.isEmpty ? 0 : '\n'.allMatches(s).length + 1;

/// Whether [d] is too long a change to diff (see [maxDiffLines]).
bool tooLongToDiff(FileChange d) =>
    _lines(d.oldText) > maxDiffLines || _lines(d.newText) > maxDiffLines;

TextDiff _diff((String, String, String) d) =>
    TextDiff.compute(d.$1, d.$2, path: d.$3);

/// A file's change side by side. With [fit] it is only as tall as the
/// change (up to fifteen lines, then it scrolls), in a thin frame; else as
/// tall as its box. With [review], a click or a drag on line numbers opens
/// a box for a comment on those lines, and the chat's comments made in
/// that view show under their lines.
class DiffBox extends StatefulWidget {
  const new(this.change, {super.key, this.fit = true, this.review});

  final FileChange change;
  final bool fit;
  final ({String chat, String where})? review;

  @override
  State<DiffBox> createState() => _DiffBoxState();
}

/// Comments half written in a file's view that went (another file picked,
/// the file left the list), by chat, view and file, until it shows again.
final _drafts = <String, ({LineSelection at, String text, String? editing})>{};

class _DiffBoxState extends State<DiffBox> {
  DiffViewController? _controller; // once the diff is in
  TextDiff? _diffed;
  FileChange? _of; // the change _diffed is of, or is being computed for
  late DiffThemeData _theme;
  double _height = 0;
  bool _selecting = false; // the line selection changed during this click
  LineSelection? _draft; // the lines a comment is being written for
  ReviewComment? _editing; // the comment being changed, if one is
  final _comment = TextEditingController(); // its text; outlives a reload

  @override
  void initState() {
    super.initState();
    reviews.addListener(_showComments);
    _takeDraft();
  }

  void _takeDraft() {
    if (_drafts.remove(_draftKey(widget.review)) case final d?) {
      _draft = d.at;
      _comment.text = d.text;
      _editing = _comments.where((c) => c.id == d.editing).firstOrNull;
    }
  }

  String? _draftKey(({String chat, String where})? r) =>
      r == null ? null : '${r.chat}\n${r.where}\n${widget.change.path}';

  /// Keeps the comment being written for when the view shows again.
  void _keepDraft(({String chat, String where})? r) {
    if (_draft case final at? when _comment.text.trim().isNotEmpty) {
      if (_draftKey(r) case final key?) {
        _drafts[key] = (at: at, text: _comment.text, editing: _editing?.id);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = diffTheme(NushiTheme.of(context).t);
    _build();
  }

  @override
  void didUpdateWidget(DiffBox old) {
    super.didUpdateWidget(old);
    if (old.change != widget.change) {
      _build();
    } else if (old.review != widget.review) {
      // Another view of the same file (another commit picked): its own
      // comments; the box half written for the last one waits for it.
      _keepDraft(old.review);
      _draft = _editing = null;
      _comment.clear();
      _takeDraft();
      _showComments();
    }
  }

  /// Diffs the change (once per change), then makes the view.
  void _build() {
    final d = widget.change;
    final rows = max(_lines(d.oldText), _lines(d.newText)).clamp(1, 15);
    _height =
        _theme.lineHeightFor(MediaQuery.devicePixelRatioOf(context)) * rows + 6;
    if (_of == d) {
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
    final lines = SyntaxLines(diff.lines, doc.oldLineCount, doc.newLineCount);
    _controller?.dispose();
    _controller = DiffViewController(
      document: doc,
      lines: lines,
      theme: _theme,
      captureNames: syntaxCaptures,
      devicePixelRatio: dpr,
    )..selectionChanges.addListener(() => _selecting = true);
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
    reviews.removeListener(_showComments);
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

  /// Puts the comments, and the box being written in, under their lines:
  /// where those lines are now, or above the file when they're gone.
  void _showComments() {
    final c = _controller;
    if (c == null) return;
    final doc = c.document;
    final change = widget.change;
    var moved = false;
    for (final m in _comments) {
      if (m.anchor(m.old ? change.oldText : change.newText)) moved = true;
    }
    if (moved) {
      // After this build: saving tells every view, this one included.
      final chat = widget.review!.chat;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => setComments(chat, [...commentsOf(chat)]),
      );
    }
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
      if (d != null) InlaySpec(id: '', side: d.side, afterLine: d.span.end - 1),
    ];
  }

  /// A click or drag on line numbers ended: a comment on those lines.
  void _pointerUp(PointerUpEvent _) {
    final sel = _controller?.selection.value;
    if (!_selecting || sel == null || widget.review == null) return;
    _selecting = false;
    _draft = sel;
    _editing = null;
    _comment.clear();
    // The box takes the keys (Shift-arrows, ⌘C), not the diff's selection.
    _controller!.selection.clear();
    _selecting = false;
    _showComments();
  }

  void _closeDraft() {
    _draft = _editing = null;
    _comment.clear();
    _controller!.selection.clear();
    _selecting = false;
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
        );
    _closeDraft();
    setComments(r.chat, [
      for (final c in commentsOf(r.chat))
        if (c != edited) c,
      made,
    ]);
  }

  Widget _inlay(BuildContext context, InlaySpec spec) {
    final r = widget.review!;
    if (spec.id.isEmpty) {
      final d = _draft!;
      final s = d.span;
      return CommentBox(
        key: ValueKey(_editing?.id ?? 'new'),
        lines: s.length == 1
            ? 'Line ${s.start + 1}'
            : 'Lines ${s.start + 1}–${s.end}',
        controller: _comment,
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
  Widget build(BuildContext context) {
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
          ? SizedBox(height: long ? 40 : _height, child: placeholder)
          : placeholder;
    }
    final diff = Listener(
      onPointerUp: _pointerUp,
      child: SideBySideDiff(
        controller: _controller!,
        theme: _theme,
        inlayBuilder: widget.review == null
            ? (context, spec) => const SizedBox.shrink()
            : _inlay,
      ),
    );
    if (!widget.fit) return diff;
    return framed(
      height: _height,
      border: NushiTheme.of(context).t.borderSubtle,
      radius: NushiTheme.control,
      child: diff,
    );
  }
}
