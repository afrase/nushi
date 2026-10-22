import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart';
import 'markdown.dart';
import 'theme/theme.dart';

const _icons = {
  'read': Icons.description_outlined,
  'edit': Icons.edit_outlined,
  'delete': Icons.delete_outline,
  'move': Icons.drive_file_move_outline,
  'search': Icons.search,
  'execute': Icons.terminal,
  'think': Icons.psychology_outlined,
  'fetch': Icons.public,
};

bool _running(Item it) => it.status == 'pending' || it.status == 'in_progress';

/// Lines added and removed by [d].
(int, int) lineCounts(FileChange d) {
  final ids = <String, int>{};
  List<int> lines(String s) => [
    if (s.isNotEmpty)
      for (final l in s.split('\n')) ids.putIfAbsent(l, () => ids.length),
  ];
  final ops = myersDiff(lines(d.oldText), lines(d.newText));
  return (
    ops.where((o) => o == EditOp.insert).length,
    ops.where((o) => o == EditOp.delete).length,
  );
}

/// What a run of tool calls did: "Read 4 files, ran 2 commands".
String groupLabel(List<Item> calls) {
  final counts = <String, int>{};
  for (final c in calls) {
    counts.update(c.toolKind, (n) => n + 1, ifAbsent: () => 1);
  }
  String n(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final label = [
    for (final MapEntry(key: kind, value: c) in counts.entries)
      switch (kind) {
        'read' => 'read ${n(c, 'file', 'files')}',
        'edit' => 'edited ${n(c, 'file', 'files')}',
        'delete' => 'deleted ${n(c, 'file', 'files')}',
        'move' => 'moved ${n(c, 'file', 'files')}',
        'execute' => 'ran ${n(c, 'command', 'commands')}',
        'search' => 'ran ${n(c, 'search', 'searches')}',
        'fetch' => 'fetched ${n(c, 'page', 'pages')}',
        'think' => 'thought',
        _ => 'used ${n(c, 'tool', 'tools')}',
      },
  ].join(', ');
  return label[0].toUpperCase() + label.substring(1);
}

/// A card with a one-line header that opens to show [body]; outlined in
/// red when [failed].
class _Collapsible extends StatefulWidget {
  const _Collapsible({
    required this.header,
    required this.body,
    required this.failed,
  });

  final Widget header;
  final Widget? body;
  final bool failed;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final body = widget.body;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: widget.failed ? t.crashed : t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: body == null ? null : () => setState(() => _open = !_open),
            child: Container(
              height: 28,
              color: widget.failed ? t.crashedSoft : t.raised,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: body == null
                        ? null
                        : Icon(
                            _open ? Icons.expand_more : Icons.chevron_right,
                            size: 14,
                            color: t.textSecondary,
                          ),
                  ),
                  Expanded(child: widget.header),
                ],
              ),
            ),
          ),
          if (_open && body != null) body,
        ],
      ),
    );
  }
}

/// The end of a tool call's header: a spinner while it runs, "failed" in
/// red when it failed.
class _Status extends StatelessWidget {
  const _Status({required this.running, required this.failed});

  final bool running;
  final String failed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(failed, style: theme.ui(theme.t.crashed, size: 12)),
        if (running)
          const SizedBox.square(
            dimension: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
      ],
    );
  }
}

/// One tool call: a one-line summary by kind (the file read or edited, the
/// command run, `+n −m` for an edit) that opens to its output and diffs.
class ToolCallView extends StatelessWidget {
  const ToolCallView(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = item;
    final code = theme.code(t.text, size: 12).copyWith(height: 1.2);
    final path = it.paths.firstOrNull ?? it.diffs.firstOrNull?.path;
    final verb = switch (it.toolKind) {
      'read' => 'Read',
      'edit' => 'Edit',
      'delete' => 'Delete',
      'move' => 'Move',
      _ => null,
    };
    final InlineSpan title = it.toolKind == 'execute'
        ? TextSpan(text: '\$ ${it.title}', style: code)
        : verb != null && path != null
        ? TextSpan(
            children: [
              TextSpan(text: '$verb ', style: theme.ui(t.textSecondary)),
              TextSpan(text: path, style: code),
            ],
          )
        : TextSpan(text: it.title, style: theme.ui(t.textSecondary));
    var (added, removed) = (0, 0);
    for (final d in it.diffs) {
      final (a, r) = lineCounts(d);
      added += a;
      removed += r;
    }
    final failed = it.status == 'failed';
    final hasBody = it.text.isNotEmpty || it.diffs.isNotEmpty;
    return _Collapsible(
      failed: failed,
      header: Row(
        children: [
          Icon(
            _icons[it.toolKind] ?? Icons.build_outlined,
            size: 13,
            color: failed ? t.crashed : t.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (it.diffs.isNotEmpty) ...[
            Text('+$added', style: code.copyWith(fontSize: 11, color: t.done)),
            const SizedBox(width: 4),
            Text(
              '−$removed',
              style: code.copyWith(fontSize: 11, color: t.crashed),
            ),
          ],
          const SizedBox(width: 8),
          _Status(running: _running(it), failed: failed ? 'failed' : ''),
        ],
      ),
      body: !hasBody
          ? null
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final d in it.diffs) EditDiff(d),
                  if (it.text.isNotEmpty) AgentMarkdown(it.text),
                ],
              ),
            ),
    );
  }
}

/// A run of tool calls as one line ("Read 4 files, ran 2 commands") that
/// opens to each call.
class ToolGroupView extends StatelessWidget {
  const ToolGroupView(this.calls, {super.key});

  final List<Item> calls;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final failed = calls.where((c) => c.status == 'failed').length;
    return _Collapsible(
      failed: false, // its failed calls stand out inside, and in the count
      header: Row(
        children: [
          Icon(Icons.layers_outlined, size: 13, color: t.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              groupLabel(calls),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          _Status(
            running: calls.any(_running),
            failed: failed == 0 ? '' : '$failed failed',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            for (final c in calls) ToolCallView(c, key: ValueKey(c.id)),
          ],
        ),
      ),
    );
  }
}

/// An edit's diff, side by side and only as tall as the edit (up to about
/// fifteen lines, then it scrolls).
class EditDiff extends StatefulWidget {
  const EditDiff(this.change, {super.key});

  final FileChange change;

  @override
  State<EditDiff> createState() => _EditDiffState();
}

class _EditDiffState extends State<EditDiff> {
  DiffViewController? _controller;
  late DiffThemeData _theme;
  double _height = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _build();
  }

  @override
  void didUpdateWidget(EditDiff old) {
    super.didUpdateWidget(old);
    if (old.change != widget.change) _build();
  }

  void _build() {
    final d = widget.change;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _theme = Theme.of(context).brightness == Brightness.dark
        ? DiffThemeData.dark()
        : DiffThemeData.light();
    final diff = TextDiff.compute(d.oldText, d.newText, path: d.path);
    _controller?.dispose();
    _controller = DiffViewController(
      document: diff.document,
      lines: diff.lines,
      theme: _theme,
      devicePixelRatio: dpr,
    );
    final rows = diff.document.oldLineCount > diff.document.newLineCount
        ? diff.document.oldLineCount
        : diff.document.newLineCount;
    _height = _theme.lineHeightFor(dpr) * rows.clamp(1, 15) + 6;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: t.borderSubtle),
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: SideBySideDiff(
        controller: _controller!,
        theme: _theme,
        inlayBuilder: (context, spec) => const SizedBox.shrink(),
      ),
    );
  }
}
