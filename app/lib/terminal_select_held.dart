part of 'terminal_select.dart';

/// A drag held past the view's edge: when [HeldScroll] scrolls, where the
/// selection's far end goes as it moves the view or as output arrives, and
/// what a release past an edge ends ([TerminalSelect]'s comment says why).
mixin _HeldDrag on State<TerminalSelect>, TickerProvider {
  /// The terminal's view, by its key.
  GlobalKey<TerminalViewState> get _view;

  /// The mouse pointer pressed with the primary button, while it is down.
  int? get _pointer;

  /// The press's held start, once the package has set its first selection.
  _Pin? get _pin;

  /// Whether the press has let go and pins nothing more: the screen
  /// changed buffers under it (a full-screen program started or ended) or
  /// was cleared.
  bool get _off;

  /// Lets the press go for good.
  void _letGo();

  /// Whether a pin is still in the buffer shown.
  bool _holds(_Pin pin);

  /// The buffer shown.
  Buffer get _buffer;

  /// Selects from [pin] to the cell [to], or, from a word or line pin, to
  /// the word or line [to] is in; nothing when that is [base] to [extent]
  /// already.
  void _select(_Pin pin, CellOffset to, CellOffset? base, CellOffset? extent);

  /// The drag's scroll while it is held past an edge.
  late final _held = HeldScroll(
    this,
    view: () => _view.currentState,
    onEdge: _toEdge,
  );

  /// Whether the session ended while this press was held: its scroll
  /// stops for good, though the pointer moves on. A new press scrolls.
  bool _endedHeld = false;

  /// Whether output's catch-up after the frame's layout is asked for.
  bool _following = false;

  /// Scrolls while the press is a selecting drag held past an edge.
  void _drive() => _pointer != null && _pin != null && !_off && !_endedHeld
      ? _held.resume()
      : _held.stop();

  /// The session ended: a press held now stops scrolling for good.
  void _sessionEnded() {
    if (_pointer == null) return;
    _endedHeld = true;
    _held.stop();
  }

  /// A release past an edge ends the package's own edge step in flight
  /// (an animation of the scroll it starts on each move), so the view
  /// doesn't coast on once the button is up. A release inside leaves the
  /// scroll alone.
  void _stopPackageStep() {
    if (_held.edge() == null) return;
    final position = _view.currentState?.scrollableState?.position;
    position?.jumpTo(position.pixels);
  }

  /// The held scroll moved the view: the selection runs to [to], the cell
  /// at the edge under the pointer. It runs in a frame callback, so it
  /// never builds a cell from a pin no longer in the buffer shown, nor
  /// from a row outside it: the first lets the press go.
  void _toEdge(CellOffset to) {
    final pin = _pin;
    if (pin == null || _off || _pointer == null) return;
    if (!_holds(pin)) return _letGo();
    if (to.y < 0 || to.y >= _buffer.lines.length) return;
    final s = widget.controller.selectionFor(_buffer);
    _select(pin, to, s?.begin, s?.end);
  }

  /// Output arrived while the press is held: once the frame's layout has
  /// followed it (the view sticks to the end), the far end goes to the row
  /// at the edge under the pointer, as a tick runs before layout and would
  /// read the old end. The held scroll starts again too, for output that
  /// gives a view with nothing to scroll a scrollback while the pointer is
  /// held still above its top. It only answers output, and a tick that
  /// finds the buffer's end stops, so nothing ticks on at the end of an
  /// idle buffer. One catch-up a frame, however many writes it has; the
  /// output's own layout brings the frame.
  void _followOutput() {
    if (_following) return;
    _following = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _following = false;
      if (!mounted || _pointer == null) return;
      if (_held.edge() case final edge?) _toEdge(edge);
      _drive();
    });
  }
}
