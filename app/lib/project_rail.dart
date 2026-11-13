import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/card_list.dart' show reordered;
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slide_list.dart';
import 'package:nushi/slop_draggable.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Picks the folder Add project… adds. A test puts its own in its place:
/// the system's panel can't be shown in one.
Future<String?> Function() chooseProjectFolder = () =>
    getDirectoryPath(confirmButtonText: 'Add');

/// Add project…, the Arrange menu's and the rail's: adds a folder picked
/// in the system's panel to the sidebar's projects, with no chat; its
/// group's + starts the first.
Future<void> addProject() async {
  final folder = await chooseProjectFolder();
  if (folder != null && folder.isNotEmpty) keepProject(folder);
}

/// The project rail (ADR 0112): a narrow column of tiles at the sidebar's
/// left while it's arranged by project. All projects, a short hairline,
/// a tile for each of [folders] (the sidebar's projects, in its order),
/// then Add project… ([addProject]). It's there only once Settings ›
/// Appearance's Project rail is on ([projectRail]; off at first: the
/// owner, having tried it, liked the tiles in the list, not the rail).
/// A click on a project's tile narrows the sidebar to it
/// ([sidebarProject]); the one picked wears a ring. A
/// tile says its project's name and path in its tooltip, counts the
/// project's chats that need you in a badge, and has the project's menu
/// ([entries]) on a right-click. A project's tile dragged moves the
/// project ([SlideList]), setting the sidebar's own order
/// ([sidebarOrder]), so the list follows; All projects and Add project…
/// never move. It scrolls when the tiles don't fit, and as a drag nears
/// its top or bottom edge.
class ProjectRail extends StatelessWidget {
  const new({
    required this.daemon,
    required this.folders,
    required this.colors,
    required this.shown,
    required this.entries,
    super.key,
  });

  /// Its width, a tile and five on each side, and the room between tiles.
  static const width = 48.0;
  static const gap = 8.0;

  /// The room over its first tile, for the ring around it.
  static const top = 4.0;

  /// The narrowest sidebar that has it: under this its chats' rows would
  /// be left with too little.
  static const minSidebar = 250.0;

  final Daemon daemon;
  final List<String> folders;

  /// Each folder's place in the tiles' colors (`folderTileColors`).
  final Map<String, int> colors;

  /// The project the sidebar is narrowed to; null for all.
  final String? shown;

  /// A project's menu, the same as its group's header's.
  final List<MenuEntry> Function(BuildContext context, String folder) entries;

  /// How many of [folder]'s chats need the user: those waiting on an
  /// answer, pinned or in a section too, archived ones aside.
  int _needs(String folder) => daemon.chats.values
      .where((c) => !c.archived && !c.scratch && c.home == folder && c.waiting)
      .length;

