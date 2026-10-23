import 'dart:math';

import 'package:flutter/material.dart';

import 'changes_span.dart';
import 'chat.dart';
import 'commits.dart';
import 'daemon.dart';
import 'diff_box.dart';
import 'file_tree.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'panes.dart';
import 'review.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The chat folder's changes in a [Scope]: a toolbar, the changed files
/// (under the branch's commits in Commits) and the picked one side by
/// side. It reloads when the agent finishes a turn.
class ChangesView extends StatefulWidget {
  const ChangesView({super.key, required this.chat, required this.daemon});

  final ChatState chat;
  final Daemon daemon;

  @override
  State<ChangesView> createState() => _ChangesViewState();
}

class _ChangesViewState extends State<ChangesView> with FollowsChanges {
  @override
  ChatState get chat => widget.chat;
  @override
  Daemon get daemon => widget.daemon;
  ChangeSpan? _span;
  List<FileChange> _files = [];
  List<Commit> _commits = [];
  String? _first,
      _last; // the commits picked (hashes), a click and a shift-click
  String? _error;
  bool _loading = false;
  String? _path; // the file shown
  String? _opening; // a file to show once the list is in (a terminal link)
  int _asked = 0; // the last request's number: older answers are dropped

  @override
  void initState() {
    _take();
    super.initState();
    chat.addListener(_open);
  }

  @override
  void dispose() {
    chat.removeListener(_open);
    super.dispose();
  }

  /// Takes the file the chat asks to show (see ChatState.showFile).
  bool _take() {
    final path = chat.openPath;
    if (path == null) return false;
    chat.openPath = null;
    _opening = path;
    return true;
  }

  void _open() {
    if (_take()) reload();
  }

  /// The commits picked, as indices: newest, oldest.
  (int, int)? get _picked {
    final i = _commits.indexWhere((c) => c.hash == _first);
    final j = _commits.indexWhere((c) => c.hash == (_last ?? _first));
    return i < 0 || j < 0 ? null : (min(i, j), max(i, j));
  }

