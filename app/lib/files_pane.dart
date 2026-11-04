import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/file_filter.dart';
import 'package:nushi/folder_tree.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tree_rows.dart';
import 'package:nushi/widgets.dart';

/// Opens [chat]'s Files pane, or closes it.
void toggleFiles(ChatState chat) {
  final open = {...filesChats.value};
  if (!open.remove(chat.id)) open.add(chat.id);
  filesChats.value = open;
}

/// The Files pane: a tree of the chat's folder (its worktree's, for a
/// worktree chat), beside the chat. Folders open as they're clicked (or
/// with →, ← closing them), listed by the daemon then and kept current
/// ([FolderTree]); a file that previews opens in the preview, as an
/// artifact does, with a click or ⏎. The files the chat wrote are marked,
/// and the folders holding them. What git ignores is left out unless the
/// eye in its header shows it. The filter over the tree finds any file in
/// the folder by name, as a tree of what matched. Read-only (ADR 0019).
class FilesPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onClose;

  /// A row's height.
  static const row = 24.0;

  @override
  State<FilesPane> createState() => _FilesPaneState();
}

class _FilesPaneState extends State<FilesPane> {
  late final FolderTree _tree = folderTreeOf(widget.chat);
  final _query = TextEditingController();
  final _field = FocusNode(debugLabel: 'files filter');
  final _list = FocusNode(debugLabel: 'files');
  final _scroll = ScrollController();

  final _git = GitFiles();

  /// The rows as last built: what the keys move through.
  List<TreeRow> _rows = const [];

  /// The filter's row the keys are on (its own: the tree's stays).
  String? _filterAt;

  @override
  void initState() {
    super.initState();
    _tree.attach(widget.daemon);
    _query.addListener(_queried);
  }

  @override
  void dispose() {
    _tree.detach();
    _query.dispose();
    _git.dispose();
    _field.dispose();
    _list.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim();

  void _queried() {
    _filterAt = null;
    if (_q.isNotEmpty) _git.ask(widget.daemon, widget.chat.folder);
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
    if (i < 0 || !_scroll.hasClients) return;
    final p = _scroll.position;
    final top = i * FilesPane.row;
    if (top < p.pixels) {
      p.jumpTo(top);
    } else if (top + FilesPane.row > p.pixels + p.viewportDimension) {
      p.jumpTo(top + FilesPane.row - p.viewportDimension);
    }
  }

  /// A row clicked, or ⏎ on it: a folder opens or closes (in a filter's
  /// tree they're all open), a file previews.
  void _activate(TreeRow r) {
    _select(r.path);
    if (r.kind == TreeRowKind.folder && _q.isEmpty) {
      _tree.toggle(r.path);
    } else if (r.opens) {
      widget.chat.openPreview(r.path);
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
        PaneHeader(
          inset: 14,
          end: 8,
          child: Row(
            spacing: 6,
            children: [
              Icon(Icons.folder_outlined, size: 14, color: t.textSecondary),
              Text('Files', style: theme.ui(t.text, weight: FontWeight.w500)),
              Expanded(
                child: Text(
                  baseName(widget.chat.folder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.code(t.textMuted, size: 12),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: filesIgnored,
                builder: (context, shown, _) => IconTap(
                  shown
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  tooltip: shown
                      ? 'Hide what git ignores'
                      : 'Show what git ignores',
                  size: 15,
                  color: shown ? t.text : null,
                  onTap: () => filesIgnored.value = !shown,
                ),
              ),
              IconTap.line(
                LineIcon.close,
                tooltip: 'Close',
                size: 15,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
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
                  hintText: 'Filter files',
                  prefixIcon: Icon(Icons.search, size: 14, color: t.textMuted),
                  prefixIconConstraints: const BoxConstraints(minWidth: 26),
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
                _git,
                widget.chat,
                widget.chat.preview,
              ]),
              builder: (context, _) => _body(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(NushiTheme theme) {
    final t = theme.t;
    final marks = writtenMarks(widget.chat);
    if (_q.isNotEmpty) {
      final found = filterRows(filterPaths(_tree, _git.paths), _q);
      _rows = found.rows;
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
    }
    final open = widget.chat.preview.value;
    return MacScrollbar(
      controller: _scroll,
      child: ListView.builder(
        controller: _scroll,
        itemExtent: FilesPane.row,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final r = _rows[i];
          return TreeRowView(
            r,
            selected: r.entry && r.path == _at,
            showing: r.kind == TreeRowKind.file && r.path == open,
            wrote: r.kind == TreeRowKind.folder
                ? marks.folders.contains(r.path)
                : marks.files.contains(r.path),
            onTap: r.entry
                ? () {
                    _list.requestFocus();
                    _activate(r);
                  }
                : null,
          );
        },
      ),
    );
  }
}

/// Whether [chat]'s Files pane is open: a [Listenable] with it.
bool filesOpen(ChatState chat) => filesChats.value.contains(chat.id);
