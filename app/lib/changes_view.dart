import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

/// The chat folder's changes in a [Scope]: a toolbar, the changed files
/// (under the branch's commits in Commits) and the picked one side by
/// side. It reloads when the agent finishes a turn.
class ChangesView extends StatefulWidget {
  const new({required this.chat, required this.daemon, super.key});

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
  String? _first;
  String? _last; // the commits picked (hashes), a click and a shift-click
  String? _error;
  String? _path; // the file shown
  String? _opening; // a file to show once the list is in (a terminal link)
  int _openingLine = 0; // and its line, from 1
  int _line = 0; // the line of the file shown to go to, from 1
  int _jumps = 0; // how many times a line was asked for: each goes to it
  // A file asked for that isn't among the changes (a review's finding):
  // its text as it is, shown until another file is picked.
  FileChange? _plain;
  // The last reload's or pick's number: an older answer is dropped.
  int _asked = 0;
  bool _reloading = false;
  bool _repick = false; // commits were picked during a reload
  // What's shown is of the scope or commits before the ones asked for, and
  // has been for a moment: it's dimmed under a spinner.
  bool _stale = false;
  Timer? _slow;

  @override
  void initState() {
    _take();
    super.initState();
    chat.addListener(_open);
  }

  @override
  void dispose() {
    chat.removeListener(_open);
    _slow?.cancel();
    super.dispose();
  }

