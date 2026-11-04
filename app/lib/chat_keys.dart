import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/settings.dart';

// Switching chats by keyboard, as Claude Code does: ⌘ held alone numbers
// the sidebar's chats, ⌘1–⌘9 opens one, ⌘[ and ⌘] go to the one before
// and after. And the chat's tabs: ⌃Tab and ⌃⇧Tab go through them.

/// The pinned chats, top first (`Chat.pin`, kept by the daemon); archived
/// chats are never pinned.
List<ChatState> pinnedChats(Daemon daemon) =>
    daemon.chats.values.where((c) => c.pin > 0 && !c.archived).toList()
      ..sort((a, b) => a.pin.compareTo(b.pin));

/// The sidebar's groups: each folder's chats (a chat in a worktree under
/// its repository; scratch chats under ''), the folder with the newest
/// chat first, the newest chat first in each. Archived chats aren't in
/// it, nor pinned ones ([pinnedChats]): a folder whose chats are all
/// pinned has no group until one is unpinned.
Map<String, List<ChatState>> chatGroups(Daemon daemon) {
  final groups = <String, List<ChatState>>{};
  final byNewest =
      daemon.chats.values.where((c) => !c.archived && c.pin == 0).toList()
        ..sort((a, b) => b.created.compareTo(a.created));
  for (final c in byNewest) {
    (groups[c.scratch ? '' : c.home] ??= []).add(c);
  }
  return groups;
}

/// The Mac sidebar's groups ([chatGroups]) in the order they were dragged
/// into ([sidebarOrder]); a folder it doesn't name goes first, as one
/// with the newest chat, and with [starting] (the folder a chat is
/// starting in) that folder goes first too, as it will once its new chat
/// is there, with chats or not yet. In each, the
/// chats in the order they were dragged into ([sidebarChats]), a chat it
/// doesn't name (a new one) first, the newest first. Those of [without]
/// (in a section) are left out, and a folder left with none with them.
/// The phone keeps [chatGroups]' order.
Map<String, List<ChatState>> sidebarGroups(
  Daemon daemon, {
  String? starting,
  Set<String> without = const {},
}) {
  final byFolder = {
    for (final MapEntry(:key, :value) in chatGroups(daemon).entries)
      if (value.where((c) => !without.contains(c.id)).toList() case final chats
          when chats.isNotEmpty)
        key: chats,
  };
  final groups = {?starting: byFolder[starting] ?? <ChatState>[], ...byFolder};
  final saved = sidebarOrder.value;
  final placed = saved.toSet();
  return {
    for (final MapEntry(:key, :value) in groups.entries)
      if (!placed.contains(key)) key: inSavedOrder(key, value),
    for (final k in saved)
      if (groups[k] case final chats?) k: inSavedOrder(k, chats),
  };
}

/// [chats] (the group of [folder], the newest first) in the order they
/// were dragged into ([sidebarChats]), those it doesn't name first.
List<ChatState> inSavedOrder(String folder, List<ChatState> chats) {
  final saved = sidebarChats.value[folder];
  if (saved == null) return chats;
  final at = {for (final (i, id) in saved.indexed) id: i};
  return [
    ...chats.where((c) => !at.containsKey(c.id)),
    ...chats.where((c) => at.containsKey(c.id)).toList()
      ..sort((a, b) => at[a.id]!.compareTo(at[b.id]!)),
  ];
}

/// Those of [chats] (the group of [folder]) the sidebar shows: all, or
/// with the group collapsed ([sidebarCollapsed]), only the selected one,
/// if it's one of them.
Iterable<ChatState> shownChats(
  String folder,
  List<ChatState> chats,
  String? selectedId,
) => sidebarCollapsed.value.contains(folder)
    ? chats.where((c) => c.id == selectedId)
    : chats;

/// The pinned chats the sidebar shows: all, or with Pinned collapsed
/// ([pinnedCollapsed]), only the selected one, if it's pinned.
Iterable<ChatState> shownPinned(Daemon daemon) {
  final pinned = pinnedChats(daemon);
  return pinnedCollapsed.value
      ? pinned.where((c) => c.id == daemon.selectedId)
      : pinned;
}

