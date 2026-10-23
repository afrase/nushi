import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A row of the changed files: a folder (no [file]) or a file.
class ChangeRow {
  ChangeRow.folder(this.path, this.name, this.depth, this.added, this.removed)
    : file = null;
  ChangeRow.file(FileChange this.file, this.name, this.depth)
    : path = file.path,
      added = file.added,
      removed = file.removed;

  final String path;
  final String name; // a file's name (its path when flat), or folders
  final int depth;
  final FileChange? file;
  final int added, removed;
}

class _Folder {
  final folders = <String, _Folder>{};
  final files = <FileChange>[];

  (int, int) get totals {
    var (a, r) = (0, 0);
    for (final f in files) {
      (a, r) = (a + f.added, r + f.removed);
    }
    for (final d in folders.values) {
      final (da, dr) = d.totals;
      (a, r) = (a + da, r + dr);
    }
    return (a, r);
  }
}

/// The rows of [files] (sorted by path): with [flat] the files alone, else
/// a tree, folders first, a chain of single folders as one (`app/lib`),
/// without what's inside the [collapsed] folders.
List<ChangeRow> changeRows(
  List<FileChange> files, {
  required bool flat,
  Set<String> collapsed = const {},
}) {
  if (flat) return [for (final f in files) ChangeRow.file(f, f.path, 0)];
  final root = _Folder();
  for (final f in files) {
    final parts = f.path.split('/');
    var d = root;
    for (final p in parts.take(parts.length - 1)) {
      d = d.folders[p] ??= _Folder();
    }
    d.files.add(f);
  }
  final rows = <ChangeRow>[];
  void walk(_Folder d, String parent, int depth) {
    for (final name in d.folders.keys.toList()..sort()) {
      var (label, sub) = (name, d.folders[name]!);
      while (sub.files.isEmpty && sub.folders.length == 1) {
        final MapEntry(:key, :value) = sub.folders.entries.single;
        (label, sub) = ('$label/$key', value);
      }
      final path = '$parent$label';
      final (a, r) = sub.totals;
      rows.add(ChangeRow.folder(path, label, depth, a, r));
      if (!collapsed.contains(path)) walk(sub, '$path/', depth + 1);
    }
    for (final f in d.files) {
      rows.add(ChangeRow.file(f, f.path.split('/').last, depth));
    }
  }

  walk(root, '', 0);
  return rows;
}

/// The changed files as a tree or a flat list ([changesFlat]): ↑/↓ move
/// between files, and the selected one stays in view.
class FileList extends StatefulWidget {
  const FileList({
    super.key,
    required this.files,
    required this.selected,
    required this.onSelect,
  });

  final List<FileChange> files;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  static const _row = 26.0;
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _collapsed = <String>{};
  List<ChangeRow> _rows = [];

  @override
  void didUpdateWidget(FileList old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reveal() {
    final i = _rows.indexWhere((r) => r.file?.path == widget.selected);
    if (i < 0 || !_scroll.hasClients) return;
    final p = _scroll.position, top = i * _row;
    if (top < p.pixels) {
      p.jumpTo(top);
    } else if (top + _row > p.pixels + p.viewportDimension) {
      p.jumpTo(top + _row - p.viewportDimension);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (e is KeyUpEvent ||
        !down && e.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final files = [for (final r in _rows) ?r.file?.path];
    final i = files.indexOf(widget.selected ?? '');
    final next = i < 0 ? 0 : (i + (down ? 1 : -1)).clamp(0, files.length - 1);
    if (files.isNotEmpty) widget.onSelect(files[next]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: changesFlat,
    builder: (context, flat, _) {
      _rows = changeRows(widget.files, flat: flat, collapsed: _collapsed);
      return Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        child: ListView.builder(
          controller: _scroll,
          itemExtent: _row,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          itemCount: _rows.length,
          itemBuilder: (context, i) {
            final row = _rows[i];
            return _Row(
              row,
              flat: flat,
              selected: row.file != null && row.path == widget.selected,
              open: !_collapsed.contains(row.path),
              onTap: () {
                _focus.requestFocus();
                if (row.file == null) {
                  setState(() {
                    if (!_collapsed.remove(row.path)) _collapsed.add(row.path);
                  });
                } else {
                  widget.onSelect(row.path);
                }
              },
            );
          },
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row(
    this.row, {
    required this.flat,
    required this.selected,
    required this.open,
    required this.onTap,
  });

  final ChangeRow row;
  final bool flat, selected, open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final file = row.file;
    final (letter, color) = switch (file?.status) {
      'added' => ('A', t.done),
      'untracked' => ('U', t.done),
      'deleted' => ('D', t.crashed),
      'renamed' => ('R', t.running),
      _ => ('M', t.running),
    };
    final slash = row.name.lastIndexOf('/') + 1;
    return Tap(
      onTap: onTap,
      selected: selected,
      tooltip: file == null
          ? ''
          : file.status == 'renamed'
          ? '${file.oldPath} → ${file.path}'
          : file.path,
      padding: EdgeInsets.only(left: 8.0 + row.depth * 14, right: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: file == null
                ? Icon(
                    open ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: t.textMuted,
                  )
                : Text(letter, style: theme.code(color, size: 12)),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (file != null && flat)
                    TextSpan(
                      text: row.name.substring(0, slash),
                      style: theme.ui(t.textMuted),
                    ),
                  TextSpan(
                    text: file != null && flat
                        ? row.name.substring(slash)
                        : row.name,
                    style: theme.ui(file == null ? t.textSecondary : t.text),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          LineCounts(row.added, row.removed),
        ],
      ),
    );
  }
}

/// `+3 −1` in green and red, each left out when zero.
class LineCounts extends StatelessWidget {
  const LineCounts(this.added, this.removed, {super.key});

  final int added, removed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    return Text.rich(
      TextSpan(
        children: [
          if (added > 0)
            TextSpan(text: ' +$added', style: theme.code(t.done, size: 11)),
          if (removed > 0)
            TextSpan(
              text: ' −$removed',
              style: theme.code(t.crashed, size: 11),
            ),
        ],
      ),
    );
  }
}
