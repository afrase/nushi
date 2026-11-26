part of 'terminal_select.dart';

/// Shift+click: what a press with Shift takes as it goes down, and how its
/// click extends it ([TerminalSelect]'s comment says how).
extension _ShiftClick on _TerminalSelectState {
  /// Takes what a Shift+click in this press extends: [s], the selection,
  /// else the last plain click's or the cursor's cell.
  void _takeShift(BufferRange? s) {
    _dropShift();
    if (HardwareKeyboard.instance.isShiftPressed && !cmdPressed()) {
      final from = _from();
      final (start, end) = s == null
          ? (from, _cellEnd(from))
          : (s.normalized.begin, s.normalized.end);
      _shift = (
        start: _buffer.createAnchorFromOffset(start),
        end: _buffer.createAnchorFromOffset(end),
        unit: s == null ? 1 : _unitOf(s),
        block:
            HardwareKeyboard.instance.isAltPressed ||
            (s != null &&
                widget.controller.selectionMode == SelectionMode.block),
      );
    }
  }

  /// Lets go of what the press took.
  void _dropShift() {
    _shift?.start.dispose();
    _shift?.end.dispose();
    _shift = null;
  }

  /// The unit [selection] was made by, if the last press made it.
  int _unitOf(BufferRange selection) {
    final made = _made;
    if (made == null ||
        !_buffer.ownsAnchor(made.start) ||
        !_buffer.ownsAnchor(made.end)) {
      return 1;
    }
    final n = selection.normalized;
    return made.start.offset == n.begin && made.end.offset == n.end
        ? made.unit
        : 1;
  }

  /// Holds the selection as it is now, made by [unit]; nothing with no
  /// [unit] or no selection.
  void _remember(int? unit) {
    _made?.start.dispose();
    _made?.end.dispose();
    _made = null;
    final s = unit == null || !mounted
        ? null
        : widget.controller.selectionFor(_buffer)?.normalized;
    if (s == null) return;
    _made = (
      start: _buffer.createAnchorFromOffset(s.begin),
      end: _buffer.createAnchorFromOffset(s.end),
      unit: unit!,
    );
  }

  /// Where a Shift+click with no selection starts: the last plain click's
  /// cell (the oldest line's if it was trimmed away), else the cursor's.
  CellOffset _from() {
    final last = _lastClick;
    if (last != null && !last.attached) return const CellOffset(0, 0);
    if (last != null && _buffer.ownsAnchor(last)) return last.offset;
    return _cellAt(CellOffset(_buffer.cursorX, _buffer.absoluteCursorY));
  }

  /// A click the view took as its own tap, at [at]: with Shift, extends
  /// what the press took as it went down; plain, remembered for the next
  /// Shift+click.
  void _click(CellOffset at) {
    final shift = _shift;
    if (shift != null && HardwareKeyboard.instance.isShiftPressed) {
      _extend(shift, _cellAt(at));
      _pressUnit = shift.unit;
      _dropShift();
      return;
    }
    _dropShift();
    _lastClick?.dispose();
    _lastClick = _buffer.createAnchorFromOffset(_cellAt(at));
  }

  /// Extends [shift] to [cell] by its unit: the end moves to a cell at or
  /// after the start, the start to one before it; a block grows to hold
  /// the cell. A start trimmed from the scrollback is the oldest line kept.
  void _extend(_Extend shift, CellOffset cell) {
    if (!_buffer.ownsAnchor(shift.end)) return;
    final end = shift.end.offset;
    final start = _buffer.ownsAnchor(shift.start)
        ? shift.start.offset
        : shift.start.attached
        ? null
        : const CellOffset(0, 0);
    if (start == null) return;
    final (from, to) = _around(cell, shift.unit);
    if (shift.block) {
      _set(
        CellOffset(min(start.x, from.x), min(start.y, from.y)),
        CellOffset(max(end.x, to.x), max(end.y, to.y)),
        mode: SelectionMode.block,
      );
    } else if (cell.isBefore(start)) {
      _set(end, from, mode: SelectionMode.line);
    } else {
      _set(start, to, mode: SelectionMode.line);
    }
  }
}