  /// A load was asked for: if it takes a while, what's shown dims (fast
  /// ones don't flicker).
  void _waiting() {
    _slow?.cancel();
    _slow = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _stale = true);
    });
  }

  /// The last load answered (or failed); call in setState.
  void _settled() {
    _slow?.cancel();
    _stale = false;
  }

  /// Takes the file the chat asks to show (see ChatState.showFile).
  bool _take() {
    final path = chat.openPath;
    if (path == null) return false;
    chat.openPath = null;
    _opening = path;
    _openingLine = chat.openLine;
    return true;
  }

  void _open() {
    if (_take()) unawaited(reload());
  }

  /// The commits picked, as indices: newest, oldest.
  (int, int)? get _picked => pickedCommits(_commits, _first, _last);

  /// Reads the scope again, and its files; what's shown stays until both
  /// are in, so it's never another scope's files under this one's name.
  @override
  Future<void> reload() async {
    final asked = ++_asked;
    setState(() => _reloading = true);
    _repick = false;
    _waiting();
    try {
      final span = await ChangeSpan.of(daemon, chat);
      if (!mounted || asked != _asked) return; // another load took over
      final status = span.status;
      if (!status.git) {
        setState(() {
          _error = status.gone
              ? 'The folder is gone.'
              : 'Not a git repository.';
        });
        return;
      }
      final commits = span.commits;
      var (first, last) = (_first, _last);
      if (pickedCommits(commits, first, last) == null) {
        (first, last) = (commits.firstOrNull?.hash, null);
      }
      final files = await span.files(daemon, chat.folder, first, last);
      if (!mounted || asked != _asked) return;
      setState(() {
        _span = span;
        _commits = commits;
        if (!_repick) {
          _first = first;
          _last = last;
        }
        _show(files);
        _error = null;
        _reloading = false; // before _diff takes over
      });
      if (_repick) unawaited(tryOrShow(context, _diff));
    } on Object catch (e) {
      if (mounted && asked == _asked) setState(() => _error = errorText(e));
    } finally {
      if (mounted && asked == _asked) {
        setState(() {
          _reloading = false;
          _settled();
        });
      }
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

  /// Shows [files], keeping the file shown if it's among them; call in
  /// setState.
  void _show(List<FileChange> files) {
    if (!chat.busy) forgetChanged(chat.id, _where, files);
    _files = files;
    if (_plain case final p? when files.any((f) => f.path == p.path)) {
      _path = p.path;
      _plain = null;
    }
    if (_opening case final open?) {
      _line = _openingLine;
      _jumps++;
      if (_files.any((f) => f.path == open)) {
        _path = open;
        _plain = null;
      } else {
        unawaited(_showPlain(open));
      }
    }
    _opening = null;
    if (!_files.any((f) => f.path == _path)) {
      _path = changeRows(
        _files,
        flat: changesFlat.value,
      ).where((r) => r.file != null).firstOrNull?.path;
    }
  }

  /// Shows [path], which isn't among the changes, as it is now.
  Future<void> _showPlain(String path) async {
    FileChange file;
    try {
      file = (await daemon.client.getFile(
        GetFileRequest(folder: chat.folder, path: path),
      )).file;
    } on Object {
      file = FileChange(path: path, skipped: 'unreadable');
    }
    if (mounted) setState(() => _plain = file);
  }

  /// Reads the files of the commits picked.
  Future<void> _diff() async {
    final asked = ++_asked;
    _waiting();
    try {
      final files = await _span!.files(daemon, chat.folder, _first, _last);
      if (!mounted || asked != _asked) return; // a newer one is coming
      setState(() => _show(files));
    } finally {
      if (mounted && asked == _asked) setState(_settled);
    }
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
    // A reload under way reads them again once its commits are in.
    if (_reloading) {
      _repick = true;
    } else {
      unawaited(tryOrShow(context, _diff));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    if (_error != null) {
      // The toolbar stays, so a scope that fails can be left.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.ui(t.text),
                  ),
                  Button(label: 'Try again', onPressed: reload),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final file = _plain ?? _files.where((f) => f.path == _path).firstOrNull;
    final notShown = file == null
        ? ''
        : 'Not shown: ${file.path} is ${file.skipped}.';
    final commits = _span?.scope == Scope.commits;
    final empty = _reloading
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
        _cardsWaiting(),
        Expanded(
          child: Dimmed(
            on: _stale,
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
                          // ⌘F: the files with a text.
                          ValueListenableBuilder(
                            valueListenable: chat.filesFilter,
                            builder: (context, q, _) => q == null
                                ? const SizedBox.shrink()
                                : FilesFilterField(
                                    chat.filesFilter,
                                    shown: _shownFiles(q).length,
                                    total: _files.length,
                                  ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: ListenableBuilder(
                                listenable: Listenable.merge([
                                  reviews,
                                  chat.filesFilter,
                                ]),
                                builder: (context, _) => FileList(
                                  files: _shownFiles(chat.filesFilter.value),
                                  selected: _plain == null ? _path : null,
                                  onSelect: (p) => setState(() {
                                    _path = p;
                                    _plain = null;
                                  }),
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
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_plain != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    6,
                                    12,
                                    6,
                                  ),
                                  child: Text(
                                    '${file.path} has no changes here',
                                    style: theme.ui(t.textMuted, size: 12),
                                  ),
                                ),
                              Expanded(
                                child: DiffBox(
                                  file,
                                  key: ValueKey((file.path, _jumps)),
                                  fit: false,
                                  line: _line,
                                  // Comments go with changes, not with a
                                  // file shown as it is.
                                  review: _plain == null
                                      ? (
                                          chat: chat.id,
                                          where: _where,
                                          agent: chat.agentName,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(notShown, style: theme.ui(t.textMuted)),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The scope, what the files add up to, and the list's controls.
  /// The files the list shows: those with [query] (⌘F), else all.
  List<FileChange> _shownFiles(String? query) => query == null || query.isEmpty
      ? _files
      : [
          for (final f in _files)
            if (fileHas(f, query)) f,
        ];

  /// The reply cards waiting in the chat's box (the review's, sent from
  /// here), with the way to the chat.
  Widget _cardsWaiting() => ValueListenableBuilder(
    valueListenable: widget.chat.draft.replies,
    builder: (context, replies, _) => replies.isEmpty
        ? const SizedBox.shrink()
        : RepliesWaiting(
            replies.length,
            onChat: () => widget.chat.tab.value = ChatTab.chat,
          ),
  );

  Widget _toolbar() {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final span = _span;
    // Before anything loaded (it failed), every scope, to leave the one
    // that fails.
    final scopes = span?.scopes ?? Scope.values;
    final asked = Scope.values.where((s) => s.name == chat.scope).firstOrNull;
    // The scope shown, until another's load has taken a moment.
    final scope =
        (_stale && scopes.contains(asked) ? asked : span?.scope) ??
        asked ??
        Scope.uncommitted;
    final files = _error == null && !_stale ? _files : const <FileChange>[];
    final n = files.length;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        spacing: 10,
        children: [
          if (scopes.length > 1)
            Segmented(
              value: scope,
              segments: [for (final s in scopes) (s, s.label)],
              onChanged: (s) => chat.scope = s.name,
            ),
          if (_stale)
            const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          if (n > 0)
            Text(
              '$n file${n == 1 ? '' : 's'}',
              style: theme.ui(t.textSecondary, size: 12),
            ),
          Expanded(
            child: LineCounts(
              files.fold(0, (n, f) => n + f.added),
              files.fold(0, (n, f) => n + f.removed),
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([reviews, chat]),
            builder: (context, _) {
              final n = unsentComments(chat.id).length;
              if (n == 0) return const SizedBox.shrink();
              // As the Pull request tab's Send to agent: reply cards in
              // the chat's box, to go with the next message.
              return Button(
                label: 'Send to agent ($n)',
                icon: Icons.subdirectory_arrow_right,
                kind: ButtonKind.primary,
                tooltip:
                    "Each comment as a reply card in the chat's box, to "
                    'send with your next message',
                onPressed: chat.archived || chat.sessionGone
                    ? null
                    : () => reviewToBox(chat),
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
            onTap: _reloading ? null : reload,
          ),
        ],
      ),
    );
  }
}
