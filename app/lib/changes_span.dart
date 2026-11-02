import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// What a chat's Changes view shows: what's uncommitted, the branch's
/// work since it left its base (committed, uncommitted and untracked), or
/// the branch's commits one by one.
enum Scope {
  uncommitted('Uncommitted'),
  branch('Branch'),
  commits('Commits');

  new(this.label);
  final String label;
}

/// A chat's changes as its folder stands: the [folder] read, the [scope]
/// shown, the [base] branch they are counted from (a worktree's own base,
/// else the repository's default branch; '' if there's none), the folder's
/// [status] (its branch, and its changes counted as the scope shows them),
/// and in Commits the branch's [commits].
class ChangeSpan {
  new(
    this.folder,
    this.scope,
    this.base,
    this.status, {
    this.commits = const [],
    this.worktree,
    this.head = '',
  });

  final String folder;
  final Scope scope;
  final String base;
  final GetFolderStatusResponse status;
  final List<Commit> commits;

  /// The related worktree this is of, by path: it only reads (ADR 0081).
  final String? worktree;

  /// The commit a removed worktree last had: it has no folder, so its
  /// commits are read in the chat's by this. '' for a folder's HEAD.
  final String head;

  /// Whether it can only be read: no staging, commits or comments.
  bool get readOnly => worktree != null;

  /// What's staged, as the last [files] read it; Uncommitted's only.
  String index = '';

  /// Whether HEAD is on the base branch itself: its commits are then the
  /// last ones, not the branch's own.
  bool get onBase =>
      base.isEmpty ||
      base == status.branch ||
      base.endsWith('/${status.branch}');

  /// The scopes there are: Branch needs a base, Uncommitted a work tree.
  List<Scope> get scopes => [
    for (final s in Scope.values)
      if ((s != Scope.branch || base.isNotEmpty) &&
          (s != Scope.uncommitted || head.isEmpty))
        s,
  ];

  /// Reads [chat]'s folder. The scope is the one picked for the chat, else
  /// Branch when the branch has commits of its own, else Uncommitted.
  static Future<ChangeSpan> of(Daemon daemon, ChatState chat) async {
    final client = daemon.client;
    final folder = chat.folder;
    var wtBase = chat.worktree?.base ?? '';
    GetFolderStatusResponse status;
    try {
      status = await client.getFolderStatus(
        GetFolderStatusRequest(folder: folder, base: wtBase),
      );
    } on Object {
      if (wtBase.isEmpty) rethrow;
      // Its base branch is gone (merged and deleted, say): from the commit
      // it started from, else (an older worktree) the default branch.
      wtBase = chat.worktree!.baseCommit;
      status = await client.getFolderStatus(
        GetFolderStatusRequest(folder: folder, base: wtBase),
      );
    }
    final base = wtBase.isNotEmpty ? wtBase : status.defaultBase;
    final scopes = ChangeSpan(folder, Scope.uncommitted, base, status).scopes;
    final picked = Scope.values.where((s) => s.name == chat.scope).firstOrNull;
    final scope = scopes.contains(picked)
        ? picked!
        : status.ahead > 0 && scopes.contains(Scope.branch)
        ? Scope.branch
        : Scope.uncommitted;
    final countFrom = scope == Scope.branch ? base : '';
    if (status.git && countFrom != wtBase) {
      status = await client.getFolderStatus(
        GetFolderStatusRequest(folder: folder, base: countFrom),
      );
    }
    final span = ChangeSpan(folder, scope, base, status);
    if (scope != Scope.commits || !status.git) return span;
    final commits = await client.listCommits(
      ListCommitsRequest(folder: folder, base: span.onBase ? '' : base),
    );
    return ChangeSpan(folder, scope, base, status, commits: commits.commits);
  }

