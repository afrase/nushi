import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/sidebar_view.dart';

// Switching chats by keyboard, as Claude Code does: ⌘ held alone numbers
// the sidebar's chats, ⌘1–⌘9 opens one, ⌥⌘↑ and ⌥⌘↓ go to the one before
// and after (⌘[ and ⌘] are Back and Forward, ADR 0119). And the chat's
// tabs: ⌃Tab and ⌃⇧Tab go through them. On Linux, Control in ⌘'s place
// (`keys.dart`).

/// The chats as the sidebar shows them, top to bottom, Pinned first, then
/// the sections and the groups, the archived (in their collapsed group)
/// and those of collapsed sections and headed groups left out but the
/// selected one: what ⌘1–⌘9, ⌥⌘↑ and ⌥⌘↓ go through.
List<ChatState> chatOrder(Daemon daemon) {
  final view = arrangeSidebar(daemon);
  final selected = daemon.selectedId;
  return [
    ...shownPinned(daemon),
    for (final (section, chats) in view.sections)
      ...section.collapsed ? chats.where((c) => c.id == selected) : chats,
    for (final MapEntry(key: folder, value: chats) in view.projects.entries)
      ...shownChats(folder, chats, selected),
    // None's one group has no header but under Pinned or a section, and
    // a group without one can't be collapsed (GroupedChats).
    for (final g in view.groups)
      ...g.label.isEmpty ? g.chats : shownChats(g.key, g.chats, selected),
  ];
}

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

/// Opens the chat [step] places on in the sidebar (⌥⌘↑ is -1, ⌥⌘↓ 1).
class StepChatIntent extends Intent {
  const new(this.step);

  final int step;
}

/// ⌘[n] (1–9) opens the [n]th chat: the same value each time, so a
/// terminal finds it among the keys it passes on.
Cmd chatNumberKey(int n) => _chatNumberKeys[n - 1];

const _chatNumberKeys = [
  Cmd(LogicalKeyboardKey.digit1),
  Cmd(LogicalKeyboardKey.digit2),
  Cmd(LogicalKeyboardKey.digit3),
  Cmd(LogicalKeyboardKey.digit4),
  Cmd(LogicalKeyboardKey.digit5),
  Cmd(LogicalKeyboardKey.digit6),
  Cmd(LogicalKeyboardKey.digit7),
  Cmd(LogicalKeyboardKey.digit8),
  Cmd(LogicalKeyboardKey.digit9),
];

/// ⌥⌘↑ and ⌥⌘↓, which no text field or editor binds (ADR 0119; ⌘[ and
/// ⌘] until Back and Forward took them); on Linux Ctrl+Page Up and
/// Ctrl+Page Down, as a browser's tabs.
const previousChatKey = Cmd(
  LogicalKeyboardKey.arrowUp,
  alt: true,
  linux: SingleActivator(LogicalKeyboardKey.pageUp, control: true),
);
const nextChatKey = Cmd(
  LogicalKeyboardKey.arrowDown,
  alt: true,
  linux: SingleActivator(LogicalKeyboardKey.pageDown, control: true),
);

/// Shows the tab [step] places on (⌃Tab is 1, ⌃⇧Tab -1) in the chat shown.
class StepTabIntent extends Intent {
  const new(this.step);

  final int step;
}

const nextTabKey = SingleActivator(LogicalKeyboardKey.tab, control: true);
const previousTabKey = SingleActivator(
  LogicalKeyboardKey.tab,
  control: true,
  shift: true,
);

/// ⌃⌘1–⌃⌘3 show Chat, Changes and Pull request (⌘⇧3 is macOS's
/// screenshot, so not ⌘⇧); on Linux Ctrl+Alt+1–3.
const chatTabKey = Cmd(
  LogicalKeyboardKey.digit1,
  ctrl: true,
  linux: SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true),
);
const changesTabKey = Cmd(
  LogicalKeyboardKey.digit2,
  ctrl: true,
  linux: SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true),
);
const pullTabKey = Cmd(
  LogicalKeyboardKey.digit3,
  ctrl: true,
  linux: SingleActivator(LogicalKeyboardKey.digit3, control: true, alt: true),
);

/// ⌘W: closes the preview tab showing, and with the last the pane. A focused
/// terminal keeps it, to close itself.
const closeTabKey = Cmd(LogicalKeyboardKey.keyW);

Cmd tabKey(ChatTab tab) => switch (tab) {
  .chat => chatTabKey,
  .changes => changesTabKey,
  .pull => pullTabKey,
};

/// Shows the tab of [chat] [step] places after the one shown (before,
/// negative), wrapping: Chat, Changes, then Pull request while it has one.
void stepTab(ChatState chat, int step) {
  final tabs = chat.tabs;
  chat.tab.value = tabs[(tabs.indexOf(chat.shownTab) + step) % tabs.length];
}

/// ⌘1–⌘9, ⌥⌘↑ and ⌥⌘↓ that switch chats, ⌃Tab and ⌃⇧Tab that switch its
/// tabs, wherever the focus is (a terminal, which keeps ⌘ and ⌃ keys,
/// passes them on as these intents).
final Map<ShortcutActivator, Intent> chatKeys = {
  for (var n = 1; n <= 9; n++) chatNumberKey(n): OpenChatIntent(n),
  previousChatKey: const StepChatIntent(-1),
  nextChatKey: const StepChatIntent(1),
  nextTabKey: const StepTabIntent(1),
  previousTabKey: const StepTabIntent(-1),
};

/// How long ⌘ is held alone before the chats show their numbers, so a
/// quick shortcut doesn't flash them.
// design: how long ⌘ is held before the hints show, as macOS's
const commandHoldDelay = Duration(milliseconds: 300);

/// Whether the command key (⌘, Control on Linux) is held alone (for
/// [commandHoldDelay]): the sidebar numbers its chats while it is. Any
/// other key first, and it isn't until it is pressed again; the app going
/// to the background ends it (⌘⇥ never sends the ⌘ up).
class CommandHold extends ValueNotifier<bool> {
  new() : super(false) {
    HardwareKeyboard.instance.addHandler(_onKey);
    _lifecycle = AppLifecycleListener(onInactive: _reset, onHide: _reset);
  }

  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  static bool _isCommand(LogicalKeyboardKey k) => switch (commandKey) {
    CommandKey.meta =>
      k == LogicalKeyboardKey.metaLeft || k == LogicalKeyboardKey.metaRight,
    CommandKey.control =>
      k == LogicalKeyboardKey.controlLeft ||
          k == LogicalKeyboardKey.controlRight,
  };

  bool _onKey(KeyEvent e) {
    final command = _isCommand(e.logicalKey);
    if (e is KeyDownEvent && command) {
      // The command key alone (the other one may be down too).
      final alone = HardwareKeyboard.instance.logicalKeysPressed.every(
        _isCommand,
      );
      _timer?.cancel();
      _timer = alone
          ? Timer(commandHoldDelay, () {
              if (cmdPressed()) value = true;
            })
          : null;
    } else if (e is KeyUpEvent && command) {
      if (!cmdPressed()) _reset();
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
