import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The daemon removes a chat's worktree and deletes its branch, and a pull
/// request's branch on GitHub, and makes that again (GetCleanUp,
/// RemoveChatWorktree, DeleteChatBranch, DeleteGitHubBranch,
/// RestoreGitHubBranch).
const cleanUpApi = 89;

/// What the clean-up does, as its dialog picked: each only when ticked;
/// `force` removes a worktree with uncommitted changes (the dialog named
/// them), `forceBranch` deletes a branch with commits its base lacks; mid-
/// turn, `stopTurn` stops the turn, else it waits for its end.
typedef CleanUpPicks = ({
  bool archive,
  bool worktree,
  bool force,
  bool branch,
  bool forceBranch,
  bool remote,
  bool stopTurn,
});

/// Where one of a clean-up's parts is.
enum StepState { waiting, running, done, failed }

/// One part of a clean-up: what it does, as it goes.
class CleanUpStep {
  new(this.key, this.label);

  final String key;
  String label;
  StepState state = StepState.waiting;
  String? error;
}

/// A chat's clean-up after its pull request, while the app runs: what it
/// waits for, each part as it goes, and what can be undone (the branch on
/// GitHub made again, the chat unarchived). The PR widget shows it.
class CleanUpJob extends ChangeNotifier {
  /// The one of [chat].
  factory of(ChatState chat) => _all[chat] ??= CleanUpJob._(chat);

  new _(this.chat);

  static final _all = Expando<CleanUpJob>();

  final ChatState chat;
  List<CleanUpStep> steps = [];

  /// What it leaves ("Worktree and branch kept").
  String kept = '';

  /// Waiting for the chat's turn to end.
  bool waiting = false;
  bool cancelled = false;

  /// Why it ended before any part ran (the turn wouldn't stop).
  String? error;
  bool get started => steps.isNotEmpty || error != null;
  bool get running => waiting || steps.any((s) => s.state == StepState.running);
  bool get finished =>
      started && !waiting && steps.every((s) => s.state.index >= 2);

  GitHubRef? _pull;
  Daemon? _daemon;

  /// The branch on GitHub was deleted here, and can be made again.
  bool get canRestore =>
      steps.any((s) => s.key == 'remote' && s.state == StepState.done) &&
      _pull != null;

  /// The chat was archived here.
  bool get canUnarchive =>
      chat.archived &&
      steps.any((s) => s.key == 'archive' && s.state == StepState.done);

  /// Runs [picks]: waits for the turn (or stops it), then archives the
  /// chat, removes its worktree, deletes its branch and the pull request's
  /// ([pull]) branch on GitHub, each that was picked; a part that fails
  /// says why and the rest go on. One runs at a time: another asked for
  /// meanwhile does nothing.
  Future<void> run(Daemon daemon, CleanUpPicks picks, GitHubRef? pull) async {
    if (running) return;
    _daemon = daemon;
    _pull = pull;
    cancelled = false;
    error = null;
    steps = [
      if (picks.remote && pull != null)
        CleanUpStep('remote', 'Delete the branch on GitHub'),
      if (picks.archive) CleanUpStep('archive', 'Archive this chat'),
      if (picks.worktree) CleanUpStep('worktree', 'Delete the worktree'),
      if (picks.branch) CleanUpStep('branch', 'Delete the local branch'),
    ];
    kept = chat.worktree == null || picks.worktree && picks.branch
        ? ''
        : picks.worktree
        ? 'Branch kept'
        : picks.branch
        ? 'Worktree kept'
        : 'Worktree and branch kept';
    waiting = chat.busy;
    notifyListeners();
    if (chat.busy && picks.stopTurn) {
      try {
        await daemon.client.cancelTurn(CancelTurnRequest(chatId: chat.id));
      } on Object catch (e) {
        waiting = false;
        steps = [];
        kept = '';
        error =
            "The turn didn't stop, so nothing was cleaned up: "
            '${errorText(e)}';
        notifyListeners();
        return;
      }
    }
    if (chat.busy && !await _turnEnds(picks.stopTurn)) return;
    waiting = false;
    notifyListeners();
    for (final s in steps) {
      if (cancelled) return;
      s.state = StepState.running;
      notifyListeners();
      try {
        await _do(daemon, s, picks, pull);
        s.state = StepState.done;
      } on Object catch (e) {
        s
          ..state = StepState.failed
          ..error = errorText(e);
      }
      notifyListeners();
    }
  }

