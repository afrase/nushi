import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/menu.dart' show openMenus;
import 'package:nushi/run_state.dart';

// Type to write (ADR 0121): with the chat in sight and nothing that takes
// text focused, a character typed goes into the chat's box, which takes
// the focus, as if typed there, so `/` opens the commands' list. Keys
// with ⌘, Control or Option, Esc, the arrows, Tab, Enter and Space keep
// their meaning; so does what the focused part does with a key first (the
// transcript's R replies to its selection). The Mac's and Linux's window
// only: the phone has its own box to tap.

/// The focus nodes a typed character goes on from to the chat's box,
/// besides the window's own: the transcript's (`TranscriptSelection`).
/// Anything else focused (a field, a terminal, the preview's editor, a
/// button) keeps its keys.
final Set<FocusNode> typesThrough = runSet();

/// Puts [e], a key the window's own focus ([root]) got unhandled, in the
/// shown chat's box when it's a character typed with nothing else that
/// takes it focused, no menu open and no dialog over the window.
KeyEventResult typeIntoBox(Daemon d, FocusNode root, KeyEvent e) {
  if (e is KeyUpEvent) return KeyEventResult.ignored;
  final c = e.character;
  final keys = HardwareKeyboard.instance;
  if (c == null ||
      !_typed(c) ||
      keys.isMetaPressed ||
      keys.isControlPressed ||
      keys.isAltPressed) {
    return KeyEventResult.ignored;
  }
  final focus = FocusManager.instance.primaryFocus;
  if (focus != root && !typesThrough.contains(focus)) {
    return KeyEventResult.ignored;
  }
  final context = root.context;
  if (openMenus.value > 0 ||
      context == null ||
      !(ModalRoute.of(context)?.isCurrent ?? true)) {
    return KeyEventResult.ignored;
  }
  final chat = d.chatShows ? d.selected : null;
  if (chat == null || chat.shownTab != ChatTab.chat) {
    return KeyEventResult.ignored;
  }
  final take = chat.draft.typed;
  return take != null && take(c)
      ? KeyEventResult.handled
      : KeyEventResult.ignored;
}

/// Whether [c] is text typed: printable, and not a space alone (Space
/// presses what has the focus, and scrolls).
bool _typed(String c) =>
    c.trim().isNotEmpty && c.runes.every((r) => r >= 0x20 && r != 0x7f);
