import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm2/xterm.dart';

/// Scrolls a terminal's view every frame while a selecting drag is held
/// past its top or bottom edge, as Terminal and iTerm do, and says which
/// cell at that edge is under the pointer's column: the selection's far
/// end.
///
/// xterm2's own edge scroll (Flutter's `EdgeDraggingAutoScroller`) moves
/// only on a pointer move: it keeps the pointer as a point in the content,
/// so a hand held still past the edge scrolls a step and stops
/// (docs/development.md's Dependencies). This one keeps the pointer on the
/// screen and scrolls on each frame by the package's curve, 30 px a second
/// for each pixel past the edge, with room to grow: up to 100 px past
/// (the package stops at 20), and never more than three rows a frame.
///
/// It never fights the package's step on a move: a frame scrolls to the
/// further of the two, never their sum, and never back.
///
/// A step counts in text, not in pixels. With the scrollback full, each
/// new line drops the oldest, and the package keeps a view that is off the
/// end on its text by moving it up by the lines dropped, in the frame's
/// layout; a tick runs before that layout and reads the offset as it was,
/// and its jump would set the view's place over the package's. So a tick
/// first moves the offset it read, and the place it last put the view, up
/// by the lines dropped since it last looked (a count the buffer keeps, so
/// nothing is walked). A view at the end follows the output instead, as
/// the package has it, and is left there. The tick stays before layout
/// rather than after: its jump ends the package's own step in flight
/// before that step ticks, and that step, an animation to an offset in
/// pixels, would undo the shift itself. Output is written between frames,
/// so the lines dropped since the last tick are those the offset read has
/// not yet moved for. It runs on a
/// [Ticker], so it stops with the frames, and stops for good at the
/// buffer's first or last row; Reduce Motion doesn't apply to the user's
/// own drag.
class HeldScroll {
  new(TickerProvider vsync, {required this.view, required this.onEdge}) {
    _ticker = vsync.createTicker(_tick);
  }

  /// The package's speed: a second's scroll for each pixel past the edge.
  static const perPixel = 30.0;

  /// How far past the edge still speeds it up.
  static const farthest = 100.0;

  /// The most rows one frame scrolls.
  static const rowsAFrame = 3;

  /// The terminal's view, while it's shown.
  final TerminalViewState? Function() view;

  /// Called after each frame's scroll with the cell at the edge under the
  /// pointer's column.
  final void Function(CellOffset edge) onEdge;

  late final Ticker _ticker;

  /// The pointer, on the screen, while it's held.
  Offset? at;

  /// Where this last put the view, so a frame never adds its step to one
  /// the package took.
  double? _last;
  Duration _then = Duration.zero;

  /// The buffer and how many lines it had dropped from its start when
  /// this last looked: the lines dropped since move the text up.
  Buffer? _buffer;
  int _dropped = 0;

  /// Whether it is scrolling.
  bool get running => _ticker.isActive;

  /// Scrolls while the held pointer is past an edge, else stops at once;
  /// again after it stopped at the buffer's end, when output arrived.
  void resume() {
    if (edge() == null) {
      stop();
    } else if (!_ticker.isActive) {
      _then = Duration.zero;
      _last = null;
      _buffer = view()?.widget.terminal.buffer;
      _dropped = _buffer?.lines.evictedCount ?? 0;
      _ticker.start();
    }
  }

  /// Stops, leaving the pointer held: a later move or [resume] starts it.
  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  /// Stops and forgets the pointer: it was let go.
  void release() {
    at = null;
    stop();
  }

  void dispose() => _ticker.dispose();

  /// The cell at the edge the held pointer is past, under its column, or
  /// null when it is inside the view or the view can't scroll (a program
  /// that reads the mouse, or the alternate screen).
  CellOffset? edge() {
    if (_where() case (final v, _, final past) when past != 0) {
      final r = v.renderTerminal;
      final x = r.globalToLocal(at!).dx;
      return r.getCellOffset(Offset(x, past > 0 ? r.size.height - 1 : 0));
    }
    return null;
  }

  /// The view, its scroll and how far past its rows' bottom (above 0) or
  /// top (below 0) the held pointer is; null with no pointer or view.
  (TerminalViewState, ScrollPosition, double)? _where() {
    final pointer = at;
    final v = view();
    final scrollable = v?.scrollableState;
    if (pointer == null || v == null || !v.mounted || scrollable == null) {
      return null;
    }
    final position = scrollable.position;
    if (!position.physics.shouldAcceptUserOffset(position)) return null;
    final r = v.renderTerminal;
    final y = r.globalToLocal(pointer).dy;
    final past = y < 0 ? y : max(0.0, y - r.size.height);
    return (v, position, past);
  }

  void _tick(Duration elapsed) {
    final seconds =
        (elapsed - _then).inMicroseconds / Duration.microsecondsPerSecond;
    _then = elapsed;
    final where = _where();
    if (where == null || where.$3 == 0) return stop();
    final (v, position, past) = where;
    final r = v.renderTerminal;
    final step = min(
      min(past.abs(), farthest) * perPixel * seconds,
      rowsAFrame * r.lineHeight,
    );
    final shift = _droppedSince(v) * r.lineHeight;
    final pixels = position.pixels < position.maxScrollExtent
        ? max(0.0, position.pixels - shift)
        : position.pixels;
    final last = switch (_last) {
      final last? => max(0.0, last - shift),
      null => pixels,
    };
    final double to;
    final bool end;
    if (past > 0) {
      to = min(max(pixels, min(pixels, last) + step), position.maxScrollExtent);
      end = to >= position.maxScrollExtent;
    } else {
      to = max(min(pixels, max(pixels, last) - step), position.minScrollExtent);
      end = to <= position.minScrollExtent;
    }
    if (to != position.pixels) {
      position.jumpTo(to);
    } else if (pixels != position.pixels) {
      // The step is the dropped lines' height, so the place is the offset
      // read. The package must still hear it, or its own step in flight
      // goes on and its place stays where its layout shifted it: so the
      // view goes to the shifted place first, then back.
      position
        ..jumpTo(pixels)
        ..jumpTo(to);
    }
    _last = to;
    final edge = this.edge();
    if (edge != null) onEdge(edge);
    if (end) stop();
  }

  /// The lines the buffer dropped from its start since the last tick: none
  /// when it is another buffer (the alternate screen, a reconnect).
  int _droppedSince(TerminalViewState v) {
    final buffer = v.widget.terminal.buffer;
    final count = buffer.lines.evictedCount;
    final dropped = identical(buffer, _buffer) ? count - _dropped : 0;
    _buffer = buffer;
    _dropped = count;
    return dropped;
  }
}
