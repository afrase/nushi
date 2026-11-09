import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/rail.dart';

// A Markdown preview's outline (ADR 0106), as Claude's desktop app has it:
// a rail of dashes left of the text, one for each heading, the current
// section's long and in the accent; its menu lists the headings by name and
// a pick scrolls there. Each heading carries a mark where it starts
// (`StreamingMarkdown.headingMark`), which tells the outline its level, its
// name and where it stands.

/// The widest the rendered text gets.
const markdownWidth = 760.0;

/// Below this wide the preview's text keeps a narrower margin for the rail.
const outlineNarrowBelow = 480.0;

/// The most levels an outline indents (0, 1, 2), so the rail stays narrow.
const _deepest = 2;

/// Rendered Markdown that scrolls, with its outline's rail when it has two
/// headings or more: [text] as [AgentMarkdown] draws it, [images] its
/// images, in [padding] (its left grown for the rail).
class OutlinedMarkdown extends StatefulWidget {
  const new(
    this.text, {
    required this.images,
    required this.padding,
    super.key,
  });

  final String text;
  final Widget Function(Uri uri, String? alt) images;
  final EdgeInsets padding;

  @override
  State<OutlinedMarkdown> createState() => _OutlinedMarkdownState();
}

/// A heading's mark, in its text where it starts; it says where it is to
/// the outline around it.
class _Mark extends StatefulWidget {
  const new(this.level, this.title);

  final int level;
  final String title;

  @override
  State<_Mark> createState() => _MarkState();
}

