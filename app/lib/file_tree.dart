import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A row of the changed files: a folder (no [file]) or a file.
class ChangeRow {
  new folder(this.path, this.name, this.depth, this.added, this.removed)
    : file = null;
  new file(FileChange this.file, this.name, this.depth)
    : path = file.path,
      added = file.added,
      removed = file.removed;

  final String path;
  final String name; // a file's name (its path when flat), or folders
  final int depth;
  final FileChange? file;
  final int added;
  final int removed;
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
/// between files, and the selected one stays in view. Rows are as wide as
/// their names, never cut: the list scrolls sideways, as JetBrains' tree
/// does, when the widest is wider than the pane.
class FileList extends StatefulWidget {
  const new({
    required this.files,
    required this.selected,
    required this.onSelect,
    super.key,
    this.marks = const {},
  });

  final List<FileChange> files;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Map<String, int> marks; // review comments, by file

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  static const _row = 26.0;
  static const _pad = 6.0; // the list's, each side
  final _scroll = ScrollController();
  final _sideways = ScrollController();
  final _focus = FocusNode();
  final _collapsed = <String>{};
  final _widths = <String, double>{}; // rows' widths, by what they show
  List<ChangeRow> _rows = [];

  @override
  void didUpdateWidget(FileList old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _widths.clear(); // the text's size may have changed
  }

  @override
  void dispose() {
    _scroll.dispose();
    _sideways.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _reveal() {
    final i = _rows.indexWhere((r) => r.file?.path == widget.selected);
    if (i < 0 || !_scroll.hasClients) return;
    final p = _scroll.position;
    final top = i * _row;
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

  /// The width of the widest row.
  double _widest(NushiTheme theme, bool flat) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final r in _rows) {
      final comments = widget.marks[r.file?.path] ?? 0;
      final key =
          '${r.depth} ${r.file != null} $flat $comments '
          '${r.added} ${r.removed} ${r.name}';
      final w = _widths[key] ??= () {
        final p = TextPainter(
          // As Text lays it out: over the default text style.
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [_label(theme, r, flat: flat, comments: comments)],
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final w = _Row.indent(r) + _Row.lead + p.width + _Row.end;
        p.dispose();
        return w.ceilToDouble();
      }();
      widest = max(widest, w);
    }
    return widest + 2 * _pad;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: changesFlat,
    builder: (context, flat, _) {
      _rows = changeRows(widget.files, flat: flat, collapsed: _collapsed);
      final widest = _widest(NushiTheme.of(context), flat);
      return Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        child: LayoutBuilder(
          builder: (context, box) => MacScrollbar(
            controller: _scroll,
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            child: MacScrollbar(
              controller: _sideways,
              notificationPredicate: (n) =>
                  n.depth == 0 && n.metrics.axis == Axis.horizontal,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _sideways,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: max(box.maxWidth, widest),
                    child: _list(flat),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _list(bool flat) => ListView.builder(
    controller: _scroll,
    itemExtent: _row,
    padding: const EdgeInsets.symmetric(horizontal: _pad),
    itemCount: _rows.length,
    itemBuilder: (context, i) {
      final row = _rows[i];
      return _Row(
        row,
        flat: flat,
        selected: row.file != null && row.path == widget.selected,
        open: !_collapsed.contains(row.path),
        comments: widget.marks[row.file?.path] ?? 0,
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
  );
}

/// A row's text: its name (a flat list's folders muted), its review
/// comments and its line counts.
TextSpan _label(
  NushiTheme theme,
  ChangeRow row, {
  required bool flat,
  required int comments,
}) {
  final t = theme.t;
  final file = row.file;
  final slash = flat && file != null ? row.name.lastIndexOf('/') + 1 : 0;
  const mark = Icons.mode_comment_outlined;
  return TextSpan(
    style: theme.ui(t.text),
    children: [
      TextSpan(
        text: row.name.substring(0, slash),
        style: theme.ui(t.textMuted),
      ),
      TextSpan(
        text: row.name.substring(slash),
        style: theme.ui(file == null ? t.textSecondary : t.text),
      ),
      if (comments > 0) ...[
        TextSpan(
          text: '  ${String.fromCharCode(mark.codePoint)}',
          style: TextStyle(
            fontFamily: mark.fontFamily,
            package: mark.fontPackage,
            fontSize: 12,
            color: t.accentInk,
          ),
        ),
        TextSpan(text: ' $comments', style: theme.ui(t.accentInk, size: 11)),
      ],
      const TextSpan(text: ' '),
      ...lineCounts(theme, row.added, row.removed),
    ],
  );
}

class _Row extends StatelessWidget {
  const new(
    this.row, {
    required this.flat,
    required this.selected,
    required this.open,
    required this.comments,
    required this.onTap,
  });

  final ChangeRow row;
  final bool flat;
  final bool selected;
  final bool open;
  final int comments;
  final VoidCallback onTap;

  /// Before the text: the indent, then the chevron or status letter's
  /// column; after it, the end's padding.
  static double indent(ChangeRow row) => 8.0 + row.depth * 14;
  static const lead = 18.0;
  static const end = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final file = row.file;
    final (letter, color) = switch (file?.status) {
      'added' => ('A', t.done),
      'untracked' => ('U', t.done),
      'deleted' => ('D', t.crashed),
      'renamed' => ('R', t.running),
      _ => ('M', t.running),
    };
    final notes = comments == 0
        ? ''
        : ' · $comments review comment${comments == 1 ? '' : 's'}';
    return Tap(
      onTap: onTap,
      selected: selected,
      tooltip: file == null
          ? ''
          : file.status == 'renamed'
          ? '${file.oldPath} → ${file.path}$notes'
          : '${file.path}$notes',
      padding: EdgeInsets.only(left: indent(row), right: end),
      child: Row(
        children: [
          SizedBox(
            width: lead,
            child: file == null
                ? Chevron(open: open)
                : Text(letter, style: theme.code(color, size: 12)),
          ),
          Text.rich(
            _label(theme, row, flat: flat, comments: comments),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

/// `+3 −1` in green and red, each left out when zero.
List<TextSpan> lineCounts(NushiTheme theme, int added, int removed) => [
  if (added > 0)
    TextSpan(text: ' +$added', style: theme.code(theme.t.done, size: 11)),
  if (removed > 0)
    TextSpan(text: ' −$removed', style: theme.code(theme.t.crashed, size: 11)),
];

/// [lineCounts] as a widget.
class LineCounts extends StatelessWidget {
  const new(this.added, this.removed, {super.key});

  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: lineCounts(NushiTheme.of(context), added, removed)),
  );
}
