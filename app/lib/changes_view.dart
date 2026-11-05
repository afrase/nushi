import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nushi/changes_bar.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/file_tree.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/plain_text.dart';
import 'package:nushi/pull_tab.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_elsewhere.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

/// The chat folder's changes in a [Scope]: a toolbar, the changed files
/// (under the branch's commits in Commits) and the picked one side by
/// side. It reloads when the agent finishes a turn. With related worktrees
/// (ADR 0081) the toolbar's menu shows one of them instead, read-only, and
/// read only on a click.
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
  // The last file asked for as it is: an older answer, or one asked for
  // before another file was picked, is dropped.
  int _plainAsked = 0;
  // The last reload's or pick's number: an older answer is dropped.
  int _asked = 0;
  bool _reloading = false;
  bool _repick = false; // commits were picked during a reload
  // The related worktree the view last followed, and what it amounted to
  // when read; the one whose commits turned out to be gone.
  late String? _following = chat.related.shown;
  String? _readStamp;
  String? _goneOf;
  String? _wanted; // the related worktree whose stats this view follows
  // What's shown is of the scope or commits before the ones asked for, and
  // has been for a moment: it's dimmed under a spinner.
  bool _stale = false;
  Timer? _slow;

  // Staging asked for and not yet done, in order.
  Future<void> _staging = Future.value();
  int _stages = 0;
  // The list's last answer to the find: its text, of which files, the files.
  (String, List<FileChange>, List<FileChange>) _shown = (
    '',
    const [],
    const [],
  );

  @override
  void initState() {
    _take();
    super.initState();
    chat.addListener(_open);
    chat.related.addListener(_relatedChanged);
    _want();
    chat.changesFind
      ..roll = _roll
      ..addListener(_findChanged);
  }

  @override
  void dispose() {
    chat.removeListener(_open);
    chat.related.removeListener(_relatedChanged);
    if (_wanted case final path?) chat.related.unwant(path);
    chat.changesFind
      ..roll = null
      ..removeListener(_findChanged);
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
    chat.related.pick(null); // a link means the chat's own file
    _opening = path;
    _openingLine = chat.openLine;
    return true;
  }

  void _open() {
    if (_take()) unawaited(reload());
  }

  /// A worktree was picked or asked for: read it. Otherwise the list or the
  /// stats moved, which changes the menu and may say what's read is behind.
  void _relatedChanged() {
    final shown = chat.related.shown;
    _want();
    if (shown != _following || chat.related.asked) {
      _following = shown;
      unawaited(reload());
    } else {
      setState(() {});
    }
  }

  /// Follows the stats of the worktree shown, to say when it moved on.
  void _want() {
    final shown = chat.related.shown;
    if (shown == _wanted) return;
    if (_wanted case final path?) chat.related.unwant(path);
    if (shown != null) chat.related.want(shown);
    _wanted = shown;
  }

  /// Whether the view shows, or is about to show, what can only be read: the
  /// span held too, for the moment after switching back to the chat's folder
  /// while a worktree's files still show.
  bool get _readOnly =>
      chat.related.shown != null || (_span?.readOnly ?? false);

  /// The worktree shown has moved on from what was read of it.
  bool get _behind {
    final path = chat.related.shown;
    return path != null &&
        _readStamp != null &&
        _span?.worktree == path &&
        chat.related.stamp(path) != _readStamp;
  }

  /// A click: reads what's shown again, a related worktree too.
  void _again() {
    if (chat.related.shown == null) {
      unawaited(reload());
    } else {
      chat.related.ask();
    }
    unawaited(chat.related.reload());
  }

  /// A related worktree's span, its commits' being gone null; the click
  /// that asked is behind this, so its stats are read as they stand.
  Future<ChangeSpan?> _relatedSpan(RelatedWorktree w) async {
    final stats = await chat.related.statsNow(w.path);
    _readStamp = chat.related.stamp(w.path);
    if (stats?.commitsGone ?? false) return null;
    return await ChangeSpan.ofRelated(daemon, chat, w, chat.related.scope);
  }

  /// The commits picked, as indices: newest, oldest.
  (int, int)? get _picked => pickedCommits(_commits, _first, _last);

  /// Reads the scope again, and its files; what's shown stays until both
  /// are in, so it's never another scope's files under this one's name. A
  /// related worktree is read only for a click, as this runs its filters
  /// (ADR 0081): a turn's end or the tab showing again changes nothing.
  @override
  Future<void> reload() => _reloaded = _reload();

  /// The newest [reload], for a commit to wait for what it shows.
  Future<void> _reloaded = Future.value();

  /// Waits for the newest [reload], and for any started while it ran.
  Future<void> _reloadsDone() async {
    Future<void> r;
    do {
      r = _reloaded;
      await r;
    } while (!identical(r, _reloaded));
  }

  Future<void> _reload() async {
    final worktree = chat.related.picked;
    if (worktree != null && !chat.related.takeAsked()) {
      if (mounted) setState(() {});
      return;
    }
    final asked = ++_asked;
    setState(() {
      _reloading = true;
      _goneOf = null;
    });
    _repick = false;
    _waiting();
    try {
      final span = worktree == null
          ? await ChangeSpan.of(daemon, chat)
          : await _relatedSpan(worktree);
      if (!mounted || asked != _asked) return; // another load took over
      if (span == null) {
        setState(() {
          _goneOf = worktree?.path;
          _error = null;
        });
        return;
      }
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
      final files = await span.files(daemon, first, last);
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
      if (mounted && asked == _asked) {
        setState(() => _error = errorText(e));
        reloadFailed(e);
      }
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
    if (_readOnly) return marks; // the chat's comments aren't on these files
    for (final c in commentsOf(chat.id).where((c) => c.where == _where)) {
      marks.update(c.path, (n) => n + 1, ifAbsent: () => 1);
    }
    return marks;
  }

  /// Shows [files], keeping the file shown if it's among them; call in
  /// setState.
  void _show(List<FileChange> files) {
    // Not on another folder's files, which would look like changed ones.
    if (!(_span?.readOnly ?? false)) {
      filesRead(chat, _where, files, idle: !chat.busy);
    }
    _files = files;
    if (_plain case final p? when files.any((f) => f.path == p.path)) {
      _path = p.path;
      _noPlain();
    }
    if (_opening case final open?) {
      _line = _openingLine;
      _jumps++;
      if (_files.any((f) => f.path == open)) {
        _path = open;
        _noPlain();
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

  /// Shows no file as it is, nor one still coming; call in setState.
  void _noPlain() {
    _plain = null;
    _plainAsked++;
  }

  /// Shows [path], which isn't among the changes, as it is now.
  Future<void> _showPlain(String path) async {
    final asked = ++_plainAsked;
    FileChange file;
    try {
      file = (await daemon.client.getFile(
        GetFileRequest(folder: chat.folder, path: path),
      )).file;
    } on Object {
      file = FileChange(path: path, skipped: 'unreadable');
    }
    if (mounted && asked == _plainAsked) setState(() => _plain = file);
  }

  /// Reads the files of the commits picked.
  Future<void> _diff() async {
    final asked = ++_asked;
    _waiting();
    try {
      final files = await _span!.files(daemon, _first, _last);
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
                  Button(label: 'Try again', onPressed: _again),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_unread() case final note?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          Expanded(child: Center(child: note)),
        ],
      );
    }
    final file = _plain ?? _files.where((f) => f.path == _path).firstOrNull;
    final notShown = file == null
        ? ''
        : 'Not shown: ${plainName(file.path)} is ${file.skipped}.';
    final commits = _span?.scope == Scope.commits;
    final staging = _span?.scope == Scope.uncommitted && !_readOnly;
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
        if (!_readOnly) _cardsWaiting(),
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
                          if (_span != null && !_readOnly)
                            CommentsElsewhere(
                              chat: chat.id,
                              where: _where,
                              paths: {for (final f in _files) f.path},
                              maxHeight: box.maxHeight * 0.4,
                            ),
                          if (empty.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(empty, style: theme.ui(t.textMuted)),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: ListenableBuilder(
                                listenable: Listenable.merge([
                                  reviews,
                                  chat.changesFind,
                                ]),
                                builder: (context, _) => FileList(
                                  files: _shownFiles(),
                                  selected: _plain == null ? _path : null,
                                  onSelect: (p) => setState(() {
                                    _path = p;
                                    _noPlain();
                                  }),
                                  marks: _marks(),
                                  onStage: staging ? _stage : null,
                                ),
                              ),
                            ),
                          ),
                          if (staging && _files.isNotEmpty)
                            CommitBox(
                              chat: chat,
                              files: _files,
                              onStage: _stage,
                              onCommit: _commit,
                              onWrite: _writeMessage,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _shownFile(file, notShown)),
                        // ⌘F, as over the transcript.
                        ListenableBuilder(
                          listenable: chat.changesFind,
                          builder: (context, _) =>
                              chat.changesFind.query == null
                              ? const SizedBox.shrink()
                              : Positioned(
                                  top: 8,
                                  right: NushiTheme.gutter,
                                  child: FindBar(
                                    chat.changesFind,
                                    hint: 'Find in the changes',
                                  ),
                                ),
                        ),
                      ],
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

  /// What stands in for a related worktree's files, if anything does: that
  /// its commits are gone, or (the view having come back to it with no
  /// click) the way to read it.
  Widget? _unread() {
    final theme = NushiTheme.of(context);
    final path = chat.related.shown;
    if (path == null) return null;
    if (_goneOf == path) {
      return Text(
        "This worktree's commits are gone: git no longer has them.",
        textAlign: TextAlign.center,
        style: theme.ui(theme.t.text),
      );
    }
    if (_span?.worktree == path) return null;
    return _reloading
        ? const SizedBox.shrink()
        : Button(label: 'Show its changes', onPressed: _again);
  }

  /// The file picked, or why it isn't shown.
  Widget _shownFile(FileChange? file, String notShown) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final find = chat.changesFind;
    if (file?.skipped.isEmpty != true && find.hits.isNotEmpty) {
      // No diff to find in, so none says the last file's hits are gone.
      WidgetsBinding.instance.addPostFrameCallback((_) => find.found(const []));
    }
    return file != null && file.skipped.isEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_plain != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: Text(
                    '${plainName(file.path)} has no changes here',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
              Expanded(
                child: DiffBox(
                  file,
                  key: ValueKey((file.path, _jumps)),
                  fit: false,
                  line: _line,
                  find: chat.changesFind,
                  // Comments go with changes, not with a
                  // file shown as it is.
                  review: _plain == null && !_readOnly
                      ? (chat: chat.id, where: _where, agent: chat.agentName)
                      : null,
                ),
              ),
            ],
          )
        : Center(child: Text(notShown, style: theme.ui(t.textMuted)));
  }

  /// The files the list shows: those with the find's text, else all.
  List<FileChange> _shownFiles() {
    final query = chat.changesFind.query ?? '';
    if (query.isEmpty) return _files;
    final (q, of, shown) = _shown;
    if (q == query && identical(of, _files)) return shown;
    final files = [
      for (final f in _files)
        if (fileHas(f, query)) f,
    ];
    _shown = (query, _files, files);
    return files;
  }

  /// The find changed: the file shown is among those listed, and the bar
  /// says which.
  void _findChanged() {
    final find = chat.changesFind;
    final paths = _inOrder();
    if (paths.isEmpty || find.query == null) {
      find.files = (0, 0);
      return;
    }
    find.files = (paths.indexOf(_path ?? '') + 1, paths.length);
    if (paths.contains(_path) || _plain != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _path = paths.first);
      find.files = (1, paths.length);
    });
  }

  /// The paths the list shows, in its order.
  List<String> _inOrder() => [
    for (final r in changeRows(_shownFiles(), flat: changesFlat.value))
      ?r.file?.path,
  ];

  /// ⏎ went past the file's first or last hit: the next file listed.
  void _roll(int by) {
    final paths = _inOrder();
    if (paths.isEmpty) return;
    final i = paths.indexOf(_path ?? '');
    final next = paths[(i + by) % paths.length];
    chat.changesFind.arrive(by);
    setState(() {
      _path = next;
      _noPlain();
      _line = 0;
      _jumps++; // a new box, even for the file it was (one file listed)
    });
    _findChanged();
  }

  /// Stages [files] or takes them out, at once on screen, in order with
  /// any others asked for, reading the folder again after the last.
  void _stage(List<FileChange> files, {required bool on}) {
    final ask = StageFilesRequest(
      folder: chat.folder,
      staged: on,
      paths: [
        for (final f in files.where(stageable)) ...[
          f.path,
          if (f.oldPath.isNotEmpty) f.oldPath,
        ],
      ],
    );
    setState(() {
      for (final f in files.where(stageable)) {
        f.staged = on ? 'all' : '';
      }
    });
    _stages++;
    final client = daemon.client;
    _staging = _staging.then((_) async {
      if (mounted) {
        await tryOrShow(context, () => client.stageFiles(ask));
      } else {
        // The view gone (another tab) while this waited its turn: the
        // click still counts, with nowhere to say it failed.
        await client.stageFiles(ask).then<void>((_) {}, onError: (Object _) {});
      }
      if (--_stages == 0 && mounted) await reload();
    });
  }

  /// The chat's agent's message for what's staged, once staging under way
  /// is in.
  Future<String> _writeMessage() async {
    await _staging;
    final got = await daemon.client.writeCommitMessage(
      WriteCommitMessageRequest(chatId: chat.id),
    );
    return got.message;
  }

  /// Commits what's staged, once any staging under way is in and read:
  /// with the index the newest reload read (a turn's may overtake the
  /// staging's), so the commit isn't refused as the index having moved.
  Future<void> _commit(String message) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _staging;
    await _reloadsDone();
    try {
      final done = await daemon.client.commitStaged(
        CommitStagedRequest(
          folder: chat.folder,
          message: message,
          index: _span?.index,
        ),
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('Committed ${done.short}')),
      );
    } finally {
      chat.committed();
    }
  }

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
    final related = chat.related;
    final worktree = related.shown;
    // A related worktree not read yet has none of its own to show.
    final unread = worktree != null && _span?.worktree != worktree;
    final span = unread ? null : _span;
    // Before anything loaded (it failed), every scope, to leave the one
    // that fails.
    final scopes = unread || _goneOf == worktree && worktree != null
        ? const <Scope>[]
        : span?.scopes ?? Scope.values;
    final name = worktree == null ? chat.scope : related.scope;
    final asked = Scope.values.where((s) => s.name == name).firstOrNull;
    // The scope shown, until another's load has taken a moment.
    final scope =
        (_stale && scopes.contains(asked) ? asked : span?.scope) ??
        asked ??
        Scope.uncommitted;
    final files = _error == null && !_stale && !unread
        ? _files
        : const <FileChange>[];
    return ChangesBar(
      chat: chat,
      scopes: scopes,
      scope: scope,
      files: files,
      stale: _stale,
      behind: _behind,
      readOnly: _readOnly,
      reloading: _reloading,
      onAgain: _again,
    );
  }
}