  Future<void> _do(
    Daemon daemon,
    CleanUpStep s,
    CleanUpPicks picks,
    GitHubRef? pull,
  ) async {
    final c = daemon.client;
    switch (s.key) {
      case 'archive':
        await c.archiveChat(
          ArchiveChatRequest(chatId: chat.id, archived: true),
        );
        s.label = 'Chat archived';
      case 'worktree':
        await c.removeChatWorktree(
          RemoveChatWorktreeRequest(chatId: chat.id, force: picks.force),
        );
        s.label = 'Worktree deleted';
      case 'branch':
        await c.deleteChatBranch(
          DeleteChatBranchRequest(chatId: chat.id, force: picks.forceBranch),
        );
        s.label = 'Local branch deleted';
      case 'remote':
        final r = await c.deleteGitHubBranch(
          DeleteGitHubBranchRequest(ref: pull),
        );
        s.label = r.deleted
            ? 'Branch deleted on GitHub'
            : 'The branch on GitHub was gone already';
    }
  }

  /// Waits until the chat's turn ends: true then, false when cancelled.
  /// Stopping, it gives up after 20 s.
  Future<bool> _turnEnds(bool stopping) async {
    final done = Completer<bool>();
    void check() {
      if (done.isCompleted) return;
      if (cancelled) return done.complete(false);
      if (!chat.busy) return done.complete(true);
    }

    chat.addListener(check);
    addListener(check);
    Timer? limit;
    if (stopping) {
      limit = Timer(const Duration(seconds: 20), () {
        if (!done.isCompleted) done.complete(false);
      });
    }
    final ok = await done.future;
    limit?.cancel();
    chat.removeListener(check);
    removeListener(check);
    if (!ok) {
      waiting = false;
      steps = [];
      notifyListeners();
    }
    return ok;
  }

  /// Gives up a clean-up still waiting for the turn.
  void cancel() {
    cancelled = true;
    notifyListeners();
  }

  /// Makes the branch on GitHub again, at the pull request's head.
  Future<void> restore() async {
    final d = _daemon;
    final pull = _pull;
    if (d == null || pull == null) return;
    await d.client.restoreGitHubBranch(RestoreGitHubBranchRequest(ref: pull));
    steps.removeWhere((s) => s.key == 'remote');
    steps.insert(0, CleanUpStep('restored', 'Branch restored on GitHub'));
    steps.first.state = StepState.done;
    notifyListeners();
  }

  /// Unarchives the chat.
  Future<void> unarchive() async {
    final d = _daemon;
    if (d == null) return;
    await d.client.archiveChat(
      ArchiveChatRequest(chatId: chat.id, archived: false),
    );
    steps.removeWhere((s) => s.key == 'archive');
    notifyListeners();
  }

  /// Forgets a finished clean-up (the widget offers it again).
  void clear() {
    steps = [];
    kept = '';
    error = null;
    notifyListeners();
  }
}

/// A clean-up as the PR widget shows it: waiting for the turn (Cancel the
/// clean-up), each part as it goes (a failure says why), what it kept,
/// then Restore branch and Unarchive.
class CleanUpProgress extends StatelessWidget {
  const new(this.job, {super.key});

  final CleanUpJob job;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([job, job.chat]),
    builder: (context, _) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      final small = theme.ui(t.text, size: 12.5);
      Widget line(IconData? icon, Color color, String text, {Widget? lead}) =>
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 16,
                  height: 18,
                  child: Center(
                    child: lead ?? Icon(icon, size: 14, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: small)),
              ],
            ),
          );
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: box(t.borderSubtle, fill: t.raised),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (job.error case final e?)
              line(Icons.error_outline, t.crashed, e),
            if (job.waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Waiting for the turn to end…',
                  style: theme.ui(t.textSecondary, size: 12.5),
                ),
              ),
            for (final s in job.steps) ...[
              switch (s.state) {
                StepState.waiting => line(Icons.schedule, t.textMuted, s.label),
                StepState.running => line(
                  null,
                  t.textMuted,
                  s.label,
                  lead: SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: t.textMuted,
                    ),
                  ),
                ),
                StepState.done => line(Icons.check, t.done, s.label),
                StepState.failed => line(
                  Icons.error_outline,
                  t.crashed,
                  '${s.label}: ${s.error}',
                ),
              },
            ],
            if (job.finished && job.kept.isNotEmpty)
              line(Icons.remove_circle_outline, t.textMuted, job.kept),
            if (job.waiting)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LinkText(
                    'Cancel the clean-up',
                    size: 12,
                    onTap: job.cancel,
                  ),
                ),
              ),
            if (job.finished && (job.canRestore || job.canUnarchive))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (job.canRestore)
                      RunButton(
                        label: 'Restore branch',
                        icon: Icons.undo,
                        run: () => tryOrShow(context, job.restore),
                      ),
                    if (job.canUnarchive)
                      RunButton(
                        label: 'Unarchive',
                        run: () => tryOrShow(context, job.unarchive),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
