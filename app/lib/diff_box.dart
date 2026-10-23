import 'dart:math';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'review.dart';
import 'review_cards.dart';
import 'syntax.dart';
import 'theme/theme.dart';

/// A file's change side by side. With [fit] it is only as tall as the
/// change (up to fifteen lines, then it scrolls), in a thin frame; else as
/// tall as its box. With [review], a click or a drag on line numbers opens
/// a box for a comment on those lines, and the chat's comments made in
/// that view show under their lines.
class DiffBox extends StatefulWidget {
  const DiffBox(this.change, {super.key, this.fit = true, this.review});

  final FileChange change;
  final bool fit;
  final ({String chat, String where})? review;

  @override
  State<DiffBox> createState() => _DiffBoxState();
}

class _DiffBoxState extends State<DiffBox> {
  DiffViewController? _controller;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(DiffBox old) {
    super.didUpdateWidget(old);
    if (old.change != widget.change) _build();
  }

  void _build() {
    final d = widget.change;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _theme = diffTheme(NushiTheme.of(context).t);
    final diff = TextDiff.compute(d.oldText, d.newText, path: d.path);
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
    final rows = max(doc.oldLineCount, doc.newLineCount).clamp(1, 15);
    _height = _theme.lineHeightFor(dpr) * rows + 6;
  }

  @override
  void dispose() {
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
    final c = _controller!, doc = c.document, change = widget.change;
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
    int below(bool old, int line) =>
        min(line, (old ? doc.oldLineCount : doc.newLineCount)) - 1;
    final d = _draft;
    c.inlays = [
      for (final m in _comments)
        if (m != _editing)
          InlaySpec(
            id: m.id,
            side: m.old ? PaneSide.old : PaneSide.neu,
            afterLine: m.outdated ? -1 : below(m.old, m.end),
          ),
      if (d != null) InlaySpec(id: '', side: d.side, afterLine: d.span.end - 1),
    ];
  }

  /// A click or drag on line numbers ended: a comment on those lines.
  void _pointerUp(PointerUpEvent _) {
    final sel = _controller!.selection.value;
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
    final r = widget.review!, d = _draft!;
    final edited = _editing;
    final span = d.span, side = d.side;
    String text(int from, int to) => [
      for (var i = max(from, 0); i < to; i++)
        if (_controller!.lines.lineAt(side, i) case final line?) line.text,
    ].join('\n');
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
    made.text = comment;
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
      final d = _draft!, s = d.span;
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
    final c = _comments.firstWhere((c) => c.id == spec.id);
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
    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: box(
        NushiTheme.of(context).t.borderSubtle,
        radius: NushiTheme.control,
      ),
      child: diff,
    );
  }
}
