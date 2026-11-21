import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/edit_bars.dart' show FileTabsFocus;
import 'package:nushi/file_view.dart';
import 'package:nushi/files_bar.dart';
import 'package:nushi/files_open.dart';
import 'package:nushi/files_split.dart';
import 'package:nushi/files_top_row.dart';
import 'package:nushi/files_tree.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/open_file.dart' show openFileKey;
import 'package:nushi/panes.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

export 'package:nushi/files_open.dart';

/// The Files pane (ADR 0123), as Claude desktop's: its top row
/// ([FilesTopRow]: Files, the open files' name or tabs, ×), its bar
/// ([FilesBar]: the shown file's path and buttons), then the viewer of the
/// open files ([FileView]), blank with none ([FilesBlank]), and the tree of
/// the chat's folder at the pane's right ([FilesTree]), its edge dragged.
/// Opening a file never moves the tree. The viewer gives its width first
/// as the pane narrows, then the tree ([treeWidth]); squeezed narrower
/// still, the tree gives on, the viewer keeping its least. With a daemon
/// older than the tree (`filesApi`) the viewer is alone.
class FilesPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onClose,
    super.key,
    this.tabsKey,
    this.expanded = false,
    this.onExpand,
  });

  final ChatState chat;
  final Daemon daemon;

  /// Hides the pane; its tabs stay.
  final VoidCallback onClose;

  /// The key of its tabs' row ([FilesTopRow.tabsKey]).
  final Key? tabsKey;

  /// Whether it covers the chat's whole pane (ADR 0094's Expand).
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  State<FilesPane> createState() => _FilesPaneState();
}

class _FilesPaneState extends State<FilesPane> with FileTabsFocus {
  ShownFile? _shown;

  /// The pane's own focus, taken as it expands, so Esc reaches it there
  /// (what had the focus, the chat's box, is hidden behind it).
  final _pane = FocusNode(debugLabel: 'files pane', skipTraversal: true);

  ChatState get _chat => widget.chat;

  @override
  void initState() {
    super.initState();
    _shown = _make(_chat.files.shown.value);
    _chat.files.shown.addListener(_showFile);
    if (widget.expanded) _takeFocus();
  }

