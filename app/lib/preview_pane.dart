import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diagram_page.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/skills_list.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart';

/// A file the agent wrote, beside the chat where a subagent's pane opens:
/// its name (a menu of the chat's other files), Live while the daemon
/// keeps it current, Preview or Source (a file that renders), Reload and
/// Open in browser (a page, not a diagram), Show in Finder and Close.
/// Read-only.
class PreviewPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.path,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String path; // as the tool row names it
  final VoidCallback onClose;

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  late final _watch = FileWatch(widget.daemon, widget.chat.id, widget.path);
  late final PreviewKind _kind = previewKind(widget.path) ?? PreviewKind.code;
  late final PageHost? _page = _kind.page && _kind != PreviewKind.mermaid
      ? newPageHost()
      : null;
  late final DiagramHost? _diagram = _kind == PreviewKind.mermaid
      ? newDiagramHost()
      : null;
  bool _source = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final kind = _kind;
    final page = _page;
    final diagram = _diagram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHeader(
          inset: 12,
          child: ListenableBuilder(
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
                // The name opens the chat's other files.
                Expanded(
                  child: Align(
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
                if (_watch.live) LiveMark(version: _watch.file),
                if (kind.rendered)
                  SourceSwitch(
                    source: _source,
                    onChanged: (v) => setState(() => _source = v),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (page != null) ...[
                      IconTap(
                        Icons.refresh,
                        tooltip: 'Reload',
                        size: 15,
                        onTap: () => page.reload().ignore(),
                      ),
                      IconTap(
                        Icons.open_in_new,
                        tooltip: 'Open in browser',
                        size: 14,
                        onTap: () => openInBrowser(Uri.file(_abs)).ignore(),
                      ),
                    ],
                    IconTap(
                      Icons.folder_open_outlined,
                      tooltip: 'Show in Finder',
                      size: 14,
                      onTap: _reveal,
                    ),
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
