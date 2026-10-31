import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';

import 'package:nushi/collapsible.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/images.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart';
import 'package:nushi/typed.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/collapsible.dart';
export 'package:nushi/tool_parts.dart';

/// What a kind of tool call does: its icon, what it did ("read") to what
/// ("file"), its verb on a path ("Read") and what it is doing ("Reading").
class ToolKind {
  const new(this.icon, this.did, this.what, [this.verb, this.doing]);

  final IconData icon;
  final String did;
  final String what;
  final String? verb;
  final String? doing;
}

/// The ACP kinds of tool calls.
const _kinds = {
  'read': ToolKind(
    Icons.description_outlined,
    'read',
    'file',
    'Read',
    'Reading',
  ),
  'edit': ToolKind(Icons.edit_outlined, 'edited', 'file', 'Edit', 'Editing'),
  'delete': ToolKind(
    Icons.delete_outline,
    'deleted',
    'file',
    'Delete',
    'Deleting',
  ),
  'move': ToolKind(
    Icons.drive_file_move_outline,
    'moved',
    'file',
    'Move',
    'Moving',
  ),
  'search': ToolKind(Icons.search, 'ran', 'search', null, 'Searching'),
  'execute': ToolKind(Icons.terminal, 'ran', 'command'),
  'think': ToolKind(Icons.psychology_outlined, 'used', 'tool'),
  'fetch': ToolKind(Icons.public, 'fetched', 'page', null, 'Fetching'),
};

/// A show call, whatever kind its agent gives it (Codex's are `execute`).
const _showKind = ToolKind(
  Icons.visibility_outlined,
  'showed',
  'file',
  'Showed',
  'Showing',
);

/// The kind of tool call [it] is.
ToolKind kindOf(Item it) => isShow(it)
    ? _showKind
    : _kinds[it.toolKind] ??
          const ToolKind(Icons.build_outlined, 'used', 'tool');

bool _running(Item it) => it.status == 'pending' || it.status == 'in_progress';

/// What a running call is doing: "Reading notes.md", "Running make test".
String doingOf(Item it) {
  final path = _named(it);
  final verb = kindOf(it).doing;
  return switch ((verb, path)) {
    _ when isCommand(it) => 'Running ${it.title}',
    (final v?, final p?) => '$v $p',
    (final v?, null) => v,
    _ => toolTitle(it),
  };
}

final _counted = Expando<(int, int)>();

/// Lines added and removed by [d], counted once per change. A change too
/// long to diff on the UI thread (DiffBox diffs it in an isolate) counts
/// lines by how often each occurs on either side: the same numbers but
/// for lines that moved, in a few milliseconds, not seconds.
(int, int) lineCounts(FileChange d) => _counted[d] ??= _count(d);

(int, int) _count(FileChange d) {
  List<String> lines(String s) => s.isEmpty ? [] : s.split('\n');
  if (d.oldText.length + d.newText.length >= offThread) {
    final n = <String, int>{};
    for (final l in lines(d.newText)) {
      n[l] = (n[l] ?? 0) + 1;
    }
    for (final l in lines(d.oldText)) {
      n[l] = (n[l] ?? 0) - 1;
    }
    return (
      n.values.where((v) => v > 0).fold(0, (a, v) => a + v),
      n.values.where((v) => v < 0).fold(0, (a, v) => a - v),
    );
  }
  final ids = <String, int>{};
  List<int> numbered(String s) => [
    for (final l in lines(s)) ids.putIfAbsent(l, () => ids.length),
  ];
  final ops = myersDiff(numbered(d.oldText), numbered(d.newText));
  return (
    ops.where((o) => o == EditOp.insert).length,
    ops.where((o) => o == EditOp.delete).length,
  );
}

/// What a call's title names: its file, a show call's by its name alone.
String? _named(Item it) => isShow(it)
    ? switch (showPath(it)) {
        final p? => baseName(p),
        null => null,
      }
    : it.paths.firstOrNull ?? it.diffs.firstOrNull?.path;

/// The file a tool call wrote or edited, when it's an artifact
/// ([isArtifact]): code gets no Preview button. Or the one a show call
/// opened, once it did: the daemon refused any other, and a call still
/// waiting to be allowed offers nothing.
String? previewPath(Item it) {
  if (isShow(it)) {
    final shown = showPath(it);
    return it.status == 'completed' && shown != null && isArtifact(shown)
        ? shown
        : null;
  }
  final path = it.paths.firstOrNull ?? it.diffs.firstOrNull?.path;
  final wrote = it.toolKind == 'edit' || it.diffs.isNotEmpty;
  return wrote && it.status != 'failed' && path != null && isArtifact(path)
      ? path
      : null;
}

/// What a run of tool calls did: "Read 4 files, ran 2 commands".
String groupLabel(List<Item> calls) {
  final counts = <(String, String), int>{};
  for (final c in calls) {
    final k = kindOf(c);
    counts.update((k.did, k.what), (n) => n + 1, ifAbsent: () => 1);
  }
  final label = [
    for (final MapEntry(key: (verb, what), value: n) in counts.entries)
      '$verb $n $what${n == 1
          ? ''
          : what.endsWith('h')
          ? 'es'
          : 's'}',
  ].join(', ');
  return label[0].toUpperCase() + label.substring(1);
}