  @override
  void didUpdateWidget(FilesPane old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) _takeFocus();
  }

  /// Gives the pane the focus after this frame, unless a field in it (the
  /// tree's filter, the find bar) or the editor has it.
  void _takeFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final at = FocusManager.instance.primaryFocus?.context;
    final inside =
        at != null && at.findAncestorStateOfType<_FilesPaneState>() == this;
    if (!inside) _pane.requestFocus();
  });

  @override
  void dispose() {
    _chat.files.shown.removeListener(_showFile);
    // The viewer, under this, has gone already.
    _shown?.dispose();
    _pane.dispose();
    super.dispose();
  }

  ShownFile? _make(PreviewFile? file) =>
      file == null ? null : ShownFile(_chat, widget.daemon, file.path);

  /// Another tab shows: its file's parts are made, and the last one's let
  /// go once its view has gone.
  void _showFile() {
    final file = _chat.files.shown.value;
    if (file?.path == _shown?.path) return;
    final old = _shown;
    setState(() => _shown = _make(file));
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final shown = _shown;
    // Esc collapses it from anywhere in it, once what it's in has had it
    // (the filter clears its text, the find bar closes).
    final expand = widget.expanded ? widget.onExpand : null;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): ?expand},
      child: Focus(
        focusNode: _pane,
        // The tree hidden (⇧⌘Y), or a daemon older than it: the viewer
        // takes its room, and the pane keeps its width.
        child: ValueListenableBuilder(
          valueListenable: filesTree,
          builder: (context, on, _) =>
              _panes(shown, t, tree: on && widget.daemon.daemonApi >= filesApi),
        ),
      ),
    );
  }

  /// The tree's width as its edge is dragged, until the drag ends (and the
  /// width is saved): the bar's path follows it with the tree on the left.
  double? _treeDragged;

  Widget _panes(ShownFile? shown, Tokens t, {required bool tree}) =>
      LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          // Under the least of both the tree gives on, the viewer keeping
          // its least (treeWidth).
          final squeezed = w < filesTreeLeast + filesViewerLeast;
          final most = squeezed ? treeWidth(w, filesTreeInitial) : treeMost(w);
          // Squeezed out, the blank names the way that's left.
          final named = tree && most > 0;
          final least = squeezed ? most : filesTreeLeast;
          return ValueListenableBuilder(
            valueListenable: filesTreeSide,
            builder: (context, side, _) {
              final right = treeOnRight(side);
              // The viewer and the tree each a group: Tab goes through one
              // and then the other in the order they read, the tree's
              // search before its rows on either side (the viewer, as tall
              // as both, would otherwise take its leftmost part first).
              final viewer = Expanded(
                key: const ValueKey('viewer'),
                child: FocusTraversalGroup(
                  child: shown == null
                      ? FilesBlank(tree: named)
                      : FileView(key: ObjectKey(shown), shown: shown),
                ),
              );
              final edge = BorderSide(color: t.line);
              final files = Resizable(
                key: const ValueKey('tree'),
                name: 'filesTree',
                initial: filesTreeInitial,
                min: least,
                max: most,
                // Its edge on the viewer's side.
                left: right,
                locked: squeezed,
                // Its own hairline, which a locked edge keeps.
                line: false,
                // Told after the frame when the tree's edge goes mid-drag
                // (squeezed out, the pane closed): this may have gone too.
                onDrag: (width) {
                  if (mounted) setState(() => _treeDragged = width);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: right ? Border(left: edge) : Border(right: edge),
                  ),
                  child: FocusTraversalGroup(
                    child: FilesTree(chat: _chat, daemon: widget.daemon),
                  ),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilesTopRow(
                    chat: _chat,
                    daemon: widget.daemon,
                    shown: shown,
                    tabsKey: widget.tabsKey,
                    expanded: widget.expanded,
                    onExpand: widget.onExpand,
                    onClose: widget.onClose,
                  ),
                  // With the tree on the left the path starts past it,
                  // over the viewer.
                  ValueListenableBuilder(
                    valueListenable: paneWidths,
                    builder: (context, _, _) => FilesBar(
                      chat: _chat,
                      daemon: widget.daemon,
                      shown: shown,
                      treeShows: named,
                      treeOut: tree && !named,
                      start: tree && !right
                          ? (_treeDragged ??
                                    paneWidth('filesTree', filesTreeInitial))
                                .clamp(least, max(least, most))
                          : 0,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // Squeezed out, the tree isn't built: laid out at
                      // no width, its search field and rows would still
                      // sit past the pane's edge, and Tab could reach them.
                      children: [
                        if (named && !right) files,
                        viewer,
                        if (named && right) files,
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
}

/// The viewer with no file open, as Claude desktop's: a folder, "Open
/// files appear here" and how to open one; without the [tree] (a daemon
/// older than it, or one squeezed out), the way that's there, Go to file's
/// key.
class FilesBlank extends StatelessWidget {
  const new({required this.tree, super.key});

  final bool tree;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ColoredBox(
      color: t.base,
      // Squeezed narrow, the words wrap taller than the viewer: they
      // scroll, rather than overflowing.
      child: Center(
        child: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(NushiTheme.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LineIcon.folder.view(size: 20, color: t.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Open files appear here',
                    textAlign: TextAlign.center,
                    style: theme.ui(t.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    switch ((tree, keyLabel(openFileKey))) {
                      (true, _) =>
                        'Pick a file in the tree, or click a file path in '
                            'the conversation',
                      // Open file's key cleared.
                      (false, '') => 'Click a file path in the conversation',
                      (false, final key) =>
                        'Go to a file with $key, or click a file path in '
                            'the conversation',
                    },
                    textAlign: TextAlign.center,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [path] (as the preview names it) as [chat]'s Files pane does, relative
/// to the chat's folder; null for a file outside it, or a daemon without
/// the pane.
String? inFiles(Daemon daemon, ChatState chat, String path) {
  if (daemon.daemonApi < filesApi) return null;
  final folder = '${chat.folder}/';
  final inside = path.startsWith('/')
      ? (path.startsWith(folder) ? path.substring(folder.length) : null)
      : path.replaceFirst(RegExp(r'^(\./)+'), '');
  return inside == null || inside.isEmpty ? null : inside;
}

/// Shows [inFiles]' file in [chat]'s Files pane: the pane opens on the Chat
/// tab, the tree shows if it was hidden (⇧⌘Y), the folders above it open,
/// its row selected and scrolled to.
void showInFiles(ChatState chat, String inside) {
  filesTree.value = true;
  folderTreeOf(chat).reveal(inside);
  chat.tab.value = ChatTab.chat;
  if (!filesOpen(chat)) toggleFiles(chat);
}

/// The chat header's Files button, lit while the pane shows, as the
/// terminal's and the details' are.
class FilesButton extends StatelessWidget {
  const new({required this.chat, super.key});

  final ChatState chat;

  /// Its tooltip: Show files or Hide files, and the key.
  static String tooltip({required bool shown}) =>
      withKey('${shown ? 'Hide' : 'Show'} files', keyLabel(filesKey));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([filesChats, chat.tab]),
    builder: (context, _) {
      final shown = filesShown(chat);
      return IconTap.line(
        LineIcon.folder,
        tooltip: tooltip(shown: shown),
        padding: IconTap.header,
        lit: shown,
        onTap: () => showOrHideFiles(chat),
      );
    },
  );
}
