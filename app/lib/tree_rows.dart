import 'package:flutter/material.dart';

import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What a row of the tree is.
enum TreeRowKind {
  folder,
  file,

  /// A link out of the chat's folder, a loop or one leading nowhere: never
  /// followed, never opened.
  link,

  /// A fifo, a device, a socket.
  other,

  /// "N more": what a folder has past the daemon's cap.
  more,

  /// A folder on its way, empty, or that can't be listed: [TreeRow.note].
  note,
}

/// One row of the Files pane's tree.
@immutable
class TreeRow {
  const new(
    this.path,
    this.name,
    this.depth,
    this.kind, {
    this.open = false,
    this.ignored = false,
    this.linked = false,
    this.size = 0,
    this.modified,
    this.count = 0,
    this.note = '',
  });

  /// Relative to the chat's folder; a [TreeRowKind.more] or note row's is
  /// its folder's.
  final String path;
  final String name;
  final int depth;
  final TreeRowKind kind;
  final bool open; // a folder's
  final bool ignored;
  final bool linked;
  final int size;
  final DateTime? modified;
  final int count; // a more row's
  final String note;

  /// Whether the keys can go to it: an entry, not what's said of a folder.
  bool get entry => kind != TreeRowKind.more && kind != TreeRowKind.note;

  /// Whether a click opens it in the preview.
  bool get opens => kind == TreeRowKind.file && previewKind(path) != null;
}

/// One row of the tree: indented by its depth, a folder's chevron or a
/// file's kind, its name (muted when git ignores it, or nothing opens it),
/// and a dot when the chat wrote it (or a file in the folder).
class TreeRowView extends StatelessWidget {
  const new(
    this.row, {
    required this.selected,
    required this.showing,
    required this.wrote,
    required this.onTap,
    super.key,
    this.large = false,
  });

  final TreeRow row;

  /// The phone's: its text and icons larger, as its touch targets are.
  final bool large;
  final bool selected;
  final bool showing; // the file the preview shows
  final bool wrote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final r = row;
    final indent = (large ? 12.0 : 4.0) + r.depth * (large ? 18 : 14);
    final text = large ? 15.0 : 12.5;
    final icon = large ? 18.0 : 14.0;
    if (!r.entry) {
      return Padding(
        padding: EdgeInsets.only(left: indent + icon + 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            r.kind == TreeRowKind.more ? '${r.count} more' : r.note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textMuted, size: text - 0.5),
          ),
        ),
      );
    }
    final dim = r.ignored || r.kind != TreeRowKind.folder && !r.opens;
    final kind = previewKind(r.path);
    return Tap(
      onTap: onTap,
      selected: selected,
      fill: showing && !selected ? t.hover : null,
      tooltip: _tooltip(r),
      padding: EdgeInsets.only(left: indent, right: 6),
      child: Row(
        spacing: 4,
        children: [
          SizedBox(
            width: 14,
            child: r.kind == TreeRowKind.folder ? Chevron(open: r.open) : null,
          ),
          Icon(
            switch (r.kind) {
              TreeRowKind.folder =>
                r.open ? Icons.folder_open_outlined : Icons.folder_outlined,
              TreeRowKind.link => Icons.link_off,
              _ => switch (kind) {
                PreviewKind.image => Icons.image_outlined,
                PreviewKind.html || PreviewKind.svg => Icons.web_outlined,
                PreviewKind.mermaid => Icons.account_tree_outlined,
                PreviewKind.code => Icons.code,
                null => Icons.insert_drive_file_outlined,
                _ => Icons.description_outlined,
              },
            },
            size: icon,
            color: dim ? t.textMuted : t.textSecondary,
          ),
          Flexible(
            child: Text(
              r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(dim ? t.textMuted : t.text, size: text),
            ),
          ),
          if (wrote)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.done, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  /// The row's path, and what's known of it.
  String _tooltip(TreeRow r) {
    final what = [
      r.path,
      if (r.kind == TreeRowKind.file) sizeText(r.size),
      if (r.modified case final m?) ago(clock().difference(m), m),
      if (wrote && r.kind == TreeRowKind.folder) 'holds files the chat wrote',
      if (wrote && r.kind != TreeRowKind.folder) 'the chat wrote it',
      if (r.ignored) 'ignored by git',
      if (r.linked) 'a link',
      if (r.kind == TreeRowKind.link)
        'a link that leads out of the folder, or nowhere',
      if (r.kind == TreeRowKind.file && !r.opens) 'no preview for this type',
    ];
    return what.join(' · ');
  }
}