/// The end of a tool call's header: [failed] in red.
Widget _failed(NushiTheme theme, String failed) =>
    Text(failed, style: theme.ui(theme.t.crashed, size: 12));

/// One tool call: a one-line summary by kind (the file read or edited, the
/// command run, `+n −m` for an edit) that opens to its output and diffs.
class ToolCallView extends StatelessWidget {
  const new(this.item, {super.key, this.images = true, this.still = false});

  final Item item;

  /// Whether the agent waits on the user: nothing shines.
  final bool still;

  /// Whether its images show under it (a run of calls shows them itself).
  final bool images;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final it = item;
    final code = theme.code(t.text, size: 12).copyWith(height: 1.2);
    final show = isShow(it);
    final failed = it.status == 'failed';
    final path = _named(it);
    final verb = !show
        ? kindOf(it).verb
        : failed
        ? 'Show'
        : _running(it)
        ? kindOf(it).doing
        : kindOf(it).verb;
    final pathed =
        (show || it.toolKind != 'execute') && verb != null && path != null;
    final title = isCommand(it)
        ? TextSpan(text: '\$ ${it.title}', style: code)
        : pathed
        ? TextSpan(
            children: [
              TextSpan(text: '$verb ', style: theme.ui(t.textSecondary)),
              TextSpan(text: path, style: code),
            ],
          )
        : TextSpan(text: toolTitle(it), style: theme.ui(t.textSecondary));
    // An MCP call's title is its server and tool; its raw name on hover.
    final rawName = show
        ? showPath(it)
        : mcpName(it.title) == null
        ? null
        : it.title;
    var (added, removed) = (0, 0);
    for (final d in it.diffs) {
      final (a, r) = lineCounts(d);
      added += a;
      removed += r;
    }
    final command = isCommand(it);
    final preview = previewPath(it);
    final input = showsInput(it);
    final output = it.text.trim().isNotEmpty;
    return _withImages(
      [if (images) ...it.images],
      Collapsible(
        ids: [it.id],
        failed: failed,
        header: Row(
          children: [
            Icon(
              kindOf(it).icon,
              size: 13,
              color: failed ? t.crashed : t.toolAccent,
            ),
            const SizedBox(width: 6),
            // The title types out as the call comes (the path after the
            // verb), then shines while it runs, the band across the text
            // alone.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _tooltip(
                  rawName,
                  Typed(
                    title,
                    keep: pathed ? verb.length + 1 : 0,
                    shine: _running(it) && !still,
                  ),
                ),
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
            if (preview != null) ...[
              const SizedBox(width: 8),
              PreviewButton(preview),
            ],
            // The call ends; the command runs on (background_commands.dart).
            if (it.hasBackgroundCommand())
              Shine(
                on: it.backgroundCommand.state == 'running' && !still,
                child: Text(
                  'in the background: ${it.backgroundCommand.state}',
                  style: theme.ui(t.textMuted, size: 11.5),
                ),
              ),
            const SizedBox(width: 8),
            _failed(theme, failed ? 'failed' : ''),
          ],
        ),
        // A call with nothing to show only has its title.
        body: !hasToolBody(it)
            ? null
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    if (command)
                      FullTitle(
                        '\$ ${it.title}',
                      ), // the header cuts it to a line
                    for (final d in it.diffs) DiffBox(d),
                    if (input) ToolSection('Input', RawText(it.input)),
                    if (output && input)
                      ToolSection('Output', AgentMarkdown(it.text))
                    else if (output)
                      AgentMarkdown(it.text)
                    else if (showsRawOutput(it))
                      ToolSection('Output', RawText(it.rawOutput, folded: 12)),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget _tooltip(String? message, Widget child) =>
    message == null ? child : Tooltip(message: message, child: child);

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
/// opens to each call; while one runs, what it's doing ends the line and
/// shines ("Read 4 files, searching").
class RunView extends StatelessWidget {
  const new(this.calls, {super.key, this.still = false});

  final List<Item> calls;
  final bool still; // as ToolCallView's

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final failed = calls.where((c) => c.status == 'failed').length;
    // The last file it wrote that previews, so a folded run offers it too.
    final preview = calls.map(previewPath).nonNulls.lastOrNull;
    return _withImages(
      [for (final c in calls) ...c.images],
      Collapsible(
        // Open when its first call was, before the next made it a group.
        ids: ['group ${calls.first.id}', calls.first.id],
        failed: false, // its failed calls stand out inside, and in the count
        header: Row(
          children: [
            Icon(Icons.layers_outlined, size: 13, color: t.toolAccent),
            const SizedBox(width: 6),
            Expanded(child: _groupTitle(theme, calls, still: still)),
            if (preview != null) PreviewButton(preview),
            const SizedBox(width: 8),
            _failed(theme, failed == 0 ? '' : '$failed failed'),
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

/// A run's line: what it did, and what its running call is doing, shining.
Widget _groupTitle(NushiTheme theme, List<Item> calls, {required bool still}) {
  final running = still ? null : calls.where(_running).firstOrNull;
  final done = calls.where((c) => running == null || !_running(c)).toList();
  final now = running == null ? null : doingOf(running);
  return RunLine(
    done.isEmpty ? '' : groupLabel(done),
    now == null || done.isEmpty ? now : now[0].toLowerCase() + now.substring(1),
    style: theme.ui(theme.t.textSecondary),
  );
}
