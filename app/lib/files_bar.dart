import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart' show fileTreeKey;
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_menu.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/marks_note.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/view_options.dart';

/// The Files pane's second row (ADR 0123), across the whole pane with a
/// hairline under it, as Claude desktop's. At its right end, always there
/// and never moving: Collapse all folders, the tree shown or hidden (lit
/// while it shows, ⇧⌘Y) and the pane's ⋯ ([filesMenu]). Left of them,
/// while a file shows, its path line ([PathLine], a click copies it) over
/// the viewer, the source button, a page's Reload and Open in browser, and
/// Show in Finder; those buttons fold into the ⋯ where the row is narrow.
/// [start] is the room before the path, so it stays over the viewer.
class FilesBar extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.shown,
    super.key,
    this.treeShows = false,
    this.treeOut = false,
    this.start = 0,
  });

  final ChatState chat;
  final Daemon daemon;
  final ShownFile? shown;

  /// Whether the tree shows with room in the pane: the tree's button is lit
  /// from it, not only from the pref (a squeezed pane can leave it none).
  final bool treeShows;

  /// Whether the tree is on but squeezed out of the pane: there's no tree
  /// to hide or show, so its button and Collapse are unavailable.
  final bool treeOut;
  final double start;

  /// Its height, the hairline under it included.
  static const height = 40.0;

  /// The room a file's button takes in the row.
  static const _button = 30.0;

  /// The least the path keeps beside the file's buttons before they fold.
  static const _pathLeast = 160.0;

  /// The room after the file's buttons, before the right end's.
  static const _gap = 8.0;

  /// The size of the right end's icons, the top row's Expand's.
  static const _icon = 18.0;

  /// The right end's width: its three buttons' boxes, side by side as the
  /// top row's Expand and × are, so the tree's button sits under Expand
  /// and the ⋯ under ×, as in Claude desktop. Squeezed under it, fewer.
  static const double ends = 3 * PaneEndButtons.box;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final shown = this.shown;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      padding: const EdgeInsets.only(bottom: 1, right: PaneEndButtons.inset),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          for (final o in viewToggles) o.pref,
          for (final c in viewChoices) c.pref,
          filesTree,
          folderTreeOf(chat),
          ?shown?.watch,
          ?shown?.source,
        ]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            // Squeezed with the tree on the left, the path's start gives
            // way to the right end's buttons.
            // Narrower than all three, Collapse goes, then the tree's
            // button: the ⋯ has both.
            final buttons = (box.maxWidth / PaneEndButtons.box).floor().clamp(
              1,
              3,
            );
            final ends = buttons * PaneEndButtons.box;
            final start = min(this.start, max(0.0, box.maxWidth - ends));
            final room = box.maxWidth - start - ends;
            final folds = shown != null && room < _least(context, shown);
            // Under its own box and the gap after it, the source button
            // folds too.
            final source =
                shown != null && shown.switches && room >= _button + _gap;
            return Row(
              children: [
                SizedBox(width: start),
                Expanded(
                  child: shown == null
                      ? const SizedBox.shrink()
                      : _file(
                          context,
                          shown,
                          folds: folds,
                          source: source,
                          gap: room >= _gap,
                        ),
                ),
                _ends(
                  context,
                  t,
                  buttons: buttons,
                  folded: [
                    if (shown != null && folds)
                      ..._folded(context, shown, source: !source),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The room [shown]'s path and buttons need before the buttons fold.
  double _least(BuildContext context, ShownFile shown) {
    // Its page's actions and Show in Finder; the source button stays.
    final count = shown.actions(context).length + 1;
    return _pathLeast + (count + (shown.switches ? 1 : 0)) * _button;
  }

  /// The shown file's path and buttons, but those [folds] puts in the ⋯:
  /// the source button too without [source], and the gap after them
  /// without [gap].
  Widget _file(
    BuildContext context,
    ShownFile shown, {
    required bool folds,
    required bool source,
    required bool gap,
  }) {
    final actions = shown.actions(context);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: PathLine(
              folder: shown.chat.folder,
              path: shown.path,
              status: MarksNote(shown: shown),
              top: 0,
              end: 8,
            ),
          ),
        ),
        if (source)
          SourceButton(
            source: shown.source.value,
            onChanged: (on) => shown.showSource(on: on),
          ),
        if (!folds) ...[
          for (final (icon, tooltip, size, onTap) in actions)
            IconTap(
              icon,
              tooltip: tooltip,
              size: size,
              padding: IconTap.header,
              onTap: onTap,
            ),
          IconTap.line(
            LineIcon.folderOpen,
            tooltip: conventions.reveal,
            size: 14,
            padding: IconTap.header,
            onTap: shown.reveal,
          ),
        ],
        if (gap) const SizedBox(width: _gap),
      ],
    );
  }

  /// The file's buttons as the ⋯'s rows, when they fold: its [source]
  /// button's first, when that folds too.
  List<MenuEntry> _folded(
    BuildContext context,
    ShownFile shown, {
    required bool source,
  }) => [
    if (source)
      MenuEntry(
        SourceButton.tooltip(source: shown.source.value),
        line: LineIcon.source,
        onPick: () => shown.showSource(on: !shown.source.value),
      ),
    for (final (icon, tooltip, _, onTap) in shown.actions(context))
      MenuEntry(tooltip, icon: icon, onPick: onTap),
    MenuEntry(
      conventions.reveal,
      line: LineIcon.folderOpen,
      onPick: shown.reveal,
    ),
  ];

  /// Collapse all folders, the tree's button and the ⋯, Claude desktop's.
  Widget _ends(
    BuildContext context,
    Tokens t, {
    required int buttons,
    required List<MenuEntry> folded,
  }) {
    final on = treeShows;
    const pad = (PaneEndButtons.box - _icon) / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (buttons > 2)
          IconTap.line(
            LineIcon.collapseAll,
            tooltip: 'Collapse all folders',
            size: _icon,
            padding: pad,
            color: t.text,
            onTap: on && canCollapseFolders(chat, daemon)
                ? folderTreeOf(chat).collapseAll
                : null,
          ),
        if (buttons > 1)
          IconTap.line(
            LineIcon.fileTree,
            tooltip: withKey(
              on ? 'Hide file tree' : 'Show file tree',
              keyLabel(fileTreeKey),
            ),
            size: _icon,
            padding: pad,
            color: t.text,
            lit: on,
            onTap: !treeOut ? () => toggleFileTree(chat) : null,
          ),
        // Under it, ending under its right edge, as Claude's does.
        TrailingMenus(
          child: MenuIcon.line(
            LineIcon.more,
            tooltip: 'More',
            size: _icon,
            padding: pad,
            color: t.text,
            filter: false,
            heldOpen: true,
            entries: filesMenu(
              context,
              chat,
              daemon,
              treeShows: treeShows,
              treeOut: treeOut,
              folded: folded,
            ),
          ),
        ),
      ],
    );
  }
}
