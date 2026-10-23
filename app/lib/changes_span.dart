import 'package:flutter/widgets.dart';

import 'chat.dart';
import 'daemon.dart';
import 'gen/nushi/v1/nushi.pb.dart';

/// What a chat's Changes view shows: what's uncommitted, the branch's
/// work since it left its base (committed, uncommitted and untracked), or
/// the branch's commits one by one.
enum Scope {
  uncommitted('Uncommitted'),
  branch('Branch'),
  commits('Commits');

  const Scope(this.label);
  final String label;
}

/// A chat's changes as its folder stands: the [scope] shown, the [base]
/// branch they are counted from (a worktree's own base, else the
/// repository's default branch; '' if there's none), and the folder's
/// [status] (its branch, and how far it is [GetFolderStatusResponse.ahead]
/// of the base).
class ChangeSpan {
  ChangeSpan(this.scope, this.base, this.status);

  final Scope scope;
  final String base;
  final GetFolderStatusResponse status;

  /// Whether HEAD is on the base branch itself: its commits are then the
  /// last ones, not the branch's own.
  bool get onBase =>
      base.isEmpty ||
      base == status.branch ||
      base.endsWith('/${status.branch}');

  /// The scopes there are: Branch needs a base; all need API 27.
  List<Scope> scopes(Daemon daemon) => [
    if (daemon.canCommits)
      for (final s in Scope.values)
        if (s != Scope.branch || base.isNotEmpty) s,
  ];

  /// Reads [chat]'s folder. The scope is the one picked for the chat, else
  /// Branch when the branch has commits of its own, else Uncommitted.
  static Future<ChangeSpan> of(Daemon daemon, ChatState chat) async {
    final status = await daemon.client.getFolderStatus(
      GetFolderStatusRequest(folder: chat.folder, base: chat.worktree?.base),
    );
    final base = chat.worktree?.base ?? status.defaultBase;
    final span = ChangeSpan(Scope.uncommitted, base, status);
    final scopes = span.scopes(daemon);
    final picked = Scope.values.where((s) => s.name == chat.scope).firstOrNull;
    return ChangeSpan(
      scopes.contains(picked)
          ? picked!
          : status.ahead > 0 && scopes.contains(Scope.branch)
          ? Scope.branch
          : Scope.uncommitted,
      base,
      status,
    );
  }

  /// The base the branch's commits are listed from: none on the base
  /// branch itself (its last commits).
  String get commitsBase => onBase ? '' : base;
}

/// Reloads (`reload`) a chat's changes when its turn ends, it moves, its
/// scope is changed, or a file is to be shown.
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
    reload();
  }

  @override
  void dispose() {
    chat.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_wasBusy && !chat.busy ||
        chat.openPath != null ||
        _folder != chat.folder ||
        _scope != chat.scope) {
      _folder = chat.folder;
      _scope = chat.scope;
      reload();
    }
    _wasBusy = chat.busy;
  }
}
