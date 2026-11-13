import 'dart:async';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/github_thread.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A pull request's files, from its merge base to its head (GitHub's Files
/// tab), in Nushi's diff view: the files on the left with their review
/// threads' counts, the one picked side by side, its threads under their
/// lines (an outdated one, or one on the whole file, above it; a resolved
/// one folded). Selecting lines writes an inline comment of my review,
/// kept until Review… sends it.
class GitHubFiles extends StatefulWidget {
  const new({
    required this.daemon,
    required this.pull,
    required this.onChanged,
    super.key,
  });

  final Daemon daemon;
  final GitHubPull pull;

  /// The pull request changed here (a reply, a resolve): ask for it again.
  final Future<void> Function() onChanged;

  @override
  State<GitHubFiles> createState() => _GitHubFilesState();
}

/// The files a head was last read at, by pull request and head, while the
/// app runs: a commit's files don't change. The last [_readMost] only.
final Map<String, List<FileChange>> _read = runMap();
const _readMost = 20;

/// Where each pull request's Files tab was left, while the app runs: the
/// file picked and the lines a comment was being written for, so a look
/// at a chat finds them (and the comment's text, kept by its box) again.
final Map<String, (String?, LineSelection?)> _left = runMap();

/// No Files tab left anywhere (tests: each starts afresh).
@visibleForTesting
void forgetFilesLeft() => _left.clear();

class _GitHubFilesState extends State<GitHubFiles> {
  List<FileChange>? _files;
  String? _error;
  String? _path;

  /// The lines a new comment is being written for.
  LineSelection? _writing;

  GitHubRef get _ref => widget.pull.item.ref;
  String get _pullKey => '${_ref.host} ${_ref.repo} ${_ref.number}';
  String get _key => '$_pullKey ${widget.pull.headOid}';

  @override
  void initState() {
    super.initState();
    if (_left[_pullKey] case (final path, final writing)) {
      _path = path;
      _writing = writing;
    }
    draftsChanged.addListener(_redraw);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GitHubFiles old) {
    super.didUpdateWidget(old);
    if (old.pull.headOid != widget.pull.headOid) unawaited(_load());
  }

