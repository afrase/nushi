import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/double_clicks.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/file_view.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/pane_tabs.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/text_width.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/widgets.dart' show Hover;

/// The Files pane's top row (ADR 0123), level with the chat's header: Files
/// at its left, as Claude desktop's; after it the open file's kind's icon,
/// its name and its ✕, or with two or more open their tabs, each led by its
/// own kind's icon ([PaneTabs], ADR 0070); Live
/// while the daemon keeps the file current; at its right end Expand (while
/// [onExpand] is given) and ×, which hides the pane and keeps its tabs
/// ([PaneEndButtons]). With no file open, Files alone. Squeezed, the row
/// folds from what stays ([_Fold]): Files goes first, then the one file's
/// kind's icon and Live, then the name, then Expand, so × always fits (the
/// tabs keep their icons, and scroll).
class FilesTopRow extends StatelessWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.shown,
    required this.onClose,
    super.key,
    this.tabsKey,
    this.expanded = false,
    this.onExpand,
  });

  final ChatState chat;
  final Daemon daemon;

  /// The file the viewer shows, if any.
  final ShownFile? shown;
  final VoidCallback onClose;

  /// The key of its [PaneTabs], from outside the pane, so the row keeps
  /// its scroll as the tabs change.
  final Key? tabsKey;
  final bool expanded;
  final VoidCallback? onExpand;

  /// The room between Files and the file's name or tabs.
  static const _titleGap = 16.0;

  /// The one file's kind's icon and the gap after it.
  static const double _kindRoom = previewKindIcon + previewKindGap;

  /// The least the one file's name keeps: a few letters and its ✕'s box
  /// (narrower, a ✕ alone would read as a stray).
  static const double _nameLeast = _Name.closeBox + 24;

  /// The gap before the end's buttons.
  static const _endGap = 8.0;

  /// [text]'s width in [style], as a [Text] here draws it.
  static double _width(BuildContext context, String text, TextStyle style) =>
      textWidth(context, text, style).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = this.shown;
    return PaneHeader(
      // Expanded, it's at the window's top left: with the sidebar hidden
      // it starts past the traffic lights, as a header's does.
      plain: expanded,
      end: PaneEndButtons.inset,
      child: LayoutBuilder(
        builder: (context, box) => ListenableBuilder(
          listenable: Listenable.merge([
            chat.files.tabs,
            chat.files.provisional,
            ?shown?.watch,
          ]),
          builder: (context, _) {
            final open = chat.files.tabs.value;
            final watch = shown?.watch;
            // A tab's file on its way keeps Live's room: a pick would
            // otherwise widen the tabs' row for a moment, and move it.
            final coming =
                open.length > 1 &&
                watch != null &&
                watch.file == null &&
                watch.error.isEmpty;
            final live = watch?.live ?? false;
            // One file's kind leads its name; tabs each lead with their own.
            final one = shown != null && open.length < 2;
            final fold = _Fold(
              room: box.maxWidth,
              words: _width(context, 'Files', theme.ui(t.text)) + _titleGap,
              marks:
                  (one ? _kindRoom : 0) +
                  (live || coming
                      ? 8 +
                            LiveMark.dot +
                            LiveMark.gap +
                            _width(context, 'Live', theme.ui(t.done, size: 12))
                      : 0),
              name: one ? _nameLeast : 0,
              ends: _endGap + (onExpand == null ? 1 : 2) * PaneEndButtons.box,
            );
            return Row(
              children: [
                if (fold.words) ...[
                  tooltip(
                    context,
                    plainPath(chat.folder),
                    Text(
                      'Files',
                      maxLines: 1,
                      style: theme.ui(t.text, weight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: _titleGap),
                ],
                if (one && fold.marks) ...[
                  // The file's kind, where the first tab's is, so its name
                  // stays put as a second file opens.
                  Icon(
                    shown.kind.icon,
                    size: previewKindIcon,
                    color: t.textSecondary,
                  ),
                  const SizedBox(width: previewKindGap),
                ],
                Expanded(
                  child: switch (shown) {
                    null => const SizedBox.shrink(),
                    _ when !fold.name => const SizedBox.shrink(),
                    final shown when open.length > 1 => PaneTabs.files(
                      key: tabsKey,
                      chat: chat,
                      tabs: open,
                      current: PreviewFile(shown.path),
                    ),
                    final shown => Align(
                      alignment: Alignment.centerLeft,
                      child: _Name(
                        daemon: daemon,
                        chat: chat,
                        path: shown.path,
                        tooltip: watch?.file?.path ?? shown.path,
                      ),
                    ),
                  },
                ),
                if ((live || coming) && fold.marks)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Visibility.maintain(
                      visible: live,
                      child: LiveMark(version: watch?.file),
                    ),
                  ),
                if (fold.expand) const SizedBox(width: _endGap),
                PaneEndButtons(
                  expanded: expanded,
                  onExpand: fold.expand ? onExpand : null,
                  onClose: onClose,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// What a [FilesTopRow] of a room keeps, from what its parts need: Files'
/// words, the one file's kind's icon and Live (marks), the one file's name's
/// least and the ends' buttons. Each folds in that order as the room
/// goes, so the row never needs more than its × ([PaneEndButtons.box]).
final class _Fold {
  new({
    required double room,
    required double words,
    required double marks,
    required double name,
    required double ends,
  }) : words = room >= words + marks + name + ends,
       marks = room >= marks + name + ends,
       name = room >= name + ends,
       expand = room >= ends;

  final bool words;
  final bool marks;
  final bool name;

  /// Expand and the gap before it; without it, × alone.
  final bool expand;
}

/// The one open file's name, plain (in italics while its tab is
/// provisional), its absolute path ([tooltip]) in a tooltip, and its ✕
/// (its unsaved edits' dot in its place, ADR 0096): a click on the name
/// shows the file in the tree ([showInFiles]) when it's in the chat's
/// folder, and does nothing otherwise; a double click keeps its tab. Its
/// text sits where a tab's would ([PaneTabs]), so a second file opening
/// moves nothing.
class _Name extends StatefulWidget {
  const new({
    required this.daemon,
    required this.chat,
    required this.path,
    required this.tooltip,
  });

  final Daemon daemon;
  final ChatState chat;
  final String path;
  final String tooltip;

  /// Its ✕'s box, which stays however little room it has.
  static const closeBox = 18.0;

  @override
  State<_Name> createState() => _NameState();
}

class _NameState extends State<_Name> {
  final _clicks = DoubleClicks();

  @override
  void dispose() {
    _clicks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final _Name(:daemon, :chat, :path, :tooltip) = widget;
    final inside = inFiles(daemon, chat, path);
    final tab = PreviewFile(path);
    final provisional = chat.files.provisional.value == tab;
    return Hover(
      builder: (context, {required hover}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Listener(
              onPointerDown: (e) {
                if (_clicks.down(path, e.position)) chat.files.keep(tab);
              },
              child: Pressable(
                onTap: inside == null ? null : () => showInFiles(chat, inside),
                tooltip: plainPath(tooltip),
                // Tinted under the pointer and ringed with the keys on it, as
                // a control is; the text stays where a tab's is.
                builder: (context, look) => Container(
                  padding: const EdgeInsets.fromLTRB(previewNameInset, 3, 3, 3),
                  decoration: look.hover
                      ? BoxDecoration(
                          color: look.pressed ? t.pressed : t.hover,
                          borderRadius: BorderRadius.circular(
                            NushiTheme.control,
                          ),
                        )
                      : null,
                  foregroundDecoration: focusRing(t, look),
                  child: Text(
                    plainPath(baseName(path)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme
                        .code(t.text, size: 12)
                        .copyWith(
                          fontStyle: provisional ? FontStyle.italic : null,
                        ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _Name.closeBox,
            child: EditedMark(
              chat: chat,
              path: path,
              shown: true,
              hover: hover,
              close: IconTap.line(
                LineIcon.close,
                size: 12,
                padding: 3,
                tooltip: 'Close tab',
                onTap: () =>
                    unawaited(closeTabSaving(context, chat, PreviewFile(path))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