  /// Reads related worktree [w] of [chat], only ever for a click: what shows
  /// next runs a GetDiff (ADR 0081). A removed one, or one whose folder went
  /// since the daemon looked, reads its commits in the chat's folder. The
  /// scope is [picked] (a Scope's name), else Branch, as a subagent's work
  /// is what's being looked at.
  static Future<ChangeSpan> ofRelated(
    Daemon daemon,
    ChatState chat,
    RelatedWorktree w,
    String? picked,
  ) async {
    final client = daemon.client;
    var status = GetFolderStatusResponse(git: true, branch: w.branch);
    var head = w.lastHead;
    if (w.state == 'present') {
      final there = await client.getFolderStatus(
        GetFolderStatusRequest(folder: w.path, base: w.baseCommit),
      );
      if (there.git) (status, head) = (there, '');
    }
    final folder = head.isEmpty ? w.path : chat.folder;
    final base = w.baseCommit;
    ChangeSpan span(Scope scope, [List<Commit> commits = const []]) =>
        ChangeSpan(
          folder,
          scope,
          base,
          status,
          commits: commits,
          worktree: w.path,
          head: head,
        );
    final scopes = span(Scope.branch).scopes;
    final asked = Scope.values.where((s) => s.name == picked).firstOrNull;
    final scope = scopes.contains(asked)
        ? asked!
        : scopes.contains(Scope.branch)
        ? Scope.branch
        : scopes.first;
    if (scope != Scope.commits) return span(scope);
    final commits = await client.listCommits(
      ListCommitsRequest(folder: folder, base: base, head: head),
    );
    return span(scope, commits.commits);
  }

  /// The files of the scope; in Commits, of the commits picked ([first]
  /// and [last] of [commits], as [pickedCommits] takes them), none if
  /// none is.
  Future<List<FileChange>> files(
    Daemon daemon,
    String? first,
    String? last,
  ) async {
    final picked = pickedCommits(commits, first, last);
    if (scope == Scope.commits && picked == null) return [];
    final req = diff(
      folder,
      commit: picked == null ? null : commits[picked.$1].hash,
      since: picked == null || picked.$1 == picked.$2
          ? null
          : commits[picked.$2].hash,
    );
    final got = await daemon.client.getDiff(req);
    index = got.index;
    return got.files;
  }

  /// What GetDiff lists for the scope; in Commits, what the commits from
  /// [since] to [commit] changed.
  GetDiffRequest diff(String folder, {String? commit, String? since}) =>
      switch (scope) {
        Scope.uncommitted => GetDiffRequest(folder: folder),
        // Its commits alone: `since` would count its base's own change.
        Scope.branch when head.isNotEmpty => GetDiffRequest(
          folder: folder,
          after: base,
          commit: head,
        ),
        Scope.branch => GetDiffRequest(folder: folder, base: base),
        Scope.commits => GetDiffRequest(
          folder: folder,
          commit: commit,
          since: since,
        ),
      };
}

/// The commits picked, a click's ([a]) and a shift-click's ([b]), as
/// indices into [commits]: newest, oldest; null if [a] isn't there.
(int, int)? pickedCommits(List<Commit> commits, String? a, String? b) {
  final i = commits.indexWhere((c) => c.hash == a);
  final j = commits.indexWhere((c) => c.hash == (b ?? a));
  return i < 0 || j < 0 ? null : (min(i, j), max(i, j));
}

/// Reloads (`reload`) a chat's changes when its turn ends, it moves, its
/// scope is changed, or a commit is made in it.
mixin FollowsChanges<T extends StatefulWidget> on State<T> {
  ChatState get chat;
  Daemon get daemon;
  late String _folder;
  String? _scope;
  bool _wasBusy = false;
  int _commits = 0;

  Future<void> reload();

  @override
  void initState() {
    super.initState();
    _folder = chat.folder;
    _scope = chat.scope;
    _commits = chat.commits;
    chat.addListener(_changed);
    unawaited(reload());
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_wasBusy && !chat.busy ||
        _folder != chat.folder ||
        _scope != chat.scope ||
        _commits != chat.commits) {
      _commits = chat.commits;
      _folder = chat.folder;
      _scope = chat.scope;
      unawaited(reload());
    }
    _wasBusy = chat.busy;
  }
}
