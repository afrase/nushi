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
import 'package:nushi/skills_list.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens:
/// its name (a menu of the chat's other files), Live while the daemon
/// keeps it current, Preview or Source (a file that renders), Reload and
/// Open in browser (a page, not a diagram), Open in a tab ([onTab]), Show in
/// Finder and Close. Read-only.
///
/// With [tab] it's a preview tab's view, in the chat's whole main area: the
/// file's path in place of the menu and Close, the tab having its own, and
/// when the file is gone it says so with a Close tab. It's one view for the
/// tab that shows, made again as a tab shows, so a page never holds a web
/// view while it's out of sight.
class PreviewPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.path,
    required this.onClose,
    super.key,
    this.tab = false,
    this.onTab,
  });

  final ChatState chat;
  final Daemon daemon;
  final String path; // as the tool row names it
  final VoidCallback onClose;
  final bool tab;
  final VoidCallback? onTab;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

/// Below this width the pane's header has no room for every button (a page
/// has four and Close, beside Live and the switch): they fold into a ⋯.
const double _foldsBelow = 380;

class _PreviewPaneState extends State<PreviewPane> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  late final PreviewKind _kind = previewKind(widget.path) ?? PreviewKind.code;
  late final PageHost? _page = _kind.page && _kind != PreviewKind.mermaid
      ? newPageHost()
      : null;
  late final DiagramHost? _diagram = _kind == PreviewKind.mermaid
      ? newDiagramHost()
      : null;
  late bool _source =
      widget.tab && widget.chat.tabSources.contains(widget.path);

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
    if (!widget.tab) return;
    final sources = widget.chat.tabSources;
    if (source) {
      sources.add(widget.path);
    } else {
      sources.remove(widget.path);
    }
  }

  /// A preview tab's file is gone, or the daemon no longer shows it.
  bool get _gone =>
      widget.tab &&
      (_watch.error.isNotEmpty || (_watch.file?.missing ?? false));

  Widget get _goneNote => PreviewNote(
    _watch.error.isNotEmpty
        ? _watch.error
        : '${baseName(widget.path)} isn’t there any more.',
    action: Button(
      label: 'Close tab',
      icon: Icons.close,
      onPressed: widget.onClose,
    ),
  );

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
      if (widget.onTab case final onTab?)
        (Icons.open_in_full, 'Open in a tab', 13, onTab),
      (Icons.folder_open_outlined, 'Show in Finder', 14, _reveal),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHeader(
          inset: 12,
          child: LayoutBuilder(
            builder: (context, box) => ListenableBuilder(
              listenable: _watch,
              builder: (context, _) => Row(
                spacing: 8,
                children: [
                  Icon(
                    switch (kind) {
                      PreviewKind.image => Icons.image_outlined,
                      PreviewKind.html || PreviewKind.svg => Icons.web_outlined,
                      PreviewKind.mermaid => Icons.account_tree_outlined,
                      PreviewKind.code => Icons.code,
                      _ => Icons.description_outlined,
                    },
                    size: 14,
                    color: t.textSecondary,
                  ),
                  // In the pane, the name opens the chat's other files.
                  Expanded(
                    child: widget.tab
                        ? Tooltip(
                            message: _abs,
                            child: Text(
                              widget.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.code(t.text, size: 12),
                            ),
                          )
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: FilesMenu(
                              chat: widget.chat,
                              current: widget.path,
                              tooltip: (_) => _watch.file?.path ?? widget.path,
                              label: (_) => Text(
                                baseName(widget.path),
                                style: theme.code(t.text, size: 12),
                              ),
                            ),
                          ),
                  ),
                  if (_watch.live && !_gone) LiveMark(version: _watch.file),
                  if (kind.rendered && !_gone)
                    SourceSwitch(source: _source, onChanged: _showSource),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (box.maxWidth < _foldsBelow)
                        MenuIcon(
                          Icons.more_horiz,
                          tooltip: 'More',
                          filter: false,
                          entries: [
                            for (final (icon, tooltip, _, onTap) in actions)
                              MenuEntry(tooltip, icon: icon, onPick: onTap),
                          ],
                        )
                      else
                        for (final (icon, tooltip, size, onTap) in actions)
                          IconTap(
                            icon,
                            tooltip: tooltip,
                            size: size,
                            onTap: onTap,
                          ),
                      if (!widget.tab)
                        IconTap(
                          Icons.close,
                          tooltip: 'Close',
                          size: 15,
                          onTap: widget.onClose,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: t.base,
            // The body stays under the note: a file an agent rewrites by
            // deleting it first keeps its web view.
            child: Stack(
              fit: StackFit.expand,
              children: [
                PreviewBody(
                  watch: _watch,
                  source: _source,
                  onReveal: _reveal,
                  center: widget.tab,
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
                ListenableBuilder(
                  listenable: _watch,
                  builder: (context, _) => _gone
                      ? ColoredBox(color: t.base, child: _goneNote)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
