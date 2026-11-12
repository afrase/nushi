import 'package:flutter/material.dart';

import 'package:nushi/chat_colors.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';

/// A project's tile (ADR 0112): a small rounded square that tells
/// projects apart at a glance, 20 before the project's name in its
/// group's header, where every project has one, and 38 in the project
/// rail and in Change tile…. (Tried at 18 in the header: 20 reads better
/// now the header is the one place it always shows, and the header is no
/// higher for it.) It shows, in this order: what
/// the user set in Change tile… ([look]: a mark, an emoji or one or two
/// characters, and a color, either without the other); else the
/// repository's own [icon]; else the folder's initials ([name]) on
/// [color], its place in the theme's eight (`tileColors`). A color is the
/// user's data or worked out from the folder, never a theme's own: it's
/// drawn from `Tokens.avatars`, as a chat's color is.
class ProjectTile extends StatelessWidget {
  const new({
    required this.name,
    required this.color,
    super.key,
    this.look = const TileLook(),
    this.icon,
    this.size = large,
  });

  /// The rail's size and a group header's.
  static const large = 38.0;
  static const small = 20.0;

  final String name;
  final int color;
  final TileLook look;
  final ImageProvider? icon;
  final double size;

  /// Its corners: a control's in the rail, a tag's in a header, where a
  /// control's would make it a blob.
  static double radius(double size) =>
      size > 24 ? NushiTheme.control : NushiTheme.tag;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chosen = ChatColor.named(look.color);
    final fill = chosen?.ink(t) ?? t.avatars[color % t.avatars.length];
    final written = look.mark.isNotEmpty ? look.mark : tileInitials(name);
    // Letters are set small and bold, as initials; an emoji or a symbol
    // fills more of the tile.
    final letters = RegExp(r'^[\p{L}\p{N}]+$', unicode: true).hasMatch(written);
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius(size)),
      ),
      child: Text(
        written,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        // The emoji's own colors, not the theme's text scale.
        textScaler: TextScaler.noScaling,
        style: theme
            .ui(
              t.monogramText,
              // 12 in the rail, 10 in a header: two letters fill a
              // small tile as far as they can and still be read.
              size: letters
                  ? (size > 24 ? size * 0.32 : size * 0.5)
                  : size * 0.5,
              weight: FontWeight.w700,
            )
            .copyWith(height: 1, letterSpacing: letters ? 0.2 : 0),
      ),
    );
    final image = icon;
    if (image == null || !look.isEmpty) return initials;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius(size)),
      child: SizedBox.square(
        dimension: size,
        // A see-through icon lies on a raised bit's fill, as a button.
        child: ColoredBox(
          color: t.lifted,
          child: Image(
            image: image,
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            // Until it's decoded, and if it can't be: the initials.
            frameBuilder: (context, child, frame, sync) =>
                frame == null && !sync ? initials : child,
            errorBuilder: (context, _, _) => initials,
          ),
        ),
      ),
    );
  }
}

/// [folder]'s tile as the app has it now: the user's look for it
/// ([projectTiles]), the repository's icon once the daemon has answered
/// (`Daemon.projectIcons`), and [color], its place in the sidebar's
/// colors.
class FolderTile extends StatelessWidget {
  const new({
    required this.daemon,
    required this.folder,
    required this.color,
    super.key,
    this.size = ProjectTile.large,
  });

  final Daemon daemon;
  final String folder;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([projectTiles, daemon.projectIcons]),
    builder: (context, _) => ProjectTile(
      name: folderParts(folder).$1,
      color: color,
      look: projectTiles.value[folder] ?? const TileLook(),
      icon: daemon.projectIcons.of(folder),
      size: size,
    ),
  );
}

/// The color of each of [folders]' tiles (`tileColors`): given in the
/// order the projects joined the sidebar ([sidebarProjects]; one not
/// kept yet, where a chat is starting, last), those the user chose
/// counted first.
Map<String, int> folderTileColors(Iterable<String> folders) {
  final joined = [
    ...sidebarProjects.value.where(folders.contains),
    ...folders.where((f) => !sidebarProjects.value.contains(f)),
  ];
  return tileColors(
    joined,
    chosen: {
      for (final f in joined)
        if (ChatColor.named(projectTiles.value[f]?.color ?? '') case final c?)
          f: c.index,
    },
  );
}
