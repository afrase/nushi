import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/terminal_held_scroll.dart';
import 'package:xterm2/xterm.dart';

part 'terminal_select_changes.dart';
part 'terminal_select_held.dart';
part 'terminal_select_shift.dart';

/// Keeps a drag's selection starting where the drag began while the view
/// scrolls under it: past the top or bottom edge, or as output arrives.
///
/// xterm2 keeps a drag's start as a point on the screen and makes it a cell
/// again on every move, at the scroll offset of the moment, so once the
/// view scrolls the start lies over other text (docs/development.md's
/// Dependencies). Here the start is pinned to its text: the first selection
/// the package sets in a press is held as anchors on its line, and each one
/// it sets after, during that press, is set again from the held start to
/// the package's end, in the package's mode. The package still owns the
/// drag: its edge scroll, Option's block mode and its rule that a program
/// reading the mouse gets a drag unless Shift is held. A double-click drag
/// grows by whole words and a triple-click drag by whole lines, which the
/// package's own drag (by characters) does not. Held still past the top or
/// bottom edge, the drag goes on scrolling a frame at a time
/// ([HeldScroll]), where the package's would stop. The package moves the
/// view and the selection for its own reasons too: where the buffer under
/// a press changes (a full-screen program) or is cleared, the press lets
/// go, its start released and its scroll stopped, rather than guess.
///
/// Shift+click extends the selection as Terminal and macOS's text views
/// do: a click after its start moves its end to the click, one before its
/// start moves its start there, and the rest stays. A selection made by a
/// double or triple click grows by whole words or lines, and a block by
/// the rectangle that holds the click. With no selection it runs from the
/// last plain click's cell, else the cursor's. It is a run of text unless
/// it extends a block or Option is held. The package has no Shift+click;
/// it takes the click only where it would call the view's own tap (in a
/// program reading the mouse, only when Shift isn't the program's too),
/// and never with ⌘, which opens a link.
///
/// Clicks are counted here as the package counts its double and triple
/// clicks (within `kDoubleTapTimeout` of a click's release and
/// `kDoubleTapSlop` of it), but from every quick release rather than only
/// from taps the package recognised: so a click then a quick press and
/// drag nearby selects by words, as a double-click drag does on the Mac.
class TerminalSelect extends StatefulWidget {
  const new({
    required this.terminal,
    required this.controller,
    required this.builder,
    this.ended = false,
    super.key,
  });

  /// The terminal shown.
  final Terminal terminal;

  /// The view's controller, which holds the selection.
  final TerminalController controller;

  /// Whether its session has ended: a drag held as it ended stops
  /// scrolling for the rest of that press.
  final bool ended;

  /// The terminal's view, given its key (to find its rows and scroll) and
  /// what its tap (`onTapUp`) calls with the cell clicked, unless ⌘ is
  /// held.
  final Widget Function(
    BuildContext context,
    GlobalKey<TerminalViewState> key,
    void Function(CellOffset) click,
  )
  builder;

  @override
  State<TerminalSelect> createState() => _TerminalSelectState();
}

/// What a drag's start holds: one cell, or the word or the line a double or
/// triple click began on, as the anchors before and after it, in the buffer
/// they were made in.
typedef _Pin = ({Buffer buffer, CellAnchor start, CellAnchor end});

/// What a Shift+click extends: the selection's start and end (or the last
/// click's cell), the unit it grows by (1 a cell, 2 a word, 3 a line) and
/// whether it is a block.
typedef _Extend = ({CellAnchor start, CellAnchor end, int unit, bool block});

/// The selection a press last left, and the unit it was made by.
typedef _Made = ({CellAnchor start, CellAnchor end, int unit});

