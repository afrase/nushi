import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/project_tile_dialog.dart';
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_arrange.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/sidebar_chats.dart';
import 'package:nushi/sidebar_grouped.dart';
import 'package:nushi/sidebar_groups.dart';
import 'package:nushi/sidebar_links.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/sidebar_sections.dart';
import 'package:nushi/sidebar_view.dart';
import 'package:nushi/status_bar.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/window_drag.dart';

/// The chats: the pinned ones first ([PinnedSection]), then the sections
/// of the user's own ([SidebarSections]), then at first grouped by folder
/// (a chat in a worktree under its repository; [SidebarGroups]): the
/// groups in the order they were dragged into, a new folder's first, and
/// in each the chats as they were dragged, a new one first. Its header's
/// [ArrangeButton] groups them otherwise ([GroupedChats]), sorts them and
/// picks what rows show ([arrangeSidebar]). Archived chats are in a
/// collapsed group at the bottom. Arranged by project, it has the project
/// rail at its left ([ProjectRail], ADR 0112; while it's wide enough for
/// one and Settings' Project rail is on; off at first), whose tiles
/// narrow all of these to one project's chats. While ⌘ is held
/// alone, the first nine chats shown (archived left out) show the number
/// ⌘ opens them with. [SidebarButton] hides it ([sidebarHidden]);
/// `main.dart` then doesn't build it, so it asks nothing while it's hidden.
///
/// It sits on the window's own background, with no pane and no border
/// (ADR 0111): the strip under the traffic lights and the title buttons,
/// New chat as a card-filled button, the chats, the views' links, and at
/// its foot the agents' counts and the memory as a card ([StatusBar]).
/// Its own fill is the window's, so it covers the main pane it slides
/// over as it goes.
class Sidebar extends StatefulWidget {
  const new({required this.daemon, super.key, this.floating = false});

  final Daemon daemon;

  /// Whether it floats over the main pane as it peeks (`SidebarBeside`,
  /// ADR 0116): its card is already in from the window's top by the
  /// window's margin, so its strip is that much shorter, its buttons
  /// where they are when it shows.
  final bool floating;

  /// The strip at its top, which holds Arrange at its right and has the
  /// title buttons drawn over its left ([TitleButtons], ADR 0116). On the
  /// Mac the traffic lights sit in it too, level with the middle of the
  /// main pane's header (`macos/Runner/TitleBar.swift`'s WindowButtons).
  /// The strip ends where that header does, so its buttons are level with
  /// the header's, on Linux too, where the title buttons stay put as on
  /// the Mac.
  static const double topHeight = NushiTheme.windowPad + PaneHeader.height;

  /// The room over New chat: the strip's foot is already the header's
  /// line.
  static const double topGap = 0;

  /// The narrowest it's dragged to: room in its top strip for the title
  /// buttons and Arrange beside them, past the Mac's traffic lights.
  static double get minWidth => max(
    200,
    TitleButtons.right +
        WindowDrag.near +
        IconTap.header * 2 +
        16 +
        end -
        SidebarButton.reach,
  );

  /// How far its rows and cards are in from its left edge, the window's,
  /// and from its right edge, where the main pane starts: the window's
  /// margin and the panes' gap, a little more at the left as the rows have
  /// no edge of their own.
  static const double start = NushiTheme.windowPad + 2;
  static const double end = NushiTheme.paneGap;

  /// How far the project rail is tucked towards the window's edge, and
  /// the chats towards it: its tiles are five in from its own sides,
  /// which with [start] on both would leave them 15 from the edge and
  /// from the chats' rows; tucked, 13.
  static const double railTuck = 2;

  /// What the project rail takes of the sidebar's width, at its left.
  static const double railWidth = start + ProjectRail.width - 2 * railTuck;

