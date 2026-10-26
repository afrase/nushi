import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';

// Switching chats by keyboard, as Claude Code does: ⌘ held alone numbers
// the sidebar's chats, ⌘1–⌘9 opens one, ⌘[ and ⌘] go to the one before
// and after.

/// The sidebar's groups: each folder's chats (a chat in a worktree under
/// its repository; scratch chats under ''), the folder with the newest
/// chat first, the newest chat first in each. Archived chats aren't in it.
Map<String, List<ChatState>> chatGroups(Daemon daemon) {
  final groups = <String, List<ChatState>>{};
  final byNewest = daemon.chats.values.where((c) => !c.archived).toList()
    ..sort((a, b) => b.created.compareTo(a.created));
  for (final c in byNewest) {
    (groups[c.scratch ? '' : c.home] ??= []).add(c);
  }
  return groups;
}

/// The chats as the sidebar lists them, top to bottom, the archived (in
/// their collapsed group) left out: what ⌘1–⌘9, ⌘[ and ⌘] go through.
List<ChatState> chatOrder(Daemon daemon) => [
  for (final chats in chatGroups(daemon).values) ...chats,
];

/// Opens the [n]th chat (1–9) of [chatOrder], if there's one.
void openNthChat(Daemon daemon, int n) {
  final order = chatOrder(daemon);
  if (n >= 1 && n <= order.length) daemon.select(order[n - 1].id);
}

/// Opens the chat [step] places after the one shown (before, negative) in
/// [chatOrder], wrapping; with none shown, the first or the last.
void stepChat(Daemon daemon, int step) {
  final order = chatOrder(daemon);
  if (order.isEmpty) return;
  final at = order.indexWhere((c) => c.id == daemon.selectedId);
  final next = at < 0
      ? (step > 0 ? 0 : order.length - 1)
      : (at + step) % order.length;
  daemon.select(order[next].id);
}

/// Opens the [n]th chat of the sidebar (⌘1–⌘9).
class OpenChatIntent extends Intent {
  const new(this.n);

  final int n;
}

/// Opens the chat [step] places on in the sidebar (⌘[ is -1, ⌘] 1).
class StepChatIntent extends Intent {
  const new(this.step);

  final int step;
}

/// ⌘[n] (1–9) opens the [n]th chat.
SingleActivator chatNumberKey(int n) =>
    SingleActivator(LogicalKeyboardKey(0x30 + n), meta: true);

const previousChatKey = SingleActivator(
  LogicalKeyboardKey.bracketLeft,
  meta: true,
);
const nextChatKey = SingleActivator(
  LogicalKeyboardKey.bracketRight,
  meta: true,
);

/// ⌘1–⌘9, ⌘[ and ⌘]: the keys that switch chats, wherever the focus is
/// (a terminal, which keeps ⌘ keys, passes them on as these intents).
final Map<ShortcutActivator, Intent> chatKeys = {
  for (var n = 1; n <= 9; n++) chatNumberKey(n): OpenChatIntent(n),
  previousChatKey: const StepChatIntent(-1),
  nextChatKey: const StepChatIntent(1),
};

/// How long ⌘ is held alone before the chats show their numbers, so a
/// quick shortcut doesn't flash them.
const commandHoldDelay = Duration(milliseconds: 300);

/// Whether ⌘ is held alone (for [commandHoldDelay]): the sidebar numbers
/// its chats while it is. Any other key first, and it isn't until ⌘ is
/// pressed again; the app going to the background ends it (⌘⇥ never
/// sends the ⌘ up).
class CommandHold extends ValueNotifier<bool> {
  new() : super(false) {
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle = AppLifecycleListener(onInactive: _reset, onHide: _reset);
  }

  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  static bool _isMeta(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight;

  bool _onKey(KeyEvent e) {
    final meta = _isMeta(e.logicalKey);
    if (e is KeyDownEvent && meta) {
      // ⌘ alone (the other ⌘ may be down too).
      final alone = HardwareKeyboard.instance.logicalKeysPressed.every(_isMeta);
      _timer?.cancel();
      _timer = alone
          ? Timer(commandHoldDelay, () {
              if (HardwareKeyboard.instance.isMetaPressed) value = true;
            })
          : null;
    } else if (e is KeyUpEvent && meta) {
      if (!HardwareKeyboard.instance.isMetaPressed) _reset();
    } else if (e is KeyDownEvent && !value) {
      _timer?.cancel(); // a shortcut, not a hold
    }
    return false; // the key goes on as usual
  }

  void _reset() {
    _timer?.cancel();
    value = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle.dispose();
    super.dispose();
  }
}
