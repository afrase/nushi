import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/edit_bars.dart';
import 'package:nushi/files_pane.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;

// A file preview's header (preview_pane.dart): its name or its tabs, Live,
// the wrap button, its actions, Show in Finder and Close.

/// Below this width the pane's header has no room for every button (a page
/// has three and Close, beside Live and the switch): they fold into a ⋯.
const double _foldsBelow = 380;

/// From this wide the pane's header has the gutters and leaves the name about
/// what it had: a page's has two more buttons.
const double _roomyFrom = 460;
const double _roomyWithPageFrom = 520;

/// From this wide it has 24 between groups too. Below, at the pane's 560 to
/// start with, that room is three short names' tabs (ADR 0072).
const double _gapsFrom = 640;

/// The header's row of `PreviewPane`: the file's [kind] icon and name (a
/// click shows it in the Files pane; with several files open, the tabs of
/// them all, [PreviewTabs]), Live while [watch] keeps it current, the wrap
/// button while it [wraps], [actions] (a [page]'s Reload and Open in
/// browser), Show in Finder ([onReveal]) and Close ([onClose]); folded into
/// a ⋯ where the pane is narrow.
class PreviewHeader extends StatelessWidget {
  const new({
    required this.daemon,
    required this.chat,
    required this.path,
    required this.watch,
    required this.kind,
    required this.page,
    required this.actions,
    required this.wraps,
    required this.onReveal,
    required this.onClose,
    super.key,
    this.tabsKey,
  });

  final Daemon daemon;
  final ChatState chat;
  final String path;
  final FileWatch watch;
  final PreviewKind kind;

  /// It's a page's, whose header has more buttons.
  final bool page;

  /// Each action's icon, tooltip, icon size and what it does.
  final List<(IconData, String, double, VoidCallback)> actions;

  /// Whether it shows a source, whose lines wrap or not; asked as the file
  /// changes.
  final bool Function() wraps;
  final VoidCallback onReveal;
  final VoidCallback onClose;