/// The sidebar as it's arranged ([arrangeSidebar]): Pinned, the sections
/// of the user's own, then under Project grouping each folder's chats
/// ([projects]), else the grouping's groups ([groups]).
class SidebarView {
  const new({
    required this.pinned,
    required this.sections,
    required this.projects,
    required this.groups,
  });

  final List<ChatState> pinned;
  final List<(Section, List<ChatState>)> sections;
  final Map<String, List<ChatState>> projects;
  final List<ChatGroup> groups;
}

/// The sidebar's chats arranged as its Arrange menu says
/// (`arrangement.dart`): the pinned ones on top whatever the grouping;
/// then each section's chats, unarchived and unpinned (a chat in two goes
/// in the first), in the order moved in under Manual, else sorted; then
/// the others, each folder's as [sidebarGroups] has them (sorted, unless
/// Manual) under Project grouping, else in the grouping's groups.
/// [starting], the folder a chat is starting in.
SidebarView arrangeSidebar(Daemon daemon, {String? starting}) {
  final group = sidebarGroupBy.value;
  final sort = effectiveSort(group, sidebarSort.value);
  final up = sidebarAscending.value;
  final live = {
    for (final c in daemon.chats.values)
      if (!c.archived && c.pin == 0) c.id: c,
  };
  final placed = <String>{};
  final sections = [
    for (final s in sidebarSections.value)
      (
        s,
        sortChats(
          [
            for (final id in s.chats)
              if (live[id] case final c? when placed.add(id)) c,
          ],
          sort,
          ascending: up,
        ),
      ),
  ];
  final projects = group == GroupBy.project
      ? {
          for (final MapEntry(:key, :value) in sidebarGroups(
            daemon,
            starting: starting,
            without: placed,
          ).entries)
            key: sortChats(value, sort, ascending: up),
        }
      : <String, List<ChatState>>{};
  final pinned = pinnedChats(daemon);
  final groups = group == GroupBy.project
      ? const <ChatGroup>[]
      : groupChats(
          live.values.where((c) => !placed.contains(c.id)),
          group,
          sort,
          ascending: up,
          now: clock(),
        );
  return SidebarView(
    pinned: pinned,
    sections: sections,
    projects: projects,
    // None's one list is headed "Chats" under Pinned or a section, so its
    // rows don't read as theirs.
    groups: [
      for (final g in groups)
        if (g.label.isEmpty && (pinned.isNotEmpty || sections.isNotEmpty))
          ChatGroup(g.key, 'Chats', g.chats)
        else
          g,
    ],
  );
}

/// The chats as the sidebar shows them, top to bottom, Pinned first, then
/// the sections and the groups, the archived (in their collapsed group)
/// and those of collapsed sections and groups left out but the selected
/// one: what ⌘1–⌘9, ⌘[ and ⌘] go through.
List<ChatState> chatOrder(Daemon daemon) {
  final view = arrangeSidebar(daemon);
  final selected = daemon.selectedId;
  return [
    ...shownPinned(daemon),
    for (final (section, chats) in view.sections)
      ...section.collapsed ? chats.where((c) => c.id == selected) : chats,
    for (final MapEntry(key: folder, value: chats) in view.projects.entries)
      ...shownChats(folder, chats, selected),
    for (final g in view.groups) ...shownChats(g.key, g.chats, selected),
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
/// screenshot, so not ⌘⇧).
const chatTabKey = SingleActivator(
  LogicalKeyboardKey.digit1,
  control: true,
  meta: true,
);
const changesTabKey = SingleActivator(
  LogicalKeyboardKey.digit2,
  control: true,
  meta: true,
);
const pullTabKey = SingleActivator(
  LogicalKeyboardKey.digit3,
  control: true,
  meta: true,
);

/// ⌘W: closes the preview tab showing, and with the last the pane. A focused
/// terminal keeps it, to close itself.
const closeTabKey = SingleActivator(LogicalKeyboardKey.keyW, meta: true);

SingleActivator tabKey(ChatTab tab) => switch (tab) {
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

/// ⌘1–⌘9, ⌘[ and ⌘] that switch chats, ⌃Tab and ⌃⇧Tab that switch its
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
