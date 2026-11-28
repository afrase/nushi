import 'package:xterm2/xterm.dart';

/// Clears a terminal (⌘K), as Terminal and iTerm do: the scrollback and
/// everything above the line being typed on go, and that line (every row
/// it wraps over, before the cursor's row and after) moves to the first
/// row, the cursor where it was on it, so output goes on from the top as
/// in a new session. Nothing is sent to the program in it.
///
/// xterm2's own clear keeps the same line, and the shell's prompt mark on
/// it, but at the bottom of the screen and only up to the cursor's row
/// (docs/development.md's Dependencies); this moves it up and puts back
/// the rows after the cursor's, which the shell would not redraw. A
/// full-screen program's alternate screen is its own and is left as it
/// is: the program would only redraw it if told, and ⌘K tells it nothing.
void clearTerminal(Terminal terminal) {
  if (terminal.isUsingAltBuffer) return;
  final buffer = terminal.buffer;
  // The kept rows: the cursor's and those it wrapped from on the screen,
  // as the package's clear counts them.
  var first = buffer.absoluteCursorY;
  while (first > buffer.scrollBack && buffer.lines[first].isWrapped) {
    first--;
  }
  final kept = buffer.absoluteCursorY - first + 1;
  // The rows after the cursor's that continue its line, which the
  // package's clear drops. They are on the screen, so kept and these fit
  // in it.
  final rest = [
    for (
      var i = buffer.absoluteCursorY + 1;
      i < buffer.lines.length && buffer.lines[i].isWrapped;
      i++
    )
      buffer.lines[i],
  ];
  terminal.clear();
  // Now the screen is the blank rows above, then the kept ones. The blank
  // rows go, the rest of the line follows the kept rows (the clear let go
  // of those lines, so they are taken back as they are), and blank rows
  // fill the screen again. The kept lines are moved, not copied, so what
  // is anchored to them (the prompt mark) moves with them.
  final above = buffer.cursorY - (kept - 1);
  if (above <= 0) return;
  buffer.lines.trimStart(above);
  buffer.lines.pushAll(rest);
  for (var i = rest.length; i < above; i++) {
    buffer.lines.push(BufferLine(buffer.viewWidth));
  }
  buffer.setCursorY(buffer.cursorY - above);
  // Terminal.clear told the view while the cursor was still on the bottom
  // row; tell it again, so the input method's caret and its candidate
  // window move to the cursor's row now, not at the next output. The
  // package skips its notice during a program's synchronized update (DEC
  // 2026) and has no getter for that mode, so this one extra notice can
  // come during one; it only repaints early.
  terminal.notifyListeners();
}
