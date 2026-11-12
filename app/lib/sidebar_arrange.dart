import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// The sidebar's Arrange menu, as Claude Code's desktop app has one at its
// sidebar's top: Group by, Sort by, Show, New section, Reset to defaults
// and View all (`arrangement.dart` has the choices).

/// Whether the sidebar is arranged as it is at first: grouped by Project,
/// sorted by hand, its rows showing what they show at first. Sections
/// aren't counted: they're the user's chats' places, not a view of them.
bool get arrangedAsDefault =>
    sidebarGroupBy.value == GroupBy.project &&
    sidebarSort.value == SortBy.manual &&
    setEquals(sidebarShows.value, defaultRowParts);

/// Puts the grouping, the sort and what rows show back as at first; the
/// sections stay.
void resetArrangement() {
  sidebarGroupBy.value = GroupBy.project;
  sidebarSort.value = SortBy.manual;
  sidebarAscending.value = false;
  sidebarShows.value = defaultRowParts;
}

/// The menu's rows: Group by, Sort by and Show, each a submenu with the
/// choice made on its right; Project rail, checked while the sidebar has
/// it ([projectRail]); New section; Reset to defaults (while it's
/// arranged otherwise); View all (Chat history, every chat and session).
List<MenuEntry> arrangeEntries(BuildContext context, Daemon daemon) {
  final group = sidebarGroupBy.value;
  final sort = effectiveSort(group, sidebarSort.value);
  final up = sidebarAscending.value;
  final shows = sidebarShows.value;
  final (down, rise) = sort.ways;
  return [
    MenuEntry(
      'Group by',
      detail: group.label,
      submenu: [
        for (final g in GroupBy.values)
          MenuEntry(
            g.label,
            checked: g == group,
            onPick: () => sidebarGroupBy.value = g,
          ),
      ],
    ),
    MenuEntry(
      'Sort by',
      detail: sort.label,
      submenu: [
        for (final s in SortBy.values)
          MenuEntry(
            s.label,
            checked: s == sort,
            // By hand only where the order is the user's: projects.
            detail: s == SortBy.manual && group != GroupBy.project
                ? 'by Project only'
                : '',
            onPick: s == SortBy.manual && group != GroupBy.project
                ? null
                : () {
                    sidebarSort.value = s;
                    sidebarAscending.value = s.naturallyAscending;
                  },
          ),
        if (sort != SortBy.manual) ...[
          MenuEntry.divider,
          MenuEntry(
            down,
            checked: !up,
            onPick: () => sidebarAscending.value = false,
          ),
          MenuEntry(
            rise,
            checked: up,
            onPick: () => sidebarAscending.value = true,
          ),
        ],
        MenuEntry.divider,
        MenuEntry.heading(
          dragsOrder(group, sort)
              ? 'Drag chats to put them in order'
              : 'The sort sets the order; drag a chat into a section',
        ),
      ],
    ),
    MenuEntry(
      'Show',
      submenu: [
        for (final p in RowPart.values)
          MenuEntry(
            p.label,
            checked: shows.contains(p),
            onPick: () => sidebarShows.toggle(p),
          ),
      ],
    ),
    MenuEntry(
      'Project rail',
      checked: projectRail.value && group == GroupBy.project,
      // The rail is the projects': there's none under another grouping.
      tooltip: group == GroupBy.project ? '' : 'Only when grouped by Project',
      onPick: group == GroupBy.project
          ? () => projectRail.value = !projectRail.value
          : null,
    ),
    MenuEntry.divider,
    MenuEntry(
      'New section',
      icon: Icons.create_new_folder_outlined,
      onPick: () => newSection(context, daemon),
    ),
    MenuEntry.divider,
    MenuEntry(
      'Reset to defaults',
      onPick: arrangedAsDefault ? null : resetArrangement,
    ),
    MenuEntry(
      'View all',
      detail: 'Chat history',
      onPick: () => daemon.openSettings(section: SettingsSection.history),
    ),
  ];
}

/// The Arrange button, beside the sidebar's own at its top: [LineIcon.arrange]
/// opening [arrangeEntries], with a dot in the accent while the sidebar is
/// arranged otherwise than at first. It shows while the pointer is over
/// the sidebar ([hover]), while it has the focus or its menu is open, and
/// always while that dot shows; else its room is kept, empty, so the
/// sidebar at first looks as it did before it had one.
class ArrangeButton extends StatefulWidget {
  const new({required this.daemon, required this.hover, super.key});

  final Daemon daemon;
  final ValueListenable<bool> hover;

  @override
  State<ArrangeButton> createState() => _ArrangeButtonState();
}

class _ArrangeButtonState extends State<ArrangeButton> {
  bool _focus = false;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.hover,
        sidebarGroupBy,
        sidebarSort,
        sidebarAscending,
        sidebarShows,
        sidebarSections,
      ]),
      builder: (context, _) {
        final marked = !arrangedAsDefault;
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) => setState(() => _focus = f),
          child: Opacity(
            opacity: marked || _open || _focus || widget.hover.value ? 1 : 0,
            child: Menu(
              filter: false,
              entries: arrangeEntries(context, widget.daemon),
              onOpen: () => setState(() => _open = true),
              onClose: () {
                if (mounted) setState(() => _open = false);
              },
              builder: (context, open) => Stack(
                clipBehavior: Clip.none,
                children: [
                  IconTap.line(
                    LineIcon.arrange,
                    tooltip: marked
                        ? 'Arrange the sidebar (arranged your way)'
                        : 'Arrange the sidebar',
                    // As the button beside it, and a header's.
                    padding: IconTap.header,
                    onTap: open,
                  ),
                  if (marked)
                    Positioned(
                      right: IconTap.header - 3,
                      top: IconTap.header - 3,
                      child: IgnorePointer(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                            // A ring of what the sidebar lies on, around it.
                            border: Border.all(color: t.window),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
