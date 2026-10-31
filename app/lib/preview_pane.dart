import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens:
/// its name (a menu of the chat's other files; with several files open, the
/// tabs of them all, [PreviewTabs]), Live while the daemon keeps it current,
/// Preview or Source (a file that renders), Reload and Open in browser (a
/// page, not a diagram), Show in Finder and Close, which closes every tab.
/// Read-only. It's one file's view, made again as its tab shows.
class PreviewPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.path,
    required this.onClose,
    super.key,
    this.tabsKey,
  });

  final ChatState chat;
  final Daemon daemon;
  final String path; // as the tool row names it
  final VoidCallback onClose;

  /// The key of its [PreviewTabs], from outside a view that's keyed by file,
  /// so the tabs' row outlives it.
  final Key? tabsKey;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

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

class _PreviewPaneState extends State<PreviewPane> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  late final PreviewKind _kind = previewKind(widget.path) ?? PreviewKind.code;
  late final PageHost? _page = _kind.page && _kind != PreviewKind.mermaid
      ? newPageHost()
      : null;
  late final DiagramHost? _diagram = _kind == PreviewKind.mermaid
      ? newDiagramHost()
      : null;
  late bool _source = widget.chat.previewSources.contains(widget.path);

  @override
  void dispose() {
    _watch.dispose();
    _page?.dispose();
    _diagram?.dispose();
    super.dispose();
  }

  String get _abs {
    final p = widget.path;
    return _watch.file?.path ??
        (p.startsWith('/') ? p : '${widget.chat.folder}/$p');
  }

  void _reveal() => revealInFinder(_abs).ignore();

  void _showSource(bool source) {
    setState(() => _source = source);
    final sources = widget.chat.previewSources;
    if (source) {
      sources.add(widget.path);
    } else {
      sources.remove(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final kind = _kind;
    final page = _page;
    final diagram = _diagram;
    final actions = <(IconData, String, double, VoidCallback)>[
      if (page != null) ...[
        (Icons.refresh, 'Reload', 15, () => page.reload().ignore()),
        (
          Icons.open_in_new,
          'Open in browser',
          14,
          () => openInBrowser(Uri.file(_abs)).ignore(),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, pane) {
            // The gutters where the row has room for them, and the bar's
            // full gaps where it has more (ADR 0072). Narrower, what it has
            // always had, so it keeps the name's room and folds where it did.
            final roomy =
                pane.maxWidth >=
                (page == null ? _roomyFrom : _roomyWithPageFrom);
            final wide = pane.maxWidth >= _gapsFrom;
            // What a group adds to the row's 8. The tabs' end needs none
            // short of wide: a last tab keeps a ✕'s room.
            final group = wide
                ? NushiTheme.groupGap - 8
                : roomy
                ? NushiTheme.barGap - 8
                : 0.0;
            return PaneHeader(
              inset: roomy ? NushiTheme.gutter : 12,
              end: roomy ? NushiTheme.gutter : 4,
              child: LayoutBuilder(
                builder: (context, box) => ListenableBuilder(
                  listenable: Listenable.merge([
                    _watch,
                    widget.chat.previewFiles,
                  ]),
                  builder: (context, _) {
                    final files = widget.chat.previewFiles.value;
                    final tabs = files.length > 1;
                    // A tab's file on its way keeps Live's room: a pick would
                    // otherwise widen the tabs' row for a moment, and move it.
                    final coming =
                        tabs && _watch.file == null && _watch.error.isEmpty;
                    return Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: wide ? group : 0),
                            child: Row(
                              spacing: roomy ? 6 : 8,
                              children: [
                                Icon(
                                  switch (kind) {
                                    PreviewKind.image => Icons.image_outlined,
                                    PreviewKind.html ||
                                    PreviewKind.svg => Icons.web_outlined,
                                    PreviewKind.mermaid =>
                                      Icons.account_tree_outlined,
                                    PreviewKind.code => Icons.code,
                                    _ => Icons.description_outlined,
                                  },
                                  size: 14,
                                  color: t.textSecondary,
                                ),
                                // The name opens the chat's other files;
                                // several open, their tabs take its place.
                                Expanded(
                                  child: tabs
                                      ? PreviewTabs(
                                          key: widget.tabsKey,
                                          chat: widget.chat,
                                          files: files,
                                          current: widget.path,
                                        )
                                      : Align(
                                          alignment: Alignment.centerLeft,
                                          child: FilesMenu(
                                            chat: widget.chat,
                                            current: widget.path,
                                            tooltip: (_) =>
                                                _watch.file?.path ??
                                                widget.path,
                                            label: (_) => Text(
                                              baseName(widget.path),
                                              style: theme.code(
                                                t.text,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_watch.live || coming)
                          Visibility.maintain(
                            visible: _watch.live,
                            child: LiveMark(version: _watch.file),
                          ),
                        if (kind.rendered)
                          SourceSwitch(source: _source, onChanged: _showSource),
                        Padding(
                          padding: EdgeInsets.only(left: group),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: wide ? NushiTheme.iconGap : 0,
                            children: [
                              if (box.maxWidth < _foldsBelow)
                                MenuIcon(
                                  Icons.more_horiz,
                                  tooltip: 'More',
                                  filter: false,
                                  entries: [
                                    for (final (icon, tooltip, _, onTap)
                                        in actions)
                                      MenuEntry(
                                        tooltip,
                                        icon: icon,
                                        onPick: onTap,
                                      ),
                                    MenuEntry(
                                      'Show in Finder',
                                      line: LineIcon.folderOpen,
                                      onPick: _reveal,
                                    ),
                                  ],
                                )
                              else ...[
                                for (final (icon, tooltip, size, onTap)
                                    in actions)
                                  IconTap(
                                    icon,
                                    tooltip: tooltip,
                                    size: size,
                                    onTap: onTap,
                                  ),
                                IconTap.line(
                                  LineIcon.folderOpen,
                                  tooltip: 'Show in Finder',
                                  size: 14,
                                  onTap: _reveal,
                                ),
                              ],
                              IconTap.line(
                                LineIcon.close,
                                tooltip: 'Close',
                                size: 15,
                                onTap: widget.onClose,
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
        ),
        Expanded(
          child: ColoredBox(
            color: t.base,
            child: PreviewBody(
              watch: _watch,
              source: _source,
              onReveal: _reveal,
              page: switch ((page, diagram)) {
                (final page?, _) => (watch) => WebPage(
                  host: page,
                  watch: watch,
                  roots: [widget.chat.folder, ?widget.chat.worktree?.path],
                ),
                (_, final diagram?) => (watch) => DiagramView(
                  host: diagram,
                  watch: watch,
                ),
                _ => null,
              },
            ),
          ),
        ),
      ],
    );
  }
}
