import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/theme/theme.dart';

// A project's own sort (ADR 0118), from the Sort button on its header, as
// Claude desktop has a Group and sort button on each project's: how that
// project's chats are sorted and which way. Grouping stays the sidebar's
// (it makes the headers), as does what rows show (one look down the list).

/// [folder]'s Sort menu: the sorts, the project's checked, its two ways
/// while it isn't Manual, and the sidebar's sort to go back to.
List<MenuEntry> projectSortEntries(String folder) {
  final own = projectSorts.value[folder];
  final (:sort, :ascending) = projectSort(folder);
  void set(ProjectSort? to) {
    final sorts = {...projectSorts.value}..remove(folder);
    projectSorts.value = {...sorts, folder: ?to};
  }

  final (down, rise) = sort.ways;
  final shared = sidebarSort.value;
  return [
    for (final s in SortBy.values)
      MenuEntry(
        s.label,
        checked: s == sort,
        onPick: () => set(ProjectSort(s, ascending: s.naturallyAscending)),
      ),
    if (sort != SortBy.manual) ...[
      MenuEntry.divider,
      MenuEntry(
        down,
        checked: !ascending,
        onPick: () => set(ProjectSort(sort)),
      ),
      MenuEntry(
        rise,
        checked: ascending,
        onPick: () => set(ProjectSort(sort, ascending: true)),
      ),
    ],
    MenuEntry.divider,
    MenuEntry(
      'Sidebar’s sort',
      detail: shared.label,
      checked: own == null,
      onPick: own == null ? null : () => set(null),
    ),
    MenuEntry.heading(
      sort == SortBy.manual
          ? 'Drag chats to put them in order'
          : 'The sort sets the order',
    ),
  ];
}

/// The Sort button on a project's header: [LineIcon.sort], opening
/// [projectSortEntries]. It shows while the header is under the pointer or
/// has the focus ([shown]) or its menu is open, and always, in the accent,
/// while the project sorts its own way, so a list sorted otherwise than
/// the rest says so.
class ProjectSortButton extends StatefulWidget {
  const new(this.folder, {required this.shown, super.key});

  final String folder;
  final bool shown;

  @override
  State<ProjectSortButton> createState() => _ProjectSortButtonState();
}

class _ProjectSortButtonState extends State<ProjectSortButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: Listenable.merge([projectSorts, sidebarSort]),
      builder: (context, _) {
        final own = projectSorts.value[widget.folder];
        return Opacity(
          opacity: own != null || _open || widget.shown ? 1 : 0,
          child: Menu(
            filter: false,
            entries: projectSortEntries(widget.folder),
            onOpen: () => setState(() => _open = true),
            onClose: () {
              if (mounted) setState(() => _open = false);
            },
            builder: (context, open) => IconTap.line(
              LineIcon.sort,
              tooltip: own == null
                  ? 'Sort this project'
                  : 'Sort this project (${own.sort.label})',
              size: 14,
              color: own == null ? null : t.accentInk,
              onTap: open,
            ),
          ),
        );
      },
    );
  }
}