class _TerminalSelectState extends State<TerminalSelect>
    with SingleTickerProviderStateMixin, _HeldDrag {
  @override
  final _view = GlobalKey<TerminalViewState>();

  @override
  int? _pointer;

  /// Where it went down, to tell a click from a drag.
  late Offset _downAt;

  /// The selection when it went down: the package's first selection in
  /// the press is the first that differs.
  (CellOffset, CellOffset)? _before;

  @override
  _Pin? _pin;

  @override
  bool _off = false;

  /// The end the selection last had, held so a start trimmed out of the
  /// scrollback can be put back at the oldest line still kept.
  CellAnchor? _end;

  /// Whether the press's start was trimmed out of the scrollback: its
  /// line was dropped as new lines came, not cleared.
  bool _trimmed = false;

  /// The buffer as the terminal's last change left it: how many lines it
  /// had dropped from its start, how many it had, and its clears.
  ({Buffer buffer, int dropped, int lines, int clears, int erases})? _seen;

  /// Set while this sets the selection, so its own change isn't taken
  /// for the package's.
  bool _setting = false;

  /// The clicks in a row (1, 2 or 3), as the package counts them for its
  /// double and triple click.
  int _clicks = 0;
  late Offset _clickAt;
  Timer? _clickTimer;

  /// The last plain click's cell, the start of a Shift+click with no
  /// selection.
  CellAnchor? _lastClick;

  /// What a Shift+click in this press extends, taken as it went down: the
  /// package clears the selection on the tap, before the click arrives.
  _Extend? _shift;

  /// The unit this press selects by: its clicks, or a Shift+click's.
  int _pressUnit = 1;

  /// The selection the last press left and its unit, which a Shift+click
  /// that extends it grows by.
  _Made? _made;

  Terminal get _terminal => widget.terminal;
  @override
  Buffer get _buffer => _terminal.buffer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_selectionChanged);
    _terminal.addListener(_terminalChanged);
    _see();
  }

  @override
  void didUpdateWidget(TerminalSelect old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_selectionChanged);
      widget.controller.addListener(_selectionChanged);
    }
    if (old.terminal != widget.terminal) {
      old.terminal.removeListener(_terminalChanged);
      _terminal.addListener(_terminalChanged);
      _release();
      _see();
      _lastClick?.dispose();
      _lastClick = null;
      _dropShift();
      _remember(null);
    }
    if (widget.ended && !old.ended) _sessionEnded();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_selectionChanged);
    _terminal.removeListener(_terminalChanged);
    _clickTimer?.cancel();
    _release();
    _held.dispose();
    _lastClick?.dispose();
    _dropShift();
    _remember(null);
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse ||
        e.buttons & kPrimaryMouseButton == 0 ||
        _pointer != null) {
      return;
    }
    _release();
    _pointer = e.pointer;
    _endedHeld = false;
    _downAt = e.position;
    final again =
        (_clickTimer?.isActive ?? false) &&
        (e.position - _clickAt).distance <= kDoubleTapSlop;
    _clicks = again ? _clicks % 3 + 1 : 1;
    final s = widget.controller.selectionFor(_buffer);
    _before = s == null ? null : (s.begin, s.end);
    _pressUnit = _clicks;
    _takeShift(s);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _stopPackageStep();
    _release();
    // The package's double and triple click select on this release, after
    // this listener: what they leave is held once they have.
    scheduleMicrotask(() => _remember(_pressUnit));
    _clickTimer?.cancel();
    if (e is PointerUpEvent && (e.position - _downAt).distance <= kTouchSlop) {
      _clickAt = e.position;
      _clickTimer = Timer(kDoubleTapTimeout, () {});
    }
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    _held.at = e.position;
    _drive();
  }

  /// The press lets go for good: the buffer under it changed, and Nushi
  /// can't put the package's view and selection right in one step. Its
  /// start is released, the held scroll stops, the selection goes, and
  /// the rest of the press selects nothing more; a new press selects as
  /// any.
  @override
  void _letGo() {
    _release();
    _off = true;
    widget.controller.clearSelection();
  }

  /// Whether [pin] is still in the buffer shown: made there, with both
  /// its anchors on that buffer's lines, or its start trimmed out of the
  /// scrollback (the selection then starts at the oldest line kept).
  @override
  bool _holds(_Pin pin) =>
      identical(pin.buffer, _buffer) &&
      (pin.start.attached
          ? _buffer.ownsAnchor(pin.start) && _buffer.ownsAnchor(pin.end)
          : _trimmed);

  /// Lets go of the press's held start.
  void _release() {
    _held.release();
    _pin?.start.dispose();
    _pin?.end.dispose();
    _pin = null;
    _end?.dispose();
    _end = null;
    _trimmed = false;
    _off = false;
  }

  /// The terminal's listener, a method of the class so that removing it
  /// finds it (an extension's tear-off is a new closure each time).
  void _terminalChanged() => _changedUnderPress();

  void _selectionChanged() {
    if (_setting || _pointer == null) return;
    if (_off) {
      // The press let go: what the package selects in the rest of it, from
      // the screen point it began at, now over other text, goes.
      if (widget.controller.selection != null) {
        widget.controller.clearSelection();
      }
      return;
    }
    final s = widget.controller.selectionFor(_buffer);
    if (s == null) return;
    var pin = _pin;
    if (pin == null) {
      if (_before == (s.begin, s.end)) return;
      final (start, end) = _around(s.begin);
      pin = _pin = (
        buffer: _buffer,
        start: _buffer.createAnchorFromOffset(start),
        end: _buffer.createAnchorFromOffset(end),
      );
    }
    if (!_holds(pin)) {
      // Another buffer now, which the terminal's listener had not yet
      // heard of.
      _letGo();
      return;
    }
    // The cell the pointer is on, from the end the package set: after its
    // start, the package ends a selection after that cell, else before it.
    // Past an edge, the row at that edge: the package's is out of view.
    final to =
        _held.edge() ??
        (s.end.isAfter(s.begin) ? _cellBefore(s.end) : _cellAt(s.end));
    _select(pin, to, s.begin, s.end);
    _drive();
  }

  @override
  void _select(_Pin pin, CellOffset to, CellOffset? base, CellOffset? extent) {
    final (pinStart, pinEnd) = pin.start.attached
        ? (pin.start.offset, pin.end.offset)
        : (const CellOffset(0, 0), const CellOffset(0, 0));
    final (toStart, toEnd) = _around(to);
    final (b, e) = to.isAfterOrSame(pinStart)
        ? (pinStart, toEnd)
        : (pinEnd, toStart);
    if (b == base && e == extent) {
      _end?.dispose();
      _end = _buffer.createAnchorFromOffset(e);
      return;
    }
    _set(b, e);
  }

  /// Sets the selection, in [mode] or else the controller's (the mode the
  /// package chose for the drag).
  void _set(CellOffset base, CellOffset extent, {SelectionMode? mode}) {
    if (_pointer != null) {
      _end?.dispose();
      _end = _buffer.createAnchorFromOffset(extent);
    }
    _setting = true;
    try {
      widget.controller.setSelection(
        _buffer.createAnchorFromOffset(base),
        _buffer.createAnchorFromOffset(extent),
        mode: mode ?? widget.controller.selectionMode,
      );
    } finally {
      _setting = false;
    }
  }

  /// The cell at [at], or its word or line by [unit] (else this press's
  /// clicks: a double or triple click), as the offsets before and after it.
  (CellOffset, CellOffset) _around(CellOffset at, [int? unit]) {
    final cell = _cellAt(at);
    final range = switch (unit ?? _clicks) {
      2 => _buffer.getWordBoundary(cell),
      3 => _buffer.getLineBoundary(cell),
      _ => null,
    };
    if (range != null) return (range.begin, range.end);
    return (cell, _cellEnd(cell));
  }

  /// The cell starting at [at]: a wide character's, from its second half.
  CellOffset _cellAt(CellOffset at) {
    final line = _buffer.lines[at.y];
    final x = min(at.x, _terminal.viewWidth - 1);
    if (x > 0 && line.getWidth(x) == 0 && line.getWidth(x - 1) == 2) {
      return CellOffset(x - 1, at.y);
    }
    return CellOffset(x, at.y);
  }

  /// The cell that ends at [at].
  CellOffset _cellBefore(CellOffset at) =>
      _cellAt(CellOffset(max(0, at.x - 1), at.y));

  /// The offset after the cell at [cell].
  CellOffset _cellEnd(CellOffset cell) {
    final width = _buffer.lines[cell.y].getWidth(cell.x) == 2 ? 2 : 1;
    return CellOffset(min(cell.x + width, _terminal.viewWidth), cell.y);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.builder(context, _view, _click),
  );
}
