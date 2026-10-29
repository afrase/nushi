import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/cleanup_job.dart';
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
Future<void> showCleanUp(
  BuildContext context,
  Daemon daemon,
  ChatState chat, {
  GitHubPull? pull,
}) async {
  final picks = await showDialog<CleanUpPicks>(
    context: context,
    builder: (_) => _CleanUpDialog(daemon, chat, pull),
  );
  if (picks == null) return;
  final ref = pull?.item.ref;
  unawaited(CleanUpJob.of(chat).run(daemon, picks, ref));
}

class _CleanUpDialog extends StatefulWidget {
  const new(this.daemon, this.chat, this.pull);

  final Daemon daemon;
  final ChatState chat;
  final GitHubPull? pull;

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
  bool get _merged => _pull?.item.state == 'merged';
  bool get _hasRemote =>
      _pull != null && (_merged || _pull!.item.state == 'closed');

  @override
  void initState() {
    super.initState();
    _archive = !widget.chat.archived;
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
            u.hasWorktree() &&
            !st.gone &&
            st.changed == 0 &&
            st.error.isEmpty &&
            u.others.isEmpty &&
            !u.worktree.found;
        _branch = _canBranch && (st.commits == 0 || _merged);
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
    final busy = chat.busy;
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
        if (u.hasWorktree())
          _Choice(
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
                ? _Dirty(
                    u,
                    onShow: () {
                      chat.tab.value = ChatTab.changes;
                      Navigator.pop(context);
                    },
                  )
                : st.ignored > 0 && _worktree
                ? Text(
                    st.ignored == 1
                        ? '1 ignored file or folder goes with it.'
                        : '${st.ignored} ignored files or folders go with it.',
                    style: theme.ui(t.textMuted, size: 12),
                  )
                : null,
          ),
        if (u.hasWorktree() && !st.branchGone)
          _Choice(
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
          _Choice(
            label: 'Delete the branch on GitHub',
            code: p!.crossRepo ? '${p.headRepo}:${p.head}' : p.head,
            value: _remote,
            onChanged: (v) => setState(() => _remote = v),
            what: _merged
                ? 'GitHub kept it. The pull request can restore it.'
                : 'Its commits stay in the pull request on GitHub.',
          ),
        if (!chat.archived)
          _Choice(
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
          if (busy) ...[
            _MidTurn(
              agent: chat.agentName,
              stop: _stopTurn,
              onChanged: (v) => setState(() => _stopTurn = v),
            ),
            const SizedBox(height: 8),
          ],
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: t.borderSubtle),
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
    return nushiDialog(title, SingleChildScrollView(child: body), [
      Button(label: 'Cancel', onPressed: () => Navigator.pop(context)),
      Button(
        label: loss.isNotEmpty
            ? 'Clean up, losing $loss'
            : busy && !_stopTurn
            ? 'Clean up when done'
            : 'Clean up',
        kind: loss.isNotEmpty ? ButtonKind.destructive : ButtonKind.primary,
        autofocus: true,
        onPressed: u == null || !any
            ? null
            : () => Navigator.pop<CleanUpPicks>(context, (
                archive: _archive && !chat.archived,
                worktree: _worktree,
                force: _worktree && (st?.changed ?? 0) > 0,
                branch: _branch && _canBranch,
                forceBranch: _branch && _canBranch && (st?.commits ?? 0) > 0,
                remote: _remote && _hasRemote,
                stopTurn: busy && _stopTurn,
              )),
      ),
    ]);
  }
}

/// A row to tick: what, its name in code, why it is as it is.
class _Choice extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    this.code,
    this.what,
    this.note,
    this.extra,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? code;
  final String? what;
  final String? note;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final on = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 22,
            child: Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: on ? (v) => onChanged!(v ?? false) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  label,
                  style: theme.ui(
                    on ? t.text : t.textMuted,
                    weight: FontWeight.w500,
                  ),
                ),
                if (code case final c?)
                  Text(c, style: theme.code(t.textMuted, size: 11.5)),
                if (what case final w?)
                  Text(w, style: theme.ui(t.textSecondary, size: 12)),
                if (note case final n?)
                  Text(n, style: theme.ui(t.needs, size: 12)),
                if (extra case final e?)
                  Padding(padding: const EdgeInsets.only(top: 4), child: e),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The uncommitted changes removing the worktree would lose, and Show the
/// changes.
class _Dirty extends StatelessWidget {
  const new(this.u, {required this.onShow});

  final GetCleanUpResponse u;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final n = u.state.changed;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: box(t.findingsBorder, fill: t.findingsTint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 3,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: t.findingsAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 uncommitted file would be lost.'
                      : '$n uncommitted files would be lost.',
                  style: theme.ui(t.text, size: 12.5, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          for (final c in u.changes)
            Text(c, style: theme.code(t.textSecondary, size: 11.5)),
          if (n > u.changes.length)
            Text(
              'and ${n - u.changes.length} more',
              style: theme.ui(t.textMuted, size: 12),
            ),
          LinkText('Show the changes', size: 12, onTap: onShow),
        ],
      ),
    );
  }
}

/// The chat is mid-turn: clean up when the turn ends, or stop it now.
class _MidTurn extends StatelessWidget {
  const new({required this.agent, required this.stop, required this.onChanged});

  final String agent;
  final bool stop;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    Widget choice(String words, {required bool value}) => Tap(
      onTap: () => onChanged(value),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        children: [
          Icon(
            stop == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 16,
            color: stop == value ? t.accentInk : t.textMuted,
          ),
          const SizedBox(width: 8),
          Text(words, style: theme.ui(t.text, size: 12.5)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: box(t.userBandBorder, fill: t.accentSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$agent is mid-turn here.',
            style: theme.ui(t.text, weight: FontWeight.w500),
          ),
          choice('Clean up when the turn ends', value: false),
          choice('Stop the turn, clean up now', value: true),
        ],
      ),
    );
  }
}