  @override
  void dispose() {
    _left[_pullKey] = (_path, _writing);
    draftsChanged.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() => setState(() {});

  Future<void> _load() async {
    // The head asked for: another may come while GitHub answers.
    final key = _key;
    if (_read[key] case final files?) {
      setState(() => _pick(files));
      return;
    }
    try {
      final r = await widget.daemon.client.getGitHubFiles(
        GetGitHubFilesRequest(
          ref: _ref,
          baseOid: widget.pull.baseOid,
          headOid: widget.pull.headOid,
        ),
      );
      _read[key] = r.files;
      if (_read.length > _readMost) _read.remove(_read.keys.first);
      if (!mounted || key != _key) return;
      setState(() {
        _pick(r.files);
        _error = null;
      });
    } on Object catch (e) {
      if (mounted && key == _key) setState(() => _error = errorText(e));
    }
  }

  void _pick(List<FileChange> files) {
    _files = files;
    if (!files.any((f) => f.path == _path)) {
      _path = _ordered(files).firstOrNull?.path;
      _writing = null;
    }
  }

  bool _open(FileChange f) => _threadsOf(f.path).any((x) => !x.resolved);

  /// The files with review threads not resolved first, each part in
  /// GitHub's order.
  List<FileChange> _ordered(List<FileChange> files) => [
    ...files.where(_open),
    ...files.where((f) => !_open(f)),
  ];

  List<GitHubThread> _threadsOf(String path) =>
      widget.pull.threads.where((x) => x.path == path).toList();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final read = _files;
    if (read == null) {
      return Center(
        child: Text(
          _error ?? 'Loading the files…',
          style: theme.ui(_error == null ? t.textMuted : t.crashed),
        ),
      );
    }
    final files = _ordered(read);
    final file = files.where((f) => f.path == _path).firstOrNull;
    final withThreads = files.where(_open).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                for (final (i, f) in files.indexed) ...[
                  if (i == 0 && withThreads > 0)
                    _group(theme, 'With unresolved threads · $withThreads'),
                  if (i == withThreads && withThreads > 0)
                    _group(theme, 'The rest · ${files.length - withThreads}'),
                  _fileRow(theme, f),
                ],
                if (widget.pull.changedFiles > files.length)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${widget.pull.changedFiles - files.length} more files: '
                      'GitHub compares 300 at most',
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                  ),
              ],
            ),
          ),
          // The list is on the pane itself and the diff a sunk block
          // beside it, as in Changes (ADR 0111): no line between them.
          Expanded(child: file == null ? const SizedBox() : _diff(theme, file)),
        ],
      ),
    );
  }

  Widget _group(NushiTheme theme, String name) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 3),
    child: Text(
      name,
      style: theme.ui(theme.t.textMuted, size: 11.5, weight: FontWeight.w600),
    ),
  );

  Widget _fileRow(NushiTheme theme, FileChange f) {
    final t = theme.t;
    final threads = _threadsOf(f.path).where((x) => !x.resolved).length;
    final drafts = reviewDrafts(_ref).where((d) => d.path == f.path).length;
    // Its fill is set in from the pane's edges, as a row's in the sidebar
    // and the Changes tree; the name stays where the group's label is.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tap(
        selected: f.path == _path,
        fill: f.path == _path ? t.accentSoft : null,
        onTap: () => setState(() {
          _path = f.path;
          _writing = null;
        }),
        tooltip: f.oldPath.isEmpty ? f.path : '${f.oldPath} → ${f.path}',
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                f.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(
                  f.status == 'deleted' ? t.textMuted : t.text,
                  size: 12.5,
                  weight: f.path == _path ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (threads > 0) ...[
              Icon(Icons.forum_outlined, size: 12, color: t.needs),
              Text(' $threads ', style: theme.ui(t.needs, size: 11.5)),
            ],
            if (drafts > 0)
              Text('✎$drafts ', style: theme.ui(t.link, size: 11.5)),
            Text('+${f.added}', style: theme.ui(t.done, size: 11.5)),
            Text(' −${f.removed}', style: theme.ui(t.crashed, size: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _diff(NushiTheme theme, FileChange f) {
    final t = theme.t;
    if (f.skipped.isNotEmpty) {
      return Center(
        child: Text('Not shown: ${f.skipped}', style: theme.ui(t.textMuted)),
      );
    }
    final threads = _threadsOf(f.path);
    final drafts = reviewDrafts(_ref);
    final w = _writing;
    final notes = <DiffNote>[
      for (final x in threads)
        (
          id: 'thread:${x.id}',
          old: x.side == 'left',
          line: x.outdated || x.onFile ? 0 : x.line,
        ),
      for (final (i, d) in drafts.indexed)
        if (d.path == f.path)
          (id: 'draft:$i', old: d.side == 'left', line: d.line),
      if (w != null) (id: 'new', old: w.side == PaneSide.old, line: w.span.end),
    ];
    final diff = DiffBox(
      f,
      key: ValueKey(f.path),
      fit: false,
      sunk: true,
      notes: notes,
      onLines: (sel) => setState(() => _writing = sel),
      note: (id) {
        if (id == 'new' && w != null) return _newDraft(f, w);
        if (id.startsWith('draft:')) {
          final i = int.parse(id.substring(6));
          return i < drafts.length
              ? _DraftCard(
                  drafts[i],
                  onRemove: () => setDrafts(_ref, [...drafts]..removeAt(i)),
                )
              : const SizedBox();
        }
        final x = threads.where((x) => 'thread:${x.id}' == id).firstOrNull;
        return x == null
            ? const SizedBox()
            : ThreadCard(
                key: ValueKey(x.id),
                daemon: widget.daemon,
                ref: _ref,
                thread: x,
                onChanged: widget.onChanged,
              );
      },
    );
    // Code's sunk surface, set in from the pane's edges, its corners a
    // control's: Changes' block.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.codeBlock,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
        child: RoundedScroll(corner: NushiTheme.control, child: diff),
      ),
    );
  }

  Widget _newDraft(FileChange f, LineSelection w) {
    final s = w.span;
    return Inlay(
      child: CommentBox(
        draft: githubDraft(
          _ref,
          'line ${f.path} ${w.side.name} ${s.start}'
          '-${s.end}',
        ),
        hint: s.length == 1
            ? 'Line ${s.end}: a comment of your review'
            : 'Lines ${s.start + 1}–${s.end}: a comment of your review',
        label: 'Add to review',
        autofocus: true,
        onCancel: () => setState(() => _writing = null),
        onPost: (text) async {
          setDrafts(_ref, [
            ...reviewDrafts(_ref),
            GitHubDraft(
              path: f.path,
              side: w.side == PaneSide.old ? 'left' : 'right',
              line: s.end,
              startLine: s.length > 1 ? s.start + 1 : 0,
              body: text,
            ),
          ]);
          setState(() => _writing = null);
        },
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const new(this.draft, {required this.onRemove});

  final GitHubDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final d = draft;
    return Inlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your review, not sent · '
                  '${d.startLine > 0 ? 'lines ${d.startLine}–' : 'line '}'
                  '${d.line}',
                  style: theme.ui(t.link, size: 11.5),
                ),
              ),
              IconTap(
                Icons.close,
                size: 13,
                tooltip: 'Remove',
                onTap: onRemove,
              ),
            ],
          ),
          AgentMarkdown(d.body, images: githubImage),
        ],
      ),
    );
  }
}
