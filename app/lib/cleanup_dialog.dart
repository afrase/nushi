import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/cleanup_job.dart';
import 'package:nushi/cleanup_parts.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// Clean up…: asks what goes once [chat]'s pull request ([pull], if it
/// has one) merged or closed, then runs it ([CleanUpJob]): the branch on
/// GitHub, the chat archived, its worktree, its local branch. Each row
/// says what it costs: a worktree with uncommitted changes starts
/// unticked, and ticking it makes the button red and names the loss; the
/// local branch can't go while its worktree stays; mid-turn it waits for
/// the turn to end, or stops it. Nothing goes that the dialog didn't name.
///
/// [openOnBranch] are the chat's other pull requests still open on its
/// branch (ADR 0117): while there are any, only [pull]'s branch on GitHub
/// can go; the dialog names them, and the worktree, the local branch and
/// archiving wait until they merge or close.
Future<void> showCleanUp(
  BuildContext context,
  Daemon daemon,
  ChatState chat, {
  GitHubPull? pull,
  List<int> openOnBranch = const [],
  String branch = '',
}) async {
  final picks = await showDialog<CleanUpPicks>(
    context: context,
    builder: (_) => _CleanUpDialog(daemon, chat, pull, openOnBranch, branch),
  );
  if (picks == null) return;
  final ref = pull?.item.ref;
  unawaited(CleanUpJob.of(chat).run(daemon, picks, ref));
}

class _CleanUpDialog extends StatefulWidget {
  const new(this.daemon, this.chat, this.pull, this.openOnBranch, this.branch);

  final Daemon daemon;
  final ChatState chat;
  final GitHubPull? pull;
  final List<int> openOnBranch;
  final String branch;

  @override
  State<_CleanUpDialog> createState() => _CleanUpDialogState();
}

class _CleanUpDialogState extends State<_CleanUpDialog> {
  GetCleanUpResponse? _u;
  String? _error;
  bool _worktree = false;
  bool _branch = false;
  bool _remote = false;
  bool _archive = true;
  bool _stopTurn = false;

  GitHubPull? get _pull => widget.pull;

  /// The worktree, the local branch and archiving are offered: no other
  /// pull request is still open on the chat's branch.
  bool get _local => widget.openOnBranch.isEmpty;
  bool get _merged => _pull?.item.state == 'merged';
  bool get _hasRemote =>
      _pull != null && (_merged || _pull!.item.state == 'closed');

  @override
  void initState() {
    super.initState();
    _archive = _local && !widget.chat.archived;
    _remote = _merged;
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final u = await widget.daemon.client.getCleanUp(
        GetCleanUpRequest(chatId: widget.chat.id),
      );
      if (!mounted) return;
      final st = u.state;
      setState(() {
        _u = u;
        // What loses nothing starts ticked; what would, unticked.
        _worktree =
            _local &&
            u.hasWorktree() &&
            !st.gone &&
            st.changed == 0 &&
            st.ignored == 0 &&
            st.error.isEmpty &&
            u.others.isEmpty &&
            !u.worktree.found;
        _branch = _local && _canBranch && (st.commits == 0 || _merged);
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  /// The local branch can go: it's there, and no worktree keeps it.
  bool get _canBranch {
    final u = _u;
    if (u == null || !u.hasWorktree()) return false;
    final st = u.state;
    return !st.branchGone &&
        !u.branchElsewhere &&
        st.error.isEmpty &&
        (_worktree || st.gone);
  }

  /// Which of the chat's pull requests are still open on its branch, and
  /// what waits for them: "#221 and #224 are still open on cursor-ties:
  /// …".
  String get _stillOpen {
    final n = [for (final x in widget.openOnBranch) '#$x'];
    final which = n.length == 1
        ? '${n.single} is'
        : '${n.sublist(0, n.length - 1).join(', ')} and ${n.last} are';
    final on = widget.branch.isEmpty ? "this chat's branch" : widget.branch;
    return '$which still open on $on. The worktree, its branch and this '
        'chat stay until ${n.length == 1 ? 'it merges or closes' : 'they '
                  'merge or close'}.';
  }

  /// What can't be got back, in words; empty when nothing.
  String get _loss {
    final u = _u;
    if (u == null) return '';
    final st = u.state;
    final commits = st.commits;
    final parts = [
      if (_worktree && st.changed == 1)
        '1 file'
      else if (_worktree && st.changed > 1)
        '${st.changed} files',
      if (_worktree && st.ignored == 1)
        '1 ignored file'
      else if (_worktree && st.ignored > 1)
        '${st.ignored} ignored files',
      if (_branch && _canBranch && !_merged && commits == 1)
        '1 commit'
      else if (_branch && _canBranch && !_merged && commits > 1)
        '$commits commits',
    ];
    return parts.join(' and ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final u = _u;
    final chat = widget.chat;
    final p = _pull;
    // Mid-turn matters only to what's local: the branch on GitHub goes now.
    final busy = chat.busy && _local;
    final title = p == null
        ? 'Clean up'
        : 'Clean up after #${p.item.ref.number}';
    Widget body;
    if (u == null) {
      body = Text(
        _error ?? 'Looking at the worktree…',
        style: theme.ui(_error == null ? t.textMuted : t.crashed),
      );
    } else {
      final st = u.state;
      final wt = u.worktree;
      final name = wt.path.split('/').last;
      final rows = <Widget>[
        if (u.hasWorktree() && _local)
          CleanUpChoice(
            label: 'Delete the worktree',
            value: _worktree,
            onChanged: st.gone || u.others.isNotEmpty || st.error.isNotEmpty
                ? null
                : (v) => setState(() {
                    _worktree = v;
                    if (!v && !st.gone) _branch = false;
                  }),
            what: st.gone
                ? 'Its folder is gone already.'
                : st.error.isNotEmpty
                ? "Nushi can't tell what's in it: ${st.error}"
                : u.others.isNotEmpty
                ? '“${u.others.join('”, “')}” works in it too.'
                : null,
            code: [
              if (wt.path.contains('/.worktrees/'))
                '.worktrees/$name'
              else
                tildePath(wt.path),
              if (st.changed == 0 && !st.gone && st.error.isEmpty) 'clean',
            ].join(' · '),
            note: wt.found && !st.gone ? 'Made outside Nushi.' : null,
            extra: st.changed > 0 && !st.gone
                ? DirtyWorktree(
                    u,
                    onShow: () {
                      chat.tab.value = ChatTab.changes;
                      Navigator.pop(context);
                    },
                  )
                : st.ignored > 0 && !st.gone
                ? Text(
                    st.ignored == 1
                        ? '1 ignored file or folder goes with it.'
                        : '${st.ignored} ignored files or folders go with it.',
                    style: theme.ui(t.textMuted, size: 12),
                  )
                : null,
          ),
        if (u.hasWorktree() && !st.branchGone && _local)
          CleanUpChoice(
            label: 'Delete the local branch',
            code: wt.branch,
            value: _branch && _canBranch,
            onChanged: _canBranch ? (v) => setState(() => _branch = v) : null,
            what: u.branchElsewhere
                ? 'Another worktree has it checked out.'
                : !_canBranch
                ? "The worktree you're keeping has it checked out."
                : st.commits == 0
                ? '${wt.base} has its commits.'
                : _merged
                ? "Squash-merged, so git can't tell. GitHub says "
                      '#${p!.item.ref.number} merged it.'
                : st.commits == 1
                ? "Its commit isn't in ${wt.base}."
                : "Its ${st.commits} commits aren't in ${wt.base}.",
          ),
        if (_hasRemote)
          CleanUpChoice(
            label: 'Delete the branch on GitHub',
            code: p!.crossRepo ? '${p.headRepo}:${p.head}' : p.head,
            value: _remote,
            onChanged: (v) => setState(() => _remote = v),
            what: _merged
                ? 'GitHub kept it. The pull request can restore it.'
                : 'Its commits stay in the pull request on GitHub.',
          ),
        if (!chat.archived && _local)
          CleanUpChoice(
            label: 'Archive this chat',
            value: _archive,
            onChanged: (v) => setState(() => _archive = v),
            what: busy
                ? (_stopTurn ? 'Once its turn stops.' : 'When the turn ends.')
                : 'Still resumable from the terminal.',
          ),
      ];
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_local) ...[
            Text(
              _stillOpen,
              key: const ValueKey('cleanup-still-open'),
              style: theme.ui(t.textSecondary, size: 12),
            ),
            const SizedBox(height: 10),
          ],
          if (busy) ...[
            MidTurnChoice(
              agent: chat.agentName,
              stop: _stopTurn,
              onChanged: (v) => setState(() => _stopTurn = v),
            ),
            const SizedBox(height: 8),
          ],
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: t.line),
            r,
          ],
        ],
      );
    }
    final loss = _loss;
    final any =
        _worktree ||
        (_branch && _canBranch) ||
        (_remote && _hasRemote) ||
        (_archive && !chat.archived);
    final st = u?.state;
    // Cleaning up deletes a worktree or a branch, and a tick can make it
    // lose work while the focus stays put: Cancel has the focus, so Enter
    // never deletes (docs/design.md).
    return nushiDialog(title, SingleChildScrollView(child: body), [
      Button(
        label: 'Cancel',
        autofocus: true,
        onPressed: () => Navigator.pop(context),
      ),
      Button(
        label: loss.isNotEmpty
            ? 'Clean up, losing $loss'
            : busy && !_stopTurn
            ? 'Clean up when done'
            : 'Clean up',
        kind: loss.isNotEmpty ? ButtonKind.destructive : ButtonKind.primary,
        onPressed: u == null || !any
            ? null
            : () => Navigator.pop<CleanUpPicks>(context, (
                archive: _archive && !chat.archived,
                worktree: _worktree,
                force:
                    _worktree &&
                    ((st?.changed ?? 0) > 0 || (st?.ignored ?? 0) > 0),
                branch: _branch && _canBranch,
                forceBranch: _branch && _canBranch && (st?.commits ?? 0) > 0,
                remote: _remote && _hasRemote,
                stopTurn: busy && _stopTurn,
              )),
      ),
    ]);
  }
}