  /// A chat's row: its height, the room between rows, and its padding
  /// inside its rounded fill.
  static const rowHeight = 34.0;
  static const rowGap = 2.0;
  static const rowPad = 10.0;

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
    // Shown again after it was hidden: a chat opened or started meanwhile
    // is followed now, as it would have been.
    final seen = _seen[widget.daemon];
    _opened = seen == null ? widget.daemon.selectedId : seen.opened;
    _started = seen == null ? widget.daemon.starting : seen.started;
    if (seen != null) _follow();
    widget.daemon.addListener(_follow);
    sidebarShows.addListener(_tick);
    sidebarGroupBy.addListener(_tick);
    _tick();
  }

  @override
  void dispose() {
    sidebarShows.removeListener(_tick);
    sidebarGroupBy.removeListener(_tick);
    widget.daemon.removeListener(_follow);
    _seen[widget.daemon] = (opened: _opened, started: _started);
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

  /// The chat open and the folder one starts in, as [_follow] last saw
  /// them.
  String? _opened;
  String? _started;

  /// What [_follow] last saw, by daemon, kept while the sidebar is hidden
  /// (it isn't built then), so it follows what changed meanwhile.
  static final _seen = Expando<({String? opened, String? started})>();

  /// Narrowed to a project, the sidebar goes to another's as a chat of
  /// that one opens or starts (from the palette, a notification, New
  /// chat), so the open chat's row is never left out of it; to all of
  /// them for a chat with no folder. A tile picked while a chat is open
  /// stays picked: only a change of chat moves it.
  void _follow() {
    final daemon = widget.daemon;
    final opened = daemon.selectedId;
    final started = daemon.starting;
    if (opened == _opened && started == _started) return;
    final to = switch ((started, daemon.selected)) {
      (final folder?, _) when started != _started => folder,
      (_, final chat?) when opened != _opened && !chat.archived =>
        chat.scratch ? '' : chat.home,
      _ => null,
    };
    _opened = opened;
    _started = started;
    if (to == null || shownProject == null || to == shownProject) return;
    sidebarProject.value = to.isEmpty ? null : to;
  }

  /// Says whether the sidebar, [width] wide, has room for the rail, once
  /// this frame is laid out.
  void _fits(double width) {
    final fits = width >= ProjectRail.minSidebar;
    if (fits == railFits.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => railFits.value = fits);
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
    return MouseRegion(
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: ColoredBox(
        color: t.window,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Around the traffic lights and the title buttons, which are
            // drawn over it (ADR 0111, 0116): Arrange at its right is level
            // with them and with the header's, in the header's band under
            // the window's margin. Its empty space moves the window; the
            // buttons keep their clicks.
            SizedBox(
              height:
                  Sidebar.topHeight -
                  (widget.floating ? NushiTheme.windowPad : 0),
              child: WindowDrag(
                background: const SizedBox.shrink(),
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: widget.floating ? 0 : NushiTheme.windowPad,
                      right: Sidebar.end - SidebarButton.reach,
                      bottom: 1, // as a header's hairline
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ArrangeButton(daemon: daemon, hover: _hover),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  _fits(box.maxWidth);
                  return ValueListenableBuilder(
                    valueListenable: sidebarGroupBy,
                    builder: (context, group, _) => ListenableBuilder(
                      listenable: Listenable.merge([
                        _hold,
                        sidebarOrder,
                        sidebarCollapsed,
                        sidebarChats,
                        sidebarProjects,
                        pinnedCollapsed,
                        sidebarSort,
                        sidebarAscending,
                        projectSorts,
                        sidebarShows,
                        sidebarSections,
                        projectRail,
                        sidebarProject,
                        projectTiles,
                        railFits,
                        _minute,
                        // Grouped by state, a chat regroups as its state
                        // changes, not at each streamed chunk.
                        if (group == GroupBy.status)
                          for (final c in daemon.chats.values) c.look,
                      ]),
                      builder: (context, _) => _body(context),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sidebar.start,
                6,
                Sidebar.end,
                NushiTheme.windowPad,
              ),
              child: StatusBar(daemon),
            ),
          ],
        ),
      ),
    );
  }

  /// Under the top strip, over the status card: the project rail, if it
  /// shows, and beside it New chat, the chats and the views' links.
  Widget _body(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final daemon = widget.daemon;
    final starting = daemon.starting;
    final view = arrangeSidebar(daemon, starting: starting);
    final colors = folderTileColors(view.folders);
    final rail = railShows;
    final live = liveFolders(daemon);
    final chats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Sidebar.start,
            Sidebar.topGap,
            Sidebar.end,
            4,
          ),
          child: WideButton(
            label: 'New chat',
            icon: Icons.add,
            hint: keyLabel(newChatKey),
            onPressed: starting == null ? () => _new('') : null,
          ),
        ),
        // With no line over the links under it (ADR 0111), the list's
        // last rows fade into the window's background rather than stop
        // at a cut.
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SidebarChats(
                  daemon: daemon,
                  view: view,
                  colors: colors,
                  motion: _motion,
                  held: _hold.value,
                  showArchived: _showArchived,
                  onToggleArchived: () =>
                      setState(() => _showArchived = !_showArchived),
                  onNew: starting == null ? _new : null,
                  onTerminal: _terminal,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 12,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [t.window.withValues(alpha: 0), t.window],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SidebarLinks(daemon),
      ],
    );
    // The chats keep their place in the tree with the rail or without,
    // so their rows glide from where they were as it comes and goes.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(left: rail ? Sidebar.railWidth : 0, child: chats),
        // Its first tile level with New chat; its list starts a little
        // higher, for the room that tile's ring takes.
        if (rail)
          Positioned(
            left: Sidebar.start - Sidebar.railTuck,
            top: Sidebar.topGap - ProjectRail.top,
            bottom: 0,
            width: ProjectRail.width,
            child: ProjectRail(
              daemon: daemon,
              folders: view.folders,
              colors: colors,
              shown: shownProject,
              entries: (context, folder) {
                final inFolder = chatGroups(daemon)[folder] ?? const [];
                return projectEntries(
                  folder: folder,
                  onNew: starting == null ? () => _new(folder) : null,
                  onTerminal: inFolder.isEmpty
                      ? null
                      : () => _terminal(folder, inFolder),
                  onRemove: live.contains(folder)
                      ? null
                      : () => forgetProject(folder),
                  onChangeTile: () => changeTile(
                    context,
                    daemon,
                    folder,
                    color: colors[folder] ?? 0,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
