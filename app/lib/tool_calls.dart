import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'images.dart';
import 'markdown.dart';
import 'theme/theme.dart';
import 'widgets.dart';

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

/// What each kind of tool call did, and to what.
const _did = {
  'read': ('read', 'file'),
  'edit': ('edited', 'file'),
  'delete': ('deleted', 'file'),
  'move': ('moved', 'file'),
  'execute': ('ran', 'command'),
  'search': ('ran', 'search'),
  'fetch': ('fetched', 'page'),
  'other': ('used', 'tool'),
};

/// What a run of tool calls did: "Read 4 files, ran 2 commands".
String groupLabel(List<Item> calls) {
  final counts = <String, int>{};
  for (final c in calls) {
    final kind = _did.containsKey(c.toolKind) ? c.toolKind : 'other';
    counts.update(kind, (n) => n + 1, ifAbsent: () => 1);
  }
  final label = [
    for (final MapEntry(key: kind, value: n) in counts.entries)
      if (_did[kind] case (final verb, final what))
        '$verb $n $what${n == 1
            ? ''
            : what.endsWith('h')
            ? 'es'
            : 's'}',
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
      decoration: box(widget.failed ? t.crashed : t.borderSubtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: widget.failed ? t.crashedSoft : t.raised,
            child: Tap(
              onTap: body == null ? null : () => setState(() => _open = !_open),
              radius: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 28,
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
          ),
          if (_open && body != null) body,
        ],
      ),
    );
  }
}

/// The end of a tool call's header: [failed] in red, and a spinner while
/// it runs.
Widget _status(NushiTheme theme, {required bool running, String failed = ''}) =>
    Row(
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

/// One tool call: a one-line summary by kind (the file read or edited, the
/// command run, `+n −m` for an edit) that opens to its output and diffs.
class ToolCallView extends StatelessWidget {
  const ToolCallView(
    this.item, {
    super.key,
    this.images = true,
    this.still = false,
  });

  final Item item;

  /// Whether the agent waits on the user: nothing spins.
  final bool still;

  /// Whether its images show under it (a run of calls shows them itself).
  final bool images;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
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
    return _withImages(
      [if (images) ...it.images],
      _Collapsible(
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
              Text(
                '+$added',
                style: code.copyWith(fontSize: 11, color: t.done),
              ),
              const SizedBox(width: 4),
              Text(
                '−$removed',
                style: code.copyWith(fontSize: 11, color: t.crashed),
              ),
            ],
            const SizedBox(width: 8),
            _status(
              theme,
              running: _running(it) && !still,
              failed: failed ? 'failed' : '',
            ),
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
                    for (final d in it.diffs) DiffBox(d),
                    if (it.text.isNotEmpty) AgentMarkdown(it.text),
                  ],
                ),
              ),
      ),
    );
  }
}

/// A tool call, or a run of them, with the images they returned under it.
Widget _withImages(List<ImageData> images, Widget child) => images.isEmpty
    ? child
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          child,
          Align(
            alignment: Alignment.centerLeft,
            child: Thumbnails(images, size: 240),
          ),
        ],
      );

/// A run of tool calls as one line ("Read 4 files, ran 2 commands") that
/// opens to each call.
class ToolGroupView extends StatelessWidget {
  const ToolGroupView(this.calls, {super.key, this.still = false});

  final List<Item> calls;
  final bool still; // as ToolCallView's

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final failed = calls.where((c) => c.status == 'failed').length;
    return _withImages(
      [for (final c in calls) ...c.images],
      _Collapsible(
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
            _status(
              theme,
              running: calls.any(_running) && !still,
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
              for (final c in calls)
                ToolCallView(
                  c,
                  key: ValueKey(c.id),
                  images: false,
                  still: still,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
