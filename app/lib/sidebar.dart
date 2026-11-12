import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/arrangement.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/list_motion.dart';
import 'package:nushi/new_chat.dart';
import 'package:nushi/panes.dart';
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
/// collapsed group at the bottom. While ⌘ is held
/// alone, the first nine chats shown (archived left out) show the number
/// ⌘ opens them with. Its header's [SidebarButton] hides it ([sidebarHidden]);
/// `main.dart` then doesn't build it, so it asks nothing while it's hidden.
///
/// It sits on the window's own background, with no pane and no border
/// (ADR 0111): the strip under the traffic lights with its two buttons,
/// New chat as a card-filled button, the chats, the views' links, and at
/// its foot the agents' counts and the memory as a card ([StatusBar]).
/// Its own fill is the window's, so it covers the main pane it slides
/// over as it goes.
class Sidebar extends StatefulWidget {
  const new({required this.daemon, super.key});

  final Daemon daemon;

  /// The strip at its top, which holds Arrange and the button that hides
  /// it. On the Mac the traffic lights sit in it, level with the middle of
  /// the main pane's header (`macos/Runner/TitleBar.swift`'s
  /// WindowButtons), so the strip ends where that header does and its
  /// buttons are level with both; elsewhere it's a row of its own.
  static double get topHeight =>
      headersMoveWindow ? NushiTheme.windowPad + PaneHeader.height : 32;

  /// The room over New chat: on the Mac the strip's foot is already the
  /// header's line.
  static double get topGap => headersMoveWindow ? 0 : 8;

  /// How far its rows and cards are in from its left edge, the window's,
  /// and from its right edge, where the main pane starts: the window's
  /// margin and the panes' gap, a little more at the left as the rows have
  /// no edge of their own.
  static const double start = NushiTheme.windowPad + 2;
  static const double end = NushiTheme.paneGap;

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
    final starting = daemon.starting;
    return MouseRegion(
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: ColoredBox(
        color: t.window,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Around the traffic lights (ADR 0111): the strip's buttons
            // are level with them and with the header's, in the header's
            // band under the window's margin. Its empty space moves the
            // window; the buttons keep their clicks.
            SizedBox(
              height: Sidebar.topHeight,
              child: WindowDrag(
                background: const SizedBox.shrink(),
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: headersMoveWindow ? NushiTheme.windowPad : 0,
                      right: Sidebar.end - SidebarButton.reach,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ArrangeButton(daemon: daemon, hover: _hover),
                          const SizedBox(width: NushiTheme.iconGap),
                          const SidebarButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
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
            Expanded(
              child: ValueListenableBuilder(
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
                    sidebarShows,
                    sidebarSections,
                    _minute,
                    // Grouped by state, a chat regroups as its state
                    // changes, not at each streamed chunk.
                    if (group == GroupBy.status)
                      for (final c in daemon.chats.values) c.look,
                  ]),
                  // With no line over the links under it (ADR 0111), the
                  // list's last rows fade into the window's background
                  // rather than stop at a cut.
                  builder: (context, _) => Stack(
                    children: [
                      Positioned.fill(
                        child: SidebarChats(
                          daemon: daemon,
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
                                colors: [
                                  t.window.withValues(alpha: 0),
                                  t.window,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SidebarLinks(daemon),
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
}