class _MarkState extends State<_Mark> {
  _OutlinedMarkdownState? _outline;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outline = context
        .dependOnInheritedWidgetOfExactType<_Scope>()
        ?.outline;
    if (outline == _outline) return;
    _outline?._remove(this);
    _outline = outline?.._add(this);
  }

  @override
  void didUpdateWidget(_Mark old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level || old.title != widget.title) {
      _outline?._changed();
    }
  }

  @override
  void dispose() {
    _outline?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Scope extends InheritedWidget {
  const new({required this.outline, required super.child});

  final _OutlinedMarkdownState outline;

  @override
  bool updateShouldNotify(_Scope old) => old.outline != outline;
}

class _OutlinedMarkdownState extends State<OutlinedMarkdown> {
  final _scroll = ScrollController();
  final _marks = <_MarkState>{};
  final ValueNotifier<int> _current = ValueNotifier(0);
  final GlobalKey _viewport = GlobalKey();

  /// The marks in the text's order, and the rail's entries for them.
  List<_MarkState> _order = const [];
  List<RailEntry> _entries = const [];
  bool _due = false;

  /// The heading picked from the rail's menu, current while the view goes
  /// there (`at` null) and stays where the pick took it, though another
  /// heading is at the top (the last ones, at the text's end).
  ({int index, double? at})? _picked;

  @override
  void dispose() {
    _scroll.dispose();
    _current.dispose();
    super.dispose();
  }

  void _add(_MarkState mark) {
    _marks.add(mark);
    _changed();
  }

  void _remove(_MarkState mark) {
    if (_marks.remove(mark)) _changed();
  }

  /// The marks changed: once laid out, the entries are made again.
  void _changed() {
    if (_due) return;
    _due = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _due = false;
      if (mounted) _refresh();
    });
  }

  /// Where [mark] stands in the text, from its top; null when it isn't laid
  /// out.
  double? _top(_MarkState mark) {
    final view = _viewport.currentContext?.findRenderObject();
    final box = mark.context.findRenderObject();
    if (view is! RenderBox || box is! RenderBox || !box.attached) return null;
    if (!_scroll.hasClients) return null;
    return box.localToGlobal(Offset.zero, ancestor: view).dy + _scroll.offset;
  }

  void _refresh() {
    final placed = [
      for (final m in _marks)
        if (_top(m) case final top?) (m, top),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final order = [for (final (m, _) in placed) m];
    final entries = _outline(order);
    final same =
        entries.length == _entries.length &&
        [for (var i = 0; i < entries.length; i++) i]
            .every((i) => entries[i] == _entries[i]);
    _order = order;
    if (!same) setState(() => _entries = entries);
    _follow();
  }

  /// The rail's entries for [order]'s headings: their depth from the
  /// top-most level, or from the next one when a single top heading leads
  /// (a title, as Claude's outline has it), at most [_deepest].
  static List<RailEntry> _outline(List<_MarkState> order) {
    if (order.isEmpty) return const [];
    final levels = [for (final m in order) m.widget.level];
    final top = levels.reduce(min);
    var base = top;
    final tops = levels.where((l) => l == top).length;
    if (tops == 1 && levels.first == top && levels.length > 1) {
      base = levels.skip(1).reduce(min);
    }
    return [
      for (final (i, m) in order.indexed)
        RailEntry(
          '$i',
          m.widget.title,
          depth: (m.widget.level - base).clamp(0, _deepest),
        ),
    ];
  }

  /// Makes the current entry the last heading at or above the view's top
  /// (the first while none is), or the one just picked while the view
  /// goes there or stays there.
  void _follow() {
    if (!_scroll.hasClients || _order.isEmpty) return;
    final offset = _scroll.offset;
    if (_picked case (:final index, :final at)) {
      if (at == null || (offset - at).abs() < 1) {
        _current.value = index;
        return;
      }
      _picked = null;
    }
    final line = offset + widget.padding.top + 1;
    var current = 0;
    for (final (i, m) in _order.indexed) {
      final top = _top(m);
      if (top == null || top > line) break;
      current = i;
    }
    _current.value = current;
  }

  /// Scrolls to the heading picked, its line at the view's top as the
  /// first heading's is at the start, or as far as the text goes; at once
  /// under Reduce Motion.
  Future<void> _pick(String id) async {
    final i = int.tryParse(id);
    if (i == null || i >= _order.length || !_scroll.hasClients) return;
    final top = _top(_order[i]);
    if (top == null) return;
    final p = _scroll.position;
    final to = (top - widget.padding.top).clamp(0.0, p.maxScrollExtent);
    _picked = (index: i, at: null);
    _current.value = i;
    if (reduceMotion(context)) {
      _scroll.jumpTo(to);
    } else {
      await _scroll.animateTo(
        to,
        duration: Motion.standard,
        curve: Motion.settle,
      );
    }
    if (!mounted || _picked?.index != i) return;
    _picked = (index: i, at: _scroll.offset);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final rail = _entries.length >= 2;
      final narrow = box.maxWidth < outlineNarrowBelow;
      final pad = widget.padding;
      // The rail's dashes start where the path line's text does (the
      // padding's left); narrow, nearer the edge, and the text only as far
      // right as their room.
      final railLeft = narrow ? 0.0 : max(0, pad.left - RailFit.wide.inset);
      final textLeft = !rail
          ? pad.left
          : narrow
          ? max(pad.left, 36.0)
          : pad.left + 40;
      // Laid out at a new width, the headings stand elsewhere.
      if (_order.isNotEmpty) _changed();
      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _follow();
              return false;
            },
            child: SelectionArea(
              child: SingleChildScrollView(
                key: _viewport,
                controller: _scroll,
                padding: pad.copyWith(left: textLeft),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: markdownWidth),
                    child: _Scope(
                      outline: this,
                      child: AgentMarkdown(
                        widget.text,
                        images: widget.images,
                        headingMark: _Mark.new,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (rail)
            Positioned(
              left: railLeft.toDouble(),
              top: max(0, pad.top - 8),
              child: Rail(
                label: 'Outline',
                entries: _entries,
                current: _current,
                outline: true,
                fit: RailFit.of(textLeft - railLeft),
                onPick: (id) => _pick(id).ignore(),
              ),
            ),
        ],
      );
    },
  );
}