  @override
  Future<void> reload() async {
    final asked = ++_asked;
    setState(() => _loading = true);
    try {
      final span = await ChangeSpan.of(daemon, chat);
      if (asked != _asked) return; // another reload took over
      final status = span.status;
      if (!status.git) {
        throw status.gone ? 'The folder is gone.' : 'Not a git repository.';
      }
      _span = span;
      _commits = [];
      if (span.scope == Scope.commits) {
        _commits = (await daemon.client.listCommits(
          ListCommitsRequest(folder: chat.folder, base: span.commitsBase),
        )).commits;
        if (asked != _asked) return;
        if (_picked == null) {
          _first = _commits.firstOrNull?.hash;
          _last = null;
        }
      }
      await _diff(asked);
      _error = null;
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted && asked == _asked) setState(() => _loading = false);
    }
  }

  /// Which view the review comments are made in: the scope, and in
  /// Commits the commits picked.
  String get _where {
    final p = _picked;
    return _span?.scope != Scope.commits || p == null
        ? '${_span?.scope.name}'
        : 'commits:${_commits[p.$1].hash}:${_commits[p.$2].hash}';
  }

  /// How many review comments each file has in this view.
  Map<String, int> _marks() {
    final marks = <String, int>{};
    for (final c in commentsOf(chat.id).where((c) => c.where == _where)) {
      marks.update(c.path, (n) => n + 1, ifAbsent: () => 1);
    }
    return marks;
  }

  /// Reads the files of the scope (in Commits, of the commits picked).
  Future<void> _diff([int? asked]) async {
    asked ??= ++_asked;
    final span = _span!;
    final picked = _picked;
    final GetDiffRequest req = switch (span.scope) {
      Scope.uncommitted => GetDiffRequest(folder: chat.folder),
      Scope.branch => GetDiffRequest(folder: chat.folder, base: span.base),
      Scope.commits => GetDiffRequest(
        folder: chat.folder,
        commit: picked == null ? null : _commits[picked.$1].hash,
        since: picked == null || picked.$1 == picked.$2
            ? null
            : _commits[picked.$2].hash,
      ),
    };
    final files = span.scope == Scope.commits && picked == null
        ? <FileChange>[]
        : (await daemon.client.getDiff(req)).files;
    if (!mounted || asked != _asked) return; // a newer one is coming
    if (!chat.busy) forgetChanged(chat.id, _where, files);
    setState(() {
      _files = files;
      if (_files.any((f) => f.path == _opening)) _path = _opening;
      _opening = null;
      if (!_files.any((f) => f.path == _path)) {
        _path = changeRows(
          _files,
          flat: changesFlat.value,
        ).where((r) => r.file != null).firstOrNull?.path;
      }
    });
  }

  void _pick(int i, {required bool extend}) {
    setState(() {
      if (extend && _first != null) {
        _last = _commits[i].hash;
      } else {
        _first = _commits[i].hash;
        _last = null;
      }
    });
    tryOrShow(context, _diff);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: theme.ui(t.text)),
            Button(label: 'Try again', onPressed: reload),
          ],
        ),
      );
    }
    final file = _files.where((f) => f.path == _path).firstOrNull;
    final commits = _span?.scope == Scope.commits;
    final empty = _loading
        ? ''
        : commits && _commits.isEmpty
        ? 'No commits of its own yet'
        : _files.isEmpty
        ? 'No changes'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Resizable(
                  name: 'files',
                  initial: 240,
                  min: 180,
                  max: min(560, box.maxWidth - 360),
                  child: ColoredBox(
                    color: t.raised,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (commits && _commits.isNotEmpty)
                          Container(
                            height: min(
                              _commits.length * CommitList.rowHeight + 8,
                              box.maxHeight * 0.45,
                            ),
                            padding: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: t.borderSubtle),
                              ),
                            ),
                            child: CommitList(
                              commits: _commits,
                              picked: _picked,
                              onPick: _pick,
                            ),
                          ),
                        if (empty.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(empty, style: theme.ui(t.textMuted)),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ValueListenableBuilder(
                              valueListenable: reviews,
                              builder: (context, _, _) => FileList(
                                files: _files,
                                selected: _path,
                                onSelect: (p) => setState(() => _path = p),
                                marks: _marks(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: file != null && file.skipped.isEmpty
                      ? DiffBox(
                          file,
                          key: ValueKey(file.path),
                          fit: false,
                          review: (chat: chat.id, where: _where),
                        )
                      : Center(
                          child: Text(
                            file == null
                                ? ''
                                : 'Not shown: ${file.path} is ${file.skipped}.',
                            style: theme.ui(t.textMuted),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The scope, what the files add up to, and the list's controls.
  Widget _toolbar() {
    final theme = NushiTheme.of(context), t = theme.t;
    final span = _span;
    final scopes = span?.scopes ?? const [];
    final n = _files.length;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        spacing: 10,
        children: [
          if (span != null && scopes.length > 1)
            Segmented(
              value: span.scope,
              segments: [for (final s in scopes) (s, s.label)],
              onChanged: (s) => chat.scope = s.name,
            ),
          if (n > 0)
            Text(
              '$n file${n == 1 ? '' : 's'}',
              style: theme.ui(t.textSecondary, size: 12),
            ),
          Expanded(
            child: LineCounts(
              _files.fold(0, (n, f) => n + f.added),
              _files.fold(0, (n, f) => n + f.removed),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([reviews, chat]),
            builder: (context, _) {
              final n = commentsOf(chat.id).where((c) => !c.sent).length;
              if (n == 0) return const SizedBox.shrink();
              return Button(
                label: 'Send review ($n)',
                icon: Icons.rate_review_outlined,
                kind: ButtonKind.primary,
                onPressed: chat.archived
                    ? null
                    : () => sendReview(context, daemon, chat.id),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: changesFlat,
            builder: (context, flat, _) => IconTap(
              flat ? Icons.account_tree_outlined : Icons.list,
              tooltip: flat ? 'Show as a tree' : 'Show as a list',
              size: 15,
              onTap: () => changesFlat.value = !flat,
            ),
          ),
          IconTap(
            Icons.refresh,
            tooltip: 'Reload',
            size: 15,
            onTap: _loading ? null : reload,
          ),
        ],
      ),
    );
  }
}
