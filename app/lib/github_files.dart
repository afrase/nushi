import 'dart:async';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_review.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/pull_todo_items.dart';
import 'package:nushi/send_to_agent.dart';
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
    this.now,
  });

  final Daemon daemon;
  final GitHubPull pull;

  /// The time ages are counted from (tests); now when null.
  final DateTime? now;

  /// The pull request changed here (a reply, a resolve): ask for it again.
  final Future<void> Function() onChanged;

  @override
  State<GitHubFiles> createState() => _GitHubFilesState();
}

/// The files a head was last read at, by pull request and head, while the
/// app runs: a commit's files don't change. The last [_readMost] only.
final _read = <String, List<FileChange>>{};
const _readMost = 20;

/// Where each pull request's Files tab was left, while the app runs: the
/// file picked and the lines a comment was being written for, so a look
/// at a chat finds them (and the comment's text, kept by its box) again.
final _left = <String, (String?, LineSelection?)>{};

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
        border: Border(top: BorderSide(color: t.borderSubtle)),
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
          VerticalDivider(width: 1, color: t.borderSubtle),
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
    return Tap(
      selected: f.path == _path,
      onTap: () => setState(() {
        _path = f.path;
        _writing = null;
      }),
      tooltip: f.oldPath.isEmpty ? f.path : '${f.oldPath} → ${f.path}',
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    return DiffBox(
      f,
      key: ValueKey(f.path),
      fit: false,
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
                now: widget.now,
                onChanged: widget.onChanged,
              );
      },
    );
  }

  Widget _newDraft(FileChange f, LineSelection w) {
    final s = w.span;
    return _Inlay(
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

/// A note's frame under its lines.
class _Inlay extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: box(t.borderSubtle, fill: t.raised),
      child: child,
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
    return _Inlay(
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

/// A review thread under its lines: its comments (an author outside the
/// repository marked), whether it's outdated (and where it was) or
/// resolved (folded, a click opens it), Reply, Resolve or Unresolve.
class ThreadCard extends StatefulWidget {
  const new({
    required this.daemon,
    required this.ref,
    required this.thread,
    required this.onChanged,
    super.key,
    this.now,
  });

  final Daemon daemon;

  /// The pull request it's on.
  final GitHubRef ref;
  final GitHubThread thread;
  final DateTime? now;
  final Future<void> Function() onChanged;

  @override
  State<ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<ThreadCard> {
  /// The key of its reply box: To do's too.
  late final String _draft = githubDraft(
    widget.ref,
    'thread ${widget.thread.id}',
  );

  /// The reply box shows: opened, or a reply written there not posted yet.
  late bool _replying = commentDraft(_draft).isNotEmpty;
  late bool _open = !widget.thread.resolved || _replying;
  bool _busy = false;

  Future<void> _resolve(bool resolve) async {
    setState(() => _busy = true);
    await tryOrShow(context, () async {
      await widget.daemon.client.resolveGitHubThread(
        ResolveGitHubThreadRequest(
          host: widget.ref.host,
          thread: widget.thread.id,
          resolve: resolve,
        ),
      );
      await widget.onChanged();
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final x = widget.thread;
    final where = x.onFile
        ? 'On the file'
        : x.outdated
        ? 'Outdated · was line ${x.originalLine}'
        : x.startLine > 0 && x.startLine != x.line
        ? 'Lines ${x.startLine}–${x.line}'
        : 'Line ${x.line}';
    final authors = {for (final c in x.comments) c.author}.join(', ');
    final n = x.comments.length;
    final folded = '$n comment${n == 1 ? '' : 's'} by $authors';
    return _Inlay(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tap(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Icon(
                  _open ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: t.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      where,
                      if (x.resolved) 'Resolved',
                      if (!_open) folded,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(
                      x.resolved
                          ? t.textMuted
                          : x.outdated
                          ? t.needs
                          : t.textSecondary,
                      size: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_open) ...[
            for (final c in x.comments)
              CommentEntry(c, now: widget.now ?? clock(), sendable: false),
            const SizedBox(height: 8),
            if (_replying)
              CommentBox(
                draft: _draft,
                hint: 'Reply (Markdown; ⌘⏎ posts it)',
                label: 'Reply',
                autofocus: true,
                onCancel: () => setState(() => _replying = false),
                onPost: (text) async {
                  await widget.daemon.client.replyGitHubThread(
                    ReplyGitHubThreadRequest(
                      host: widget.ref.host,
                      thread: x.id,
                      body: text,
                    ),
                  );
                  if (mounted) setState(() => _replying = false);
                  await widget.onChanged();
                },
              )
            else
              Row(
                children: [
                  if (x.canReply)
                    Button(
                      label: 'Reply',
                      onPressed: () => setState(() => _replying = true),
                    ),
                  if (x.canResolve && !x.resolved)
                    Button(
                      label: 'Resolve',
                      onPressed: _busy ? null : () => _resolve(true),
                    ),
                  if (x.canUnresolve && x.resolved)
                    Button(
                      label: 'Unresolve',
                      onPressed: _busy ? null : () => _resolve(false),
                    ),
                  if (SendToAgent.maybeOf(context) case final to?)
                    SendButton(
                      label: 'Send to agent',
                      onPressed: () => to.send(
                        threadReply(x),
                        'the thread on ${threadPlace(x)}',
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
