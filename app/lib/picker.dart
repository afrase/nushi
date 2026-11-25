import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The pickers: a box over the window that lists what to go to or open
/// and runs what's picked, asking nothing (docs/design.md's Dialogs). Each
/// is shown as a route of its [settings], which is how the app's keys and
/// menu bar tell one from a dialog that asks something: one picker shows
/// at a time, another's key puts its picker in the open one's place, and
/// its own key closes it.
enum Picker {
  /// ⌘K's command palette.
  palette,

  /// Artifacts…, as a palette where the details panel has no room.
  artifacts,

  /// ⌘P's file opener.
  openFile;

  /// The route settings it's shown with.
  RouteSettings get settings => RouteSettings(name: 'picker', arguments: this);
}

/// The picker [route] shows, or null for any other route.
Picker? pickerOf(Route<Object?>? route) => switch (route?.settings.arguments) {
  final Picker p => p,
  _ => null,
};

/// A type-to-filter list's keys, on its field: ↑↓ [move] the selection
/// round [count] rows from [at] (to the index, and by how far: down the
/// list when it's more than 0, so a wrap to the top is up), ⏎ (the
/// keypad's too) [pick]s the row at it, and Esc runs [escape] when there
/// is one (else the route's own Esc closes it). Without [pick] ⏎ is left
/// alone (a search still asked). The palette's, Open file…'s, the rewind
/// list's, a long menu's filter and the Jira issue picker's.
KeyEventResult pickKey(
  KeyEvent e, {
  required int count,
  required int at,
  required void Function(int to, int by) move,
  VoidCallback? pick,
  VoidCallback? escape,
}) {
  if (e is KeyUpEvent) return KeyEventResult.ignored;
  switch (e.logicalKey) {
    case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp
        when count > 0:
      final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final to = (at + step) % count;
      move(to, to - at);
    case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
        when pick != null && at < count:
      pick();
    case LogicalKeyboardKey.escape when escape != null:
      escape();
    default:
      return KeyEventResult.ignored;
  }
  return KeyEventResult.handled;
}

/// Whether [text] holds each word of [query], case aside: how the
/// palette, a long menu's filter and the rewind list match, so 'tree
/// file' finds "Show file tree" in each.
bool matchesWords(String text, String query) {
  final t = text.toLowerCase();
  return query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .every(t.contains);
}
