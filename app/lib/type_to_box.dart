import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/menu.dart' show openMenus;
import 'package:nushi/run_state.dart';

// Type to write (ADR 0121): with the chat in sight and nothing that takes
// text focused, a character typed goes into the chat's box, which takes
// the focus, as if typed there, so `/` opens the commands' list. Keys
// with ⌘, Control or Option, Esc, the arrows, Tab, Enter and Space keep
// their meaning; so does what the focused part does with a key first (the
// transcript's R replies to its selection). On Windows Control and Alt
// together are AltGr, which types (`@` on a Spanish keyboard). The
// desktop's window only: the phone has its own box to tap.

/// The focus nodes a typed character goes on from to the chat's box,
/// besides the window's own: the transcript's (`TranscriptSelection`).
/// Anything else focused (a field, a terminal, the preview's editor, a
/// button) keeps its keys.
final Set<FocusNode> typesThrough = runSet();

/// Focus nodes whose own focused descendants a typed character goes on
/// from as well, when they sit under one of [typesThrough]'s: a diff's
/// (`DiffPresses`), whose panes take the focus on a click in their code,
/// in the transcript. A text field among them (an inlay's) keeps its
/// keys; the Changes and pull request tabs' diffs aren't on the chat's
/// tab, where alone a character goes on.
final Set<FocusNode> typesThroughWithin = runSet();

/// Whether a character typed with [focus] focused goes on to the box.
bool _passes(FocusNode focus) {
  if (typesThrough.contains(focus)) return true;
  final up = focus.ancestors;
  return up.any(typesThroughWithin.contains) &&
      up.any(typesThrough.contains) &&
      focus.context?.findAncestorWidgetOfExactType<EditableText>() == null;
}

/// Puts [e], a key the window's own focus ([root]) got unhandled, in the
/// shown chat's box when it's a character typed with nothing else that
/// takes it focused, no menu open and no dialog over the window.
KeyEventResult typeIntoBox(Daemon d, FocusNode root, KeyEvent e) {
  final c = typedCharacter(e);
  if (c == null) return KeyEventResult.ignored;
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null || focus != root && !_passes(focus)) {
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

/// The character [e] types, or null when it types none: a key let go,
/// one held with ⌘, Control or Option (but AltGr), or one whose character
/// isn't text (Esc, Enter, Tab, a space alone). What a question card
/// takes to start its box (`question_card.dart`) as well.
String? typedCharacter(KeyEvent e) {
  if (e is KeyUpEvent) return null;
  final c = e.character;
  final keys = HardwareKeyboard.instance;
  final altGr = conventions.altGr && keys.isControlPressed && keys.isAltPressed;
  if (c == null ||
      !_typed(c) ||
      keys.isMetaPressed ||
      !altGr && (keys.isControlPressed || keys.isAltPressed)) {
    return null;
  }
  return c;
}

/// Whether [c] is text typed: printable, and not a space alone (Space
/// presses what has the focus, and scrolls).
bool _typed(String c) =>
    c.trim().isNotEmpty && c.runes.every((r) => r >= 0x20 && r != 0x7f);