  /// The key of its [PreviewTabs] (`PreviewPane.tabsKey`).
  final Key? tabsKey;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return LayoutBuilder(
      builder: (context, pane) {
        // The gutters where the row has room for them, and the bar's
        // full gaps where it has more (ADR 0072). Narrower, what it has
        // always had, so it keeps the name's room and folds where it did.
        final roomy = pane.maxWidth >= (page ? _roomyWithPageFrom : _roomyFrom);
        final wide = pane.maxWidth >= _gapsFrom;
        // What a group adds to the row's 8. The tabs' end needs none
        // short of wide: a last tab keeps a ✕'s room.
        final group = wide
            ? NushiTheme.groupGap - 8
            : roomy
            ? NushiTheme.barGap - 8
            : 0.0;
        return ValueListenableBuilder(
          valueListenable: chat.previewTabs,
          // Beside a browser tab its row's ends are the browser's, so
          // going from one tab to the other moves no chip (ADR 0094).
          builder: (context, open, row) {
            final chips = open.length > 1 && previewChips(open);
            return PaneHeader(
              inset: chips
                  ? previewChipInset
                  : roomy
                  ? NushiTheme.gutter
                  : 12,
              end: previewHeaderEnd(pane.maxWidth, open, page: page),
              child: row!,
            );
          },
          child: LayoutBuilder(
            builder: (context, box) => ListenableBuilder(
              listenable: Listenable.merge([
                watch,
                chat.previewTabs,
                wrapLines,
              ]),
              builder: (context, _) {
                final open = chat.previewTabs.value;
                final tabs = open.length > 1;
                // A tab's file on its way keeps Live's room: a pick
                // would otherwise widen the tabs' row for a moment,
                // and move it.
                final coming =
                    tabs && watch.file == null && watch.error.isEmpty;
                final folds = box.maxWidth < _foldsBelow;
                final wraps = this.wraps();
                return Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: wide ? group : 0),
                        child: Row(
                          spacing: roomy ? 6 : 8,
                          children: [
                            // A chip has its own icon.
                            if (!tabs || !previewChips(open))
                              Icon(kind.icon, size: 14, color: t.textSecondary),
                            // The name shows the file in the Files
                            // pane; several open, their tabs take its
                            // place.
                            Expanded(
                              child: tabs
                                  ? _tabs(open)
                                  : Align(
                                      alignment: Alignment.centerLeft,
                                      child: _Name(
                                        daemon: daemon,
                                        chat: chat,
                                        path: path,
                                        tooltip: watch.file?.path ?? path,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (watch.live || coming)
                      Visibility.maintain(
                        visible: watch.live,
                        child: LiveMark(version: watch.file),
                      ),
                    if (wraps && !folds) const WrapButton(),
                    Padding(
                      padding: EdgeInsets.only(left: group),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: wide ? NushiTheme.iconGap : 0,
                        children: [
                          if (folds)
                            MenuIcon.line(
                              LineIcon.more,
                              tooltip: 'More',
                              filter: false,
                              entries: [
                                if (wraps)
                                  MenuEntry(
                                    wrapLabel(wrap: wrapLines.value),
                                    icon: Icons.wrap_text,
                                    onPick: toggleWrap,
                                  ),
                                for (final (icon, tooltip, _, onTap) in actions)
                                  MenuEntry(tooltip, icon: icon, onPick: onTap),
                                MenuEntry(
                                  conventions.reveal,
                                  line: LineIcon.folderOpen,
                                  onPick: onReveal,
                                ),
                              ],
                            )
                          else ...[
                            for (final (icon, tooltip, size, onTap) in actions)
                              IconTap(
                                icon,
                                tooltip: tooltip,
                                size: size,
                                onTap: onTap,
                              ),
                            IconTap.line(
                              LineIcon.folderOpen,
                              tooltip: conventions.reveal,
                              size: 14,
                              onTap: onReveal,
                            ),
                          ],
                          IconTap.line(
                            LineIcon.close,
                            tooltip: 'Close',
                            size: 15,
                            onTap: onClose,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// The tabs of [open], this file's showing; as chips, the + after them,
  /// as a browser tab's title row has it, so the row keeps its shape as
  /// you move between the two.
  Widget _tabs(List<PreviewEntry> open) {
    final tabs = PreviewTabs(
      key: tabsKey,
      chat: chat,
      tabs: open,
      current: PreviewFile(path),
    );
    if (!previewChips(open)) return tabs;
    return Row(
      spacing: 2,
      children: [
        Flexible(child: tabs),
        NewBrowserTab(chat: chat),
      ],
    );
  }
}

/// The room right of a preview header's last button (Close) in a pane
/// [width] wide with [open]'s tabs, a [page]'s or not: the path line's ends
/// there too.
double previewHeaderEnd(
  double width,
  List<PreviewEntry> open, {
  required bool page,
}) {
  if (open.length > 1 && previewChips(open)) return previewChipInset;
  final roomy = width >= (page ? _roomyWithPageFrom : _roomyFrom);
  return roomy ? NushiTheme.gutter : 4;
}

/// The one file's name, plain, its absolute path ([tooltip]) in a tooltip:
/// a click shows it in the Files pane ([showInFiles]) when the file is in
/// the chat's folder, and does nothing otherwise. Its text sits where a
/// tab's would ([PreviewTabs]), so a second file opening moves nothing.
class _Name extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final inside = inFiles(daemon, chat, path);
    return Pressable(
      onTap: inside == null ? null : () => showInFiles(chat, inside),
      tooltip: plainPath(tooltip),
      // Tinted under the pointer and ringed with the keys on it, as a
      // control is; the text stays where a tab's is.
      builder: (context, look) => Container(
        padding: const EdgeInsets.fromLTRB(previewNameInset, 3, 3, 3),
        decoration: look.hover
            ? BoxDecoration(
                color: look.pressed ? t.pressed : t.hover,
                borderRadius: BorderRadius.circular(NushiTheme.control),
              )
            : null,
        foregroundDecoration: focusRing(t, look),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 7,
          children: [
            Flexible(
              child: Text(
                plainPath(baseName(path)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.code(t.text, size: 12),
              ),
            ),
            // Its unsaved edits' dot (ADR 0096).
            EditedMark(
              chat: chat,
              path: path,
              close: const SizedBox.shrink(),
              shown: false,
              hover: false,
            ),
          ],
        ),
      ),
    );
  }
}
