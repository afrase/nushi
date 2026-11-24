import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/double_clicks.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_dots.dart';
import 'package:nushi/tree_rows.dart';
import 'package:nushi/widgets.dart';

/// The Files pane's tree (ADR 0090, 0123): the chat's folder (its
/// worktree's, for a worktree chat), at the window's edge right of the
/// pane's viewer. Folders open as they're clicked (or with →, ← closing
/// them), listed by the daemon then and kept current ([FolderTree]); a file
/// that previews opens in the viewer, with a click or ⏎. A dot marks each
/// file that differs from what its change marks count from, and the
/// folders holding one ([TreeDots]; outside git, the files the chat
/// wrote). What git ignores is left out unless the eye shows it. The
/// filter over the tree finds any file in the folder by name, as a tree of
/// what matched. Read-only (ADR 0019).
class FilesTree extends StatefulWidget {
  const new({required this.chat, required this.daemon, super.key});

  final ChatState chat;
  final Daemon daemon;

  /// A row's height.
  static const row = 24.0;

  @override
  State<FilesTree> createState() => _FilesTreeState();
}

class _FilesTreeState extends State<FilesTree> {
  late final FolderTree _tree = folderTreeOf(widget.chat);
  late final TreeDots _dots = treeDotsOf(widget.chat);
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'files filter');
  final _list = FocusNode(debugLabel: 'files');
  final _scroll = ScrollController();

  GitFiles get _git => gitFilesOf(widget.daemon, widget.chat.folder);
  final _filter = FilterMemo();

  /// A file's row clicked twice keeps its tab (preview tabs, ADR 0070).
  final _clicks = DoubleClicks();

  /// The rows as last built: what the keys move through.
  List<TreeRow> _rows = const [];

  /// The filter's row the keys are on (its own: the tree's stays).
  String? _filterAt;

  @override
  void initState() {
    super.initState();
    _tree.attach(widget.daemon);
    _dots.attach(widget.daemon);
    _query.addListener(_queried);
  }

  @override
  void dispose() {
    _tree.detach();
    _dots.detach();
    _clicks.dispose();
    _query.dispose();
    _field.dispose();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim();

  void _queried() {
    _filterAt = null;
    if (_q.isNotEmpty) _git.ask();
    setState(() {});
  }

  String? get _at => _q.isEmpty ? _tree.selected : _filterAt;

  void _select(String path) {
    if (_q.isEmpty) {
      _tree.select(path);
    } else {
      setState(() => _filterAt = path);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(path));
  }

  void _reveal(String path) {
    final i = _rows.indexWhere((r) => r.entry && r.path == path);
    if (i >= 0) revealRowAt(_scroll, i, FilesTree.row);
  }

  /// A row clicked, or ⏎ on it: a folder opens or closes (in a filter's
  /// tree they're all open), a file opens in the viewer; a click's file,
  /// not [keep], in a provisional tab (preview tabs).
  void _activate(TreeRow r, {bool keep = true}) {
    _select(r.path);
    if (r.kind == TreeRowKind.folder && _q.isEmpty) {
      _tree.toggle(r.path);
    } else if (r.opens) {
      widget.chat.openInFiles(r.path, keep: keep);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final entries = [
      for (final r in _rows)
        if (r.entry) r,
    ];
    final i = entries.indexWhere((r) => r.path == _at);
    final row = i < 0 ? null : entries[i];
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp:
        if (entries.isEmpty) break;
        final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
        final next = i < 0
            ? 0
            : (i + (down ? 1 : -1)).clamp(0, entries.length - 1);
        _select(entries[next].path);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (row != null) _activate(row);
      case LogicalKeyboardKey.arrowRight
          when row?.kind == TreeRowKind.folder && _q.isEmpty:
        if (!row!.open) {
          _tree.setOpen(row.path, open: true);
        } else if (i + 1 < entries.length &&
            parentOf(entries[i + 1].path) == row.path) {
          _select(entries[i + 1].path);
        }
      case LogicalKeyboardKey.arrowLeft when row != null && _q.isEmpty:
        if (row.kind == TreeRowKind.folder && row.open) {
          _tree.setOpen(row.path, open: false);
        } else if (parentOf(row.path) case final up when up.isNotEmpty) {
          _select(up);
        }
      case LogicalKeyboardKey.escape when _q.isNotEmpty:
        _query.clear();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onKeyEvent: _key,
          skipTraversal: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: SizedBox(
              height: 26,
              child: TextField(
                controller: _query,
                focusNode: _field,
                style: theme.ui(t.text, size: 12),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search files…',
                  prefixIcon: Icon(Icons.search, size: 14, color: t.textMuted),
                  prefixIconConstraints: const BoxConstraints(minWidth: 26),
                  // What git ignores, shown or not: the tree's own switch.
                  suffixIcon: ValueListenableBuilder(
                    valueListenable: filesIgnored,
                    builder: (context, shown, _) => IconTap(
                      shown
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      tooltip: shown
                          ? 'Hide what git ignores'
                          : 'Show what git ignores',
                      size: 14,
                      padding: 4,
                      color: shown ? t.text : null,
                      onTap: () => filesIgnored.value = !shown,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 26),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Focus(
            focusNode: _list,
            onKeyEvent: _key,
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _tree,
                _dots,
                _git,
                widget.chat,
                widget.chat.files.shown,
              ]),
              builder: (context, _) => _body(theme),
            ),
          ),
        ),
      ],
    );
  }

  /// A file with the dot ([dotted]) has a right-click menu: Show changes
  /// opens it in the chat's Changes tab (ADR 0131). Others have none.
  Widget _dotted(
    TreeRow r, {
    required bool dotted,
    required Widget Function(GestureTapUpCallback? menu) builder,
  }) {
    if (!dotted) return builder(null);
    return Menu(
      filter: false,
      entries: [
        MenuEntry(
          'Show changes',
          icon: Icons.difference_outlined,
          onPick: () => widget.chat.showFile(r.path),
        ),
      ],
      builder: (context, open) => builder((d) => open(d.localPosition)),
    );
  }

  Widget _body(NushiTheme theme) {
    final t = theme.t;
    final marks = _dots.marks;
    final git = _dots.fromGit;
    var capped = false;
    if (_q.isNotEmpty) {
      final found = _filter.of(_tree, _git, _q);
      _rows = found.rows;
      capped = found.capped;
      if (_filterAt == null || !_rows.any((r) => r.path == _filterAt)) {
        _filterAt = found.best;
      }
      if (_rows.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Text('No file matches', style: theme.ui(t.textMuted)),
        );
      }
    } else {
      _rows = _tree.rows();
      // A file shown from elsewhere (the preview's name), once its row's
      // in, or the folder it'd be in.
      if (_tree.settleReveal(_rows) case final path? when path.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(path));
      }
    }
    final open = widget.chat.shownFile;
    return MacScrollbar(
      controller: _scroll,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            sliver: SliverFixedExtentList.builder(
              itemExtent: FilesTree.row,
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final r = _rows[i];
                final dot = dotWords(r, marks, git: git);
                // A second click on a file keeps its tab: its first opened
                // it, and the second's tap shows it again.
                return Listener(
                  onPointerDown: (e) {
                    if (r.opens && _clicks.down(r.path, e.position)) {
                      widget.chat.openInFiles(r.path);
                    }
                  },
                  child: _dotted(
                    r,
                    dotted: dot != null && r.kind != TreeRowKind.folder,
                    builder: (menu) => TreeRowView(
                      r,
                      selected: r.entry && r.path == _at,
                      showing: r.kind == TreeRowKind.file && r.path == open,
                      dot: dot,
                      onSecondaryTapUp: menu,
                      onTap: r.entry
                          ? () {
                              _list.requestFocus();
                              _activate(r, keep: false);
                            }
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          // More matched than the filter shows: Claude desktop's words, an
          // explanation, so its full stops (docs/design.md).
          if (capped)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Some entries may not be listed. Keep typing to narrow.',
                  style: theme.ui(t.textMuted, size: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
