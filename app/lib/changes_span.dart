import 'dart:async';

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

/// A chat's changes as its folder stands: the [scope] shown, the [base]
/// branch they are counted from (a worktree's own base, else the
/// repository's default branch; '' if there's none), the folder's [status]
/// (its branch, and its changes counted as the scope shows them), and in
/// Commits the branch's [commits].
class ChangeSpan {
  new(this.scope, this.base, this.status, [this.commits = const []]);

  final Scope scope;
  final String base;
  final GetFolderStatusResponse status;
  final List<Commit> commits;

  /// Whether HEAD is on the base branch itself: its commits are then the
  /// last ones, not the branch's own.
  bool get onBase =>
      base.isEmpty ||
      base == status.branch ||
      base.endsWith('/${status.branch}');

  /// The scopes there are: Branch needs a base.
  List<Scope> get scopes => [
    for (final s in Scope.values)
      if (s != Scope.branch || base.isNotEmpty) s,
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
    final scopes = ChangeSpan(Scope.uncommitted, base, status).scopes;
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
    final span = ChangeSpan(scope, base, status);
    if (scope != Scope.commits || !status.git) return span;
    final commits = await client.listCommits(
      ListCommitsRequest(folder: folder, base: span.onBase ? '' : base),
    );
    return ChangeSpan(scope, base, status, commits.commits);
  }

  /// What GetDiff lists for the scope; in Commits, what the commits from
  /// [since] to [commit] changed.
  GetDiffRequest diff(String folder, {String? commit, String? since}) =>
      switch (scope) {
        Scope.uncommitted => GetDiffRequest(folder: folder),
        Scope.branch => GetDiffRequest(folder: folder, base: base),
        Scope.commits => GetDiffRequest(
          folder: folder,
          commit: commit,
          since: since,
        ),
      };
}

/// Reloads (`reload`) a chat's changes when its turn ends, it moves, or its
/// scope is changed.
mixin FollowsChanges<T extends StatefulWidget> on State<T> {
  ChatState get chat;
  Daemon get daemon;
  late String _folder;
  String? _scope;
  bool _wasBusy = false;

  Future<void> reload();

  @override
  void initState() {
    super.initState();
    _folder = chat.folder;
    _scope = chat.scope;
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
        _scope != chat.scope) {
      _folder = chat.folder;
      _scope = chat.scope;
      unawaited(reload());
    }
    _wasBusy = chat.busy;
  }
}
