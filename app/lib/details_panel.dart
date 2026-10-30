import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nushi/artifacts_widget.dart';
import 'package:nushi/background_tasks_widget.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/mcp_widget.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_widget.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The panel beside a chat: widgets for its environment (folder or
/// repository, branch, worktree), its context and cost, and its folder's
/// changes (uncommitted, or the branch's for a worktree chat), as the
/// Changes view shows them, its background tasks, MCP servers and artifacts.
/// They reload when a turn ends or the chat moves.
class DetailsPanel extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    super.key,
    this.onPull,
  });

  static const width = 264.0;

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;

  /// Shows the chat's pull request's tab.
  final VoidCallback? onPull;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel> with FollowsChanges {
  @override
  ChatState get chat => widget.chat;
  @override
  Daemon get daemon => widget.daemon;
  GetFolderStatusResponse? _status; // counted as the Changes view shows
  Scope _scope = Scope.uncommitted;
  List<Commit> _commits = []; // in Commits
  ListBranchesResponse? _branches; // for the Branch row's menu
  String? _error;
  late GetContextUsageResponse? _context = lastContext(chat.id)?.$2;
  Timer? _timer;
  bool _asking = false;
  bool _couldAsk = false; // the last time the chat changed
  late ChatPull _pull;

  /// Whether the agent can be asked what fills its context: the daemon
  /// says so, and the chat is idle.
  bool get _canAsk => chat.canAskContext && !chat.busy && !chat.archived;

  /// Asks the agent, unseen, what fills its context.
  Future<void> _askContext() async {
    if (mounted) setState(() => _asking = true);
    try {
      final r = await daemon.client.getContextUsage(
        GetContextUsageRequest(chatId: chat.id),
      );
      askedContext(chat.id, r);
      if (mounted) setState(() => _context = r);
    } on Object {
      // The widget keeps what it had; it asks again after the next turn.
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  /// Asks on its own whenever the chat is idle, the Context widget open or
  /// not (so it's there when opened): a moment after a turn ends or the
  /// chat becomes askable (woken, its commands listed), at most once a
  /// minute.
  void _schedule() {
    _timer?.cancel();
    bool ready() => mounted && _canAsk;
    if (!ready()) return;
    final last = contextAskedAt(chat.id);
    var wait = const Duration(seconds: 1);
    if (last != null) {
      final next = last
          .add(const Duration(minutes: 1))
          .difference(DateTime.now());
      if (next > wait) wait = next;
    }
    _timer = Timer(wait, () {
      if (ready()) unawaited(_askContext());
    });
  }

  /// The chat became askable (idle, awake, its commands listed): ask.
  void _onChat() {
    final can = _canAsk;
    if (can && !_couldAsk) _schedule();
    _couldAsk = can;
  }

  @override
  void initState() {
    super.initState();
    _couldAsk = _canAsk;
    chat.addListener(_onChat);
    _pull = ChatPull.of(daemon, chat)..follow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    chat.removeListener(_onChat);
    _pull.unfollow();
    super.dispose();
  }

  /// The folder's branches and worktrees, for the Branch row's menu: asked
  /// with the rest, and again as the menu opens.
  Future<void> _listBranches() async {
    try {
      final r = await daemon.client.listBranches(
        ListBranchesRequest(folder: chat.folder),
      );
      if (mounted) setState(() => _branches = r);
    } on Object {
      // Outside git, or gone: the menu says Loading… until asked again.
    }
  }

  @override
  Future<void> reload() async {
    _schedule();
    unawaited(_listBranches());
    try {
      final span = await ChangeSpan.of(daemon, chat);
      if (mounted) {
        setState(() {
          _status = span.status;
          _scope = span.scope;
          _commits = span.commits;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  // Live with the chat (usage, subagents), not only when a turn ends; and
  // with its side chat coming and going (its line follows its usage).
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chat, chat.side, _pull]),
    builder: (context, _) => _panel(chat.side.value),
  );

  /// The Context widget's line for [side], the chat's side chat: its own
  /// meter and cost, always under the chat's, so neither changes meaning
  /// with the focus. What fills it isn't asked: the breakdown is the chat's.
  (String, Object) _sideRow(ChatState side) => (
    'Side chat',
    ListenableBuilder(
      listenable: side,
      builder: (context, _) {
        final theme = NushiTheme.of(context);
        final t = theme.t;
        final u = side.usage;
        final spent = cost(u);
        if (u.contextSize == 0 && spent.isEmpty) {
          return Text(
            'Not reported yet',
            style: theme.ui(t.textMuted, size: 12),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            if (u.contextSize > 0)
              Tooltip(
                message:
                    '${tokens(u.contextUsed.toInt())} / '
                    '${tokens(u.contextSize.toInt())}',
                child: ContextMeter(u),
              ),
            if (spent.isNotEmpty)
              Text(spent, style: theme.ui(t.text, size: 12)),
          ],
        );
      },
    ),
  );

  Widget _panel(ChatState? side) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final u = chat.usage;
    final status = _status;
    final muted = theme.ui(t.textMuted, size: 12);
    final commits = _scope == Scope.commits;
    final (added, removed) = commits
        ? _commits.fold((0, 0), (n, c) => (n.$1 + c.added, n.$2 + c.removed))
        : (status?.added ?? 0, status?.removed ?? 0);
    final lines = status == null || !status.git
        ? null
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '+$added', style: theme.code(t.done, size: 12)),
                TextSpan(
                  text: '  −$removed',
                  style: theme.code(t.crashed, size: 12),
                ),
              ],
            ),
          );
    return PanelWidgets([
      PanelWidget(
        title: 'Environment',
        summary: Text(
          folderParts(chat.home, scratch: chat.scratch).$1,
          style: muted,
          overflow: TextOverflow.ellipsis,
        ),
        rows: [
          (
            chat.worktree == null ? 'Folder' : 'Repository',
            FolderButton(chat: chat, daemon: daemon, stacked: true),
          ),
          if (status != null && status.git)
            ...worktreeRows(
              context,
              chat,
              daemon,
              status.branch,
              list: _branches,
              onOpen: () => unawaited(_listBranches()),
              onChanged: () => unawaited(reload()),
              onChanges: widget.onChanges,
            ),
          if (status != null && status.gone)
            (
              null,
              Text(
                chat.worktree == null
                    ? 'The folder is gone.'
                    : 'Its worktree was removed. Delete the chat to clean '
                          'up its branch ${chat.worktree!.branch}.',
                style: theme.ui(t.crashed, size: 12),
              ),
            ),
        ],
      ),
      PanelWidget(
        title: 'Context',
        // Nothing to show yet: one line.
        note:
            side == null &&
                u.contextSize == 0 &&
                cost(u).isEmpty &&
                lastTurn(u).isEmpty &&
                _context == null &&
                !_asking
            ? 'Not reported yet'
            : null,
        summary: ContextMeter(u, breakdown: _context),
        rows: [
          if (u.contextSize == 0 && cost(u).isEmpty && _context == null)
            (null, 'Not reported yet'),
          // Why there's no breakdown yet.
          if (_context == null && (u.contextSize > 0 || _asking))
            (
              null,
              _asking
                  ? 'Asking what fills it…'
                  : chat.asleep
                  ? 'What fills it, once the chat is awake'
                  : chat.busy
                  ? 'What fills it, after this turn'
                  : _canAsk
                  ? 'What fills it, in a moment'
                  : "The agent can't say what fills it",
            ),
          // "4% used … 37.4k / 1M", then the bar.
          if (u.contextSize > 0)
            (
              null,
              Row(
                children: [
                  Expanded(child: ContextUsed(u)),
                  Text(
                    '${tokens(u.contextUsed.toInt())} / '
                    '${tokens(u.contextSize.toInt())}',
                    style: theme.ui(t.text, size: 12),
                  ),
                ],
              ),
            ),
          switch (_context) {
            final c? when c.categories.isNotEmpty => (
              null,
              // As last asked, brought up to the agent's latest count.
              ContextBreakdown(liveCategories(c.categories, u)),
            ),
            final c? => (null, AgentMarkdown(c.markdown)),
            null when u.contextSize > 0 => (null, UsageBar(u)),
            null => (null, const SizedBox.shrink()),
          },
          if (lastTurn(u).isNotEmpty)
            (
              'Last turn',
              Tooltip(
                message: cacheUse(u).isEmpty ? '' : 'Cache: ${cacheUse(u)}',
                child: Text(lastTurn(u), style: theme.ui(t.text, size: 12)),
              ),
            ),
          if (cost(u).isNotEmpty)
            ('Cost', Text(cost(u), style: theme.ui(t.text, size: 12))),
          if (side != null) _sideRow(side),
        ],
      ),
      PanelWidget(
        title: 'Changes',
        note: _error == null && status != null && !status.git
            ? (status.gone ? 'The folder is gone' : 'Not a git repository')
            : null,
        summary: lines,
        onTap: status != null && status.git ? widget.onChanges : null,
        rows: [
          if (_error != null)
            (null, _error!)
          else if (status == null)
            (null, '…')
          else if (!status.git)
            (
              null,
              status.gone ? 'The folder is gone.' : 'Not a git repository.',
            )
          else ...[
            (_scope.label, lines!),
            if (commits)
              ('Number', _commits.isEmpty ? 'None' : '${_commits.length}')
            else
              ('Files', status.files == 0 ? 'None' : '${status.files}'),
          ],
        ],
      ),
      ?pullWidget(_pull, onShow: widget.onPull),
      ?backgroundTasksWidget(chat, daemon),
      mcpWidget(chat, daemon),
      ?artifactsWidget(chat),
    ]);
  }
}
