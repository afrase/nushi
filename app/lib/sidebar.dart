import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_arrange.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/sidebar_grouped.dart';
import 'package:nushi/sidebar_groups.dart';
import 'package:nushi/sidebar_row.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The chats: the pinned ones first ([PinnedSection]), then the sections
/// of the user's own ([SidebarSections]), then at first grouped by folder
/// (a chat in a worktree under its repository; [SidebarGroups]): the
/// groups in the order they were dragged into, a new folder's first, and
/// in each the chats as they were dragged, a new one first. Its header's
/// [ArrangeButton] groups them otherwise ([GroupedChats]), sorts them and
/// picks what rows show ([arrangeSidebar]). Archived chats are in a
/// collapsed group at the bottom. While ⌘ is held
/// alone, the first nine chats shown (archived left out) show the number
/// ⌘ opens them with. Its header's [SidebarButton] hides it ([sidebarHidden]);
/// `main.dart` then doesn't build it, so it asks nothing while it's hidden.
class Sidebar extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _showArchived = false;
  final _hold = CommandHold();

  /// The rows of its lists, so one that moves between them glides.
  final _motion = ListMotion();

  /// Whether the pointer is over it, which shows its Arrange button.
  final _hover = ValueNotifier<bool>(false);

  /// The chats' pull requests' checks, for their rows' dots, asked while
  /// the list shows.
  late final PullStates _pulls;

  /// Counts the minutes while the list reads the clock (its rows' ages,
  /// the Date groups), so an idle app's ages go on and a chat leaves Today
  /// at midnight; nothing else would build it again.
  final _minute = ValueNotifier<int>(0);
  Timer? _ticks;

  @override
  void initState() {
    super.initState();
    _pulls = PullStates.of(widget.daemon)..watch();
    sidebarShows.addListener(_tick);
    sidebarGroupBy.addListener(_tick);
    _tick();
  }

  @override
  void dispose() {
    sidebarShows.removeListener(_tick);
    sidebarGroupBy.removeListener(_tick);
    _ticks?.cancel();
    _minute.dispose();
    _hold.dispose();
    _hover.dispose();
    _pulls.unwatch();
    super.dispose();
  }

  /// Starts or ends [_minute]'s count, as the list reads the clock or not.
  void _tick() {
    final reads =
        sidebarShows.value.contains(RowPart.time) ||
        sidebarGroupBy.value == GroupBy.date;
    if (!reads) {
      _ticks?.cancel();
      _ticks = null;
    } else {
      _ticks ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => _minute.value++,
      );
    }
  }

  void _new(String folder) => newChat(context, widget.daemon, folder);

  /// Opens a terminal in [folder] for the chat shown, if it's one of
  /// [chats], else for the newest of them, which it shows.
  Future<void> _terminal(String folder, List<ChatState> chats) async {
    final daemon = widget.daemon;
    final chat = chats.contains(daemon.selected)
        ? daemon.selected!
        : chats.first;
    daemon.select(chat.id);
    await tryOrShow(context, () => openTerminalIn(daemon, chat, folder));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final daemon = widget.daemon;
    final archived = daemon.chats.values.where((c) => c.archived).toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final starting = daemon.starting;
    return MouseRegion(
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.raised),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Under the traffic lights, its hairline the chat header's. Its
            // empty space moves the window; the buttons keep their clicks.
            PaneHeader(
              end: 10,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArrangeButton(daemon: daemon, hover: _hover),
                    const SizedBox(width: 2),
                    const SidebarButton(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Button(
                label: 'New chat',
                icon: Icons.add,
                hint: '⌘N',
                onPressed: starting == null ? () => _new('') : null,
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: sidebarGroupBy,
                builder: (context, group, _) => ListenableBuilder(
                  listenable: Listenable.merge([
                    _hold,
                    sidebarOrder,
                    sidebarCollapsed,
                    sidebarChats,
                    pinnedCollapsed,
                    sidebarSort,
                    sidebarAscending,
                    sidebarShows,
                    sidebarSections,
                    _minute,
                    // Grouped by state, a chat regroups as its state
                    // changes, not at each streamed chunk.
                    if (group == GroupBy.status)
                      for (final c in daemon.chats.values) c.look,
                  ]),
                  builder: (context, _) => _list(context, archived),
                ),
              ),
            ),
            _Footer(daemon),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<ChatState> archived) {
    final t = NushiTheme.of(context).t;
    final daemon = widget.daemon;
    final starting = daemon.starting;
    final held = _hold.value;
    final group = sidebarGroupBy.value;
    final sort = effectiveSort(group, sidebarSort.value);
    final reorders = dragsOrder(group, sidebarSort.value);
    final shows = sidebarShows.value;
    final view = arrangeSidebar(daemon, starting: starting);
    // Where each row is before the lists change, and what they show now:
    // a row one loses and another shows moved.
    _motion
      ..ground = t.raised
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
        if (_showArchived)
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
      motion: _motion,
      child: ListView(
        // Hiding the sidebar takes it away: back where it was.
        key: const PageStorageKey('sidebar'),
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          Column(
            key: _motion.space,
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
                        onNew: starting == null ? _new : null,
                        onTerminal: _terminal,
                        reorders: reorders,
                        row: (c, movable) => row(c, movable, inProject: true),
                      )
                    : GroupedChats(
                        groups: view.groups,
                        selectedId: daemon.selectedId,
                        row: row,
                      ),
              ),
              ArchivedSection(
                archived,
                open: _showArchived,
                onToggle: () => setState(() => _showArchived = !_showArchived),
                row: (c) => SidebarRow(c, key: ValueKey(c.id), daemon: daemon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The footer: the views in the chat's place, Jira and GitHub (each again
/// closes it), and Settings, which opens over the window (ADR 0087). MCP
/// servers and Skills are Settings' sections, reached there, from a chat's
/// ⋯ and from the palette.
class _Footer extends StatelessWidget {
  const new(this.daemon);

  final Daemon daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget row(
      String label,
      IconData icon,
      VoidCallback onTap, {
      required bool open,
    }) => Tap(
      selected: open,
      fill: open ? t.accentSoft : null, // as the open chat's row
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: t.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: theme.ui(t.textSecondary, size: 12)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'Jira',
            Icons.task_alt,
            open: daemon.place is JiraPlace,
            () => daemon.toggle(const JiraPlace()),
          ),
          row(
            'GitHub',
            Icons.merge_type,
            open: daemon.place is GitHubPlace,
            () => daemon.toggle(const GitHubPlace()),
          ),
          // Settings opens over the window, never a place (ADR 0087).
          row(
            'Settings',
            Icons.settings_outlined,
            open: false,
            daemon.openSettings,
          ),
        ],
      ),
    );
  }
}
