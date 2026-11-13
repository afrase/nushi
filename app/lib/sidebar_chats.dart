import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/project_tile_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_grouped.dart';
import 'package:nushi/sidebar_groups.dart';
import 'package:nushi/sidebar_row.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/theme/theme.dart';

/// The sidebar's list of chats, as arranged ([view]): Pinned, the
/// sections, the projects' groups or the grouping's, and the archived,
/// in one scroll. A row that moves between them glides ([motion]). While
/// ⌘ is [held], the first nine rows show the number it opens them with.
/// A project's header has its tile, in its place among [colors].
class SidebarChats extends StatelessWidget {
  const new({
    required this.daemon,
    required this.view,
    required this.colors,
    required this.motion,
    required this.held,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onNew,
    required this.onTerminal,
    super.key,
  });

  final Daemon daemon;
  final SidebarView view;
  final Map<String, int> colors;
  final ListMotion motion;
  final bool held;
  final bool showArchived;
  final VoidCallback onToggleArchived;

  /// A new chat in a folder; null while one starts.
  final void Function(String folder)? onNew;

  /// A terminal in a folder, in one of its group's chats.
  final void Function(String folder, List<ChatState> chats) onTerminal;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final starting = daemon.starting;
    // Narrowed to a project, the archived are that project's too.
    final archived =
        daemon.chats.values
            .where((c) => c.archived && inShownProject(c))
            .toList()
          ..sort((a, b) => b.created.compareTo(a.created));
    final group = sidebarGroupBy.value;
    final sort = effectiveSort(group, sidebarSort.value);
    final reorders = dragsOrder(group, sidebarSort.value);
    final shows = sidebarShows.value;
    // Where each row is before the lists change, and what they show now:
    // a row one loses and another shows moved.
    motion
      ..ground = t.window
      ..shown = {
        for (final c in view.pinned) ValueKey(c.id),
        for (final (section, chats) in view.sections) ...[
          ValueKey(section.key),
          for (final c in chats) ValueKey(c.id),
        ],
        for (final MapEntry(:key, :value) in view.projects.entries) ...[
          ValueKey(key),
          for (final c in value) ValueKey(c.id),
        ],
        for (final g in view.groups) ...[
          ValueKey(g.key),
          for (final c in g.chats) ValueKey(c.id),
        ],
        if (showArchived)
          for (final c in archived) ValueKey(c.id),
      }
      ..snapshot();
    final numbers = {
      for (final (i, c) in chatOrder(daemon).take(9).indexed) c.id: i + 1,
    };
    // A row says its project where its group doesn't.
    Widget row(ChatState c, Movable movable, {bool inProject = false}) =>
        SidebarRow(
          c,
          key: ValueKey(c.id),
          daemon: daemon,
          number: held ? numbers[c.id] : null,
          movable: movable,
          project: !inProject && shows.contains(RowPart.project),
          time: shows.contains(RowPart.time) ? chatTime(c, sort) : null,
        );
    return ListMotionScope(
      motion: motion,
      child: ListView(
        // Hiding the sidebar takes it away: back where it was.
        key: const PageStorageKey('sidebar'),
        padding: const EdgeInsets.only(bottom: 14),
        children: [
          Column(
            key: motion.space,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PinnedSection(daemon, row: row),
              SidebarSections(
                daemon: daemon,
                sections: view.sections,
                reorders: reorders,
                row: row,
              ),
              LeaveSectionTarget(
                child: group == GroupBy.project
                    ? SidebarGroups(
                        groups: view.projects,
                        selectedId: daemon.selectedId,
                        starting: starting,
                        startingAgent: daemon.startingAgent,
                        live: liveFolders(daemon),
                        onNew: onNew,
                        onTerminal: onTerminal,
                        reorders: reorders,
                        row: (c, movable) => row(c, movable, inProject: true),
                        tile: (folder) => FolderTile(
                          daemon: daemon,
                          folder: folder,
                          color: colors[folder] ?? 0,
                          size: ProjectTile.small,
                        ),
                        onChangeTile: (folder) => changeTile(
                          context,
                          daemon,
                          folder,
                          color: colors[folder] ?? 0,
                        ),
                      )
                    : GroupedChats(
                        groups: view.groups,
                        selectedId: daemon.selectedId,
                        row: row,
                      ),
              ),
              ArchivedSection(
                archived,
                open: showArchived,
                onToggle: onToggleArchived,
                row: (c) => SidebarRow(c, key: ValueKey(c.id), daemon: daemon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