  /// [folder]'s tile: a click narrows the sidebar to it, a right-click
  /// opens its menu, and a drag past [dragSlop] moves it, a copy of the
  /// tile lifted under the pointer as the sidebar's header's is.
  Widget _project(BuildContext context, String folder, ItemDrag<_Moving> drag) {
    final t = NushiTheme.of(context).t;
    Widget tile() =>
        FolderTile(daemon: daemon, folder: folder, color: colors[folder] ?? 0);
    return Menu(
      filter: false,
      entries: entries(context, folder),
      builder: (context, open) => drag.draggable(
        data: _Moving(folder),
        slop: dragSlop,
        // Its middle under the pointer, which is where it lands.
        feedback: Transform.translate(
          offset: const Offset(-ProjectTile.large / 2, -ProjectTile.large / 2),
          child: Opacity(
            opacity: 0.85,
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NushiTheme.control),
                  boxShadow: floatShadows(t),
                ),
                child: tile(),
              ),
            ),
          ),
        ),
        child: RailTile(
          tooltip: '${folderParts(folder).$1}\n${tildePath(folder)}',
          picked: shown == folder,
          onTap: () => sidebarProject.value = folder,
          onMenu: open,
          // The count follows each chat's state, not the list's.
          badge: ListenableBuilder(
            listenable: Listenable.merge([
              for (final c in daemon.chats.values)
                if (c.home == folder) c.look,
            ]),
            builder: (context, _) => TileBadge(_needs(folder)),
          ),
          child: tile(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget slot(Widget tile) => Padding(
      padding: const EdgeInsets.only(bottom: gap),
      child: Center(child: tile),
    );
    return SizedBox(
      width: width,
      child: ScrollConfiguration(
        // No scrollbar: it would lie over the tiles.
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          key: const PageStorageKey('project rail'),
          // Room for the first tile's ring and the last's.
          padding: const EdgeInsets.only(top: top, bottom: 6),
          children: [
            // The projects' tiles move; All projects and Add project…
            // stay put, and a tile dragged over one lands at that end.
            SlideList<_Moving>(
              count: folders.length,
              accepts: (_) => true,
              onMove: (from, to) => sidebarOrder.value = reordered(
                sidebarOrder.value,
                folders,
                from,
                to,
              ),
              item: (i, drag) => KeyedSubtree(
                key: ValueKey(folders[i]),
                child: slot(_project(context, folders[i], drag)),
              ),
              before: Column(
                children: [
                  slot(
                    RailTile(
                      tooltip: 'All projects',
                      picked: shown == null,
                      onTap: () => sidebarProject.value = null,
                      child: _Plain(
                        fill: t.lifted,
                        child: Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  slot(
                    SizedBox(
                      width: 20,
                      height: 1,
                      child: ColoredBox(color: t.line),
                    ),
                  ),
                ],
              ),
              after: slot(
                RailTile(
                  tooltip: 'Add project…',
                  onTap: addProject,
                  child: CustomPaint(
                    painter: _DashedEdge(t.textMuted),
                    child: SizedBox.square(
                      dimension: ProjectTile.large,
                      child: Icon(Icons.add, size: 18, color: t.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a tile's drag carries: its project's folder.
class _Moving {
  const new(this.folder);

  final String folder;
}

/// A tile of the rail as a control: [child], 38 square, pressed with a
/// click, Enter or Space; the pointer's tint over it, a ring of the
/// accent's ink around the one [picked] (and the one with the focus),
/// [badge] at its top right, and [onMenu] on a right-click.
class RailTile extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.onTap,
    required this.child,
    super.key,
    this.picked = false,
    this.onMenu,
    this.badge,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool picked;
  final OpenMenu? onMenu;
  final Widget? badge;

  /// The ring's width, and how far it stands off the tile's edge: with
  /// the window's color between them it reads on a tile of any color, the
  /// accent's own blue too.
  static const ring = 2.0;
  static const ringGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Semantics(
      selected: picked,
      child: GestureDetector(
        onSecondaryTapUp: switch (onMenu) {
          final open? => (d) => open(d.localPosition),
          null => null,
        },
        child: Pressable(
          onTap: onTap,
          tooltip: tooltip,
          // A project's tile drags too: a click may move as far as its
          // drag waits for. The rail's own tiles click alike.
          slop: dragSlop,
          tooltipAt: besideTile,
          builder: (context, look) => Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              // The pointer's tint, over whatever the tile shows.
              if (look.hover)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: look.pressed ? t.pressed : t.hover,
                        borderRadius: BorderRadius.circular(NushiTheme.control),
                      ),
                    ),
                  ),
                ),
              if (picked || look.focus)
                Positioned(
                  left: -ring - ringGap,
                  top: -ring - ringGap,
                  right: -ring - ringGap,
                  bottom: -ring - ringGap,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: picked ? const Key('tile ring') : null,
                      decoration: BoxDecoration(
                        border: Border.all(color: t.accentInk, width: ring),
                        // Around the tile's own corners, its curve
                        // parallel to theirs.
                        borderRadius: BorderRadius.circular(
                          NushiTheme.control + ring + ringGap,
                        ),
                      ),
                    ),
                  ),
                ),
              if (badge case final badge?)
                Positioned(top: -7, right: -7, child: badge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a rail tile's tooltip goes: to the tile's right, its middle
/// level with the tile's, so it covers the chats' edge rather than the
/// next tile; to its left if there's no room to the right, and below or
/// above it, as any tooltip, if there's none either side. Kept inside
/// the window, top to bottom.
Offset besideTile(TooltipPositionContext at) {
  const gap = 8.0;
  final TooltipPositionContext(:target, :targetSize, :tooltipSize) = at;
  final room = at.overlaySize;
  final right = target.dx + targetSize.width / 2 + gap;
  final left = target.dx - targetSize.width / 2 - gap - tooltipSize.width;
  final x = right + tooltipSize.width <= room.width
      ? right
      : left >= 0
      ? left
      : null;
  if (x == null) {
    return positionDependentBox(
      size: room,
      childSize: tooltipSize,
      target: target,
      verticalOffset: targetSize.height / 2 + gap,
      preferBelow: true,
    );
  }
  final y = target.dy - tooltipSize.height / 2;
  return Offset(x, y.clamp(0, max(0, room.height - tooltipSize.height)));
}

/// How many of a project's chats need you, on its tile's corner: the
/// count in a small pill of the needs color, ringed in the window's own
/// so it reads apart from the tile; nothing for none.
class TileBadge extends StatelessWidget {
  const new(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return IgnorePointer(
      child: Container(
        key: const Key('tile badge'),
        height: 21,
        constraints: const BoxConstraints(minWidth: 21),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.needs,
          borderRadius: BorderRadius.circular(NushiTheme.pill),
          border: Border.all(color: t.window, width: 2),
        ),
        child: Text(
          count > 9 ? '9+' : '$count',
          textScaler: TextScaler.noScaling,
          // The window's color reads on the needs color in every theme:
          // dark on its amber, light on a light set's brown.
          style: theme
              .ui(t.window, size: 10.5, weight: FontWeight.w700)
              .copyWith(height: 1),
        ),
      ),
    );
  }
}

/// A tile that isn't a project's: [child] on [fill].
class _Plain extends StatelessWidget {
  const new({required this.fill, required this.child});

  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: ProjectTile.large,
    height: ProjectTile.large,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(NushiTheme.control),
    ),
    child: child,
  );
}

/// A tile's edge in dashes, for one that isn't there yet (Add project…):
/// no fill, so it stands back from the projects' own.
class _DashedEdge extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    const dash = 4.0;
    final edge = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(stroke / 2),
          const Radius.circular(NushiTheme.control - stroke / 2),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in edge.computeMetrics()) {
      // A whole number of dashes, so none is cut where the edge closes.
      final count = (metric.length / (dash * 2)).round();
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(
          metric.extractPath(i * step, i * step + step / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdge old) => old.color != color;
}
