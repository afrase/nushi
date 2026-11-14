import 'package:flutter/foundation.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/settings.dart';

// The sidebar's chats as it shows them: its groups, its sections and
// Pinned, arranged as the Arrange menu says (`arrangement.dart`).

/// The pinned chats, top first (`Chat.pin`, kept by the daemon); archived
/// chats are never pinned.
List<ChatState> pinnedChats(Daemon daemon) =>
    daemon.chats.values.where((c) => c.pin > 0 && !c.archived).toList()
      ..sort((a, b) => a.pin.compareTo(b.pin));

/// Whether the sidebar is wide enough for its project rail: the sidebar
/// says so as it's laid out (`ProjectRail.minSidebar`).
final ValueNotifier<bool> railFits = runValue(true);

/// Whether the sidebar would have its project rail, room allowing:
/// arranged by project and Settings › Appearance's Project rail on (off
/// at first). The sidebar is then kept wide enough for it, as far as the
/// window has room.
bool get railWanted =>
    sidebarGroupBy.value == GroupBy.project && projectRail.value;

/// Whether the sidebar has its project rail (ADR 0112): wanted
/// ([railWanted]) and room for it.
bool get railShows => railWanted && railFits.value;

/// The project the sidebar is narrowed to, by folder: the tile picked in
/// the rail ([sidebarProject]), while the rail shows and the folder is
/// still one of the sidebar's projects; null for all of them.
String? get shownProject => switch (sidebarProject.value) {
  final p? when railShows && sidebarProjects.value.contains(p) => p,
  _ => null,
};

/// Whether [c] is of the project the sidebar is narrowed to
/// ([shownProject]), or it shows them all.
bool inShownProject(ChatState c) => switch (shownProject) {
  null => true,
  final p => !c.scratch && c.home == p,
};

/// The sidebar's groups: each folder's chats (a chat in a worktree under
/// its repository; scratch chats under ''), the folder with the newest
/// chat first, the newest chat first in each. Archived chats aren't in
/// it, nor pinned ones ([pinnedChats]): a folder whose chats are all
/// pinned has no group here until one is unpinned ([sidebarGroups] keeps
/// it, empty).
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

/// The folders that have a chat that isn't archived, pinned and sectioned
/// ones too (a worktree's under its repository; not scratch folders): a
/// project the sidebar can't forget (Remove from sidebar).
Set<String> liveFolders(Daemon daemon) => {
  for (final c in daemon.chats.values)
    if (!c.archived && !c.scratch) c.home,
};

/// The Mac sidebar's groups ([chatGroups]) in the order they were dragged
/// into ([sidebarOrder]); a folder it doesn't name goes first, as one
/// with the newest chat, and with [starting] (the folder a chat is
/// starting in) that folder goes first too, as it will once its new chat
/// is there, with chats or not yet. In each, the
/// chats in the order they were dragged into ([sidebarChats]), a chat it
/// doesn't name (a new one) first, the newest first. Those of [without]
/// (in a section) are left out. A project kept ([sidebarProjects]) with
/// no chats to show (all archived, deleted, pinned or in a section) is an
/// empty group, its header alone or over "No chats" ([liveFolders]):
/// where it was dragged to, else after the others, in the order they
/// joined. The phone keeps [chatGroups]' order, and no empty
/// group.
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
  final empty = sidebarProjects.value.difference(groups.keys.toSet());
  final saved = sidebarOrder.value;
  final placed = saved.toSet();
  return {
    for (final MapEntry(:key, :value) in groups.entries)
      if (!placed.contains(key)) key: inSavedOrder(key, value),
    for (final k in saved)
      if (groups[k] case final chats?)
        k: inSavedOrder(k, chats)
      else if (empty.contains(k))
        k: [],
    for (final f in empty)
      if (!placed.contains(f)) f: [],
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

/// The pinned chats the sidebar shows: those of the project it's
/// narrowed to ([inShownProject]), or with Pinned collapsed
/// ([pinnedCollapsed]), only the selected one, if it's one of them.
Iterable<ChatState> shownPinned(Daemon daemon) {
  final pinned = pinnedChats(daemon).where(inShownProject);
  return pinnedCollapsed.value
      ? pinned.where((c) => c.id == daemon.selectedId)
      : pinned;
}

/// The sidebar as it's arranged ([arrangeSidebar]): Pinned, the sections
/// of the user's own, then under Project grouping each folder's chats
/// ([projects]), else the grouping's groups ([groups]). [folders] are
/// the projects, in the sidebar's order, whichever it's narrowed to: the
/// project rail's tiles.
class SidebarView {
  const new({
    required this.pinned,
    required this.sections,
    required this.projects,
    required this.groups,
    this.folders = const [],
  });

  final List<ChatState> pinned;
  final List<(Section, List<ChatState>)> sections;
  final Map<String, List<ChatState>> projects;
  final List<ChatGroup> groups;
  final List<String> folders;
}

/// How [folder]'s chats sort under Project grouping: its own sort
/// ([projectSorts], ADR 0118), else the sidebar's.
({SortBy sort, bool ascending}) projectSort(String folder) =>
    switch (projectSorts.value[folder]) {
      final own? => (sort: own.sort, ascending: own.ascending),
      null => (sort: sidebarSort.value, ascending: sidebarAscending.value),
    };

/// The sidebar's chats arranged as its Arrange menu says
/// (`arrangement.dart`): the pinned ones on top whatever the grouping;
/// then each section's chats, unarchived and unpinned (a chat in two goes
/// in the first), in the order moved in under Manual, else sorted; then
/// the others, each folder's as [sidebarGroups] has them (sorted by its
/// own sort or the sidebar's, [projectSort], unless Manual; a kept project
/// with none of them an empty group) under Project grouping, else in the
/// grouping's groups.
/// [starting], the folder a chat is starting in.
///
/// Narrowed to a project ([shownProject]: its tile picked in the project
/// rail), it's that project's chats only: its pinned ones, the sections
/// that have a chat of it with those chats, and its own group. The
/// sections with none of it and the chats with no folder are left out.
SidebarView arrangeSidebar(Daemon daemon, {String? starting}) {
  final group = sidebarGroupBy.value;
  final sort = effectiveSort(group, sidebarSort.value);
  final up = sidebarAscending.value;
  final only = shownProject;
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
              if (live[id] case final c? when placed.add(id))
                if (inShownProject(c)) c,
          ],
          sort,
          ascending: up,
        ),
      ),
  ].where((s) => only == null || s.$2.isNotEmpty).toList();
  final all = group == GroupBy.project
      ? {
          for (final MapEntry(:key, :value) in sidebarGroups(
            daemon,
            starting: starting,
            without: placed,
          ).entries)
            key: switch (projectSort(key)) {
              (:final sort, :final ascending) => sortChats(
                value,
                sort,
                ascending: ascending,
              ),
            },
        }
      : <String, List<ChatState>>{};
  final projects = only == null ? all : {only: all[only] ?? <ChatState>[]};
  final pinned = pinnedChats(daemon).where(inShownProject).toList();
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
    folders: [...all.keys.where((f) => f.isNotEmpty)],
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
