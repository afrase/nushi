part of 'terminal_select.dart';

/// What a held press makes of the terminal's changes: another buffer or a
/// clear lets it go, a start trimmed out of the scrollback is put back at
/// the oldest line kept ([TerminalSelect]'s comment says why).
extension _TerminalChanges on _TerminalSelectState {
  /// Notes the buffer as it is now, for the next change to compare.
  void _see() {
    final buffer = _buffer;
    _seen = (
      buffer: buffer,
      dropped: buffer.lines.evictedCount,
      lines: buffer.lines.length,
      clears: buffer.forceScrollToBottomGeneration,
      erases: buffer.screenClearGeneration,
    );
  }

  /// The terminal changed under the press. Another buffer (a full-screen
  /// program started or ended) or a clear lets the press go, pointer still
  /// or not, and leaves no selection. A clear is ⌘K or a reset, the
  /// start's line gone with no line dropped, or the screen or scrollback
  /// erased (the shell's `clear`, a program's clear and reprint) with the
  /// start's line gone, trimmed before or dropped in that same change:
  /// what is there after is not what the drag began on. Otherwise a start
  /// trimmed out of the scrollback as lines are dropped leaves the
  /// selection with no start (the package then has none); it starts at
  /// the oldest line kept.
  void _changedUnderPress() {
    final seen = _seen;
    _see();
    final pin = _pin;
    if (pin != null) {
      final buffer = _buffer;
      final same = seen != null && identical(seen.buffer, buffer);
      final dropped =
          same &&
          buffer.lines.evictedCount > seen.dropped &&
          buffer.lines.length >= seen.lines;
      final cleared =
          !same ||
          buffer.forceScrollToBottomGeneration != seen.clears ||
          (buffer.screenClearGeneration != seen.erases && !pin.start.attached);
      if (!identical(pin.buffer, buffer) ||
          cleared ||
          (!pin.start.attached && !_trimmed && !dropped)) {
        _letGo();
        return;
      }
      if (!pin.start.attached) _trimmed = true;
    }
    if (_pointer != null) _followOutput();
    final end = _end;
    if (_setting || pin == null || !_trimmed || end == null) return;
    if (!_buffer.ownsAnchor(end)) return;
    if (widget.controller.selectionFor(_buffer) != null) return;
    _set(const CellOffset(0, 0), end.offset);
  }
}
