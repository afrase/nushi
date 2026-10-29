import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents_card.dart';
import 'package:nushi/artifacts_card.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/mcp_card.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/pull_card.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The panel beside a chat: cards for its environment (folder or
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
  late GetContextUsageResponse? _context = _last(chat.id)?.$2;

  /// What fills each chat's context, and when it was asked: kept across
  /// panels, so switching chats doesn't ask again.
  static final _asked = <String, (DateTime, GetContextUsageResponse)>{};

  /// What was last asked of [id]'s chat: in this run, else as remembered
  /// from an earlier one.
  static (DateTime, GetContextUsageResponse)? _last(String id) =>
      _asked[id] ?? recalledContext(id);
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
      _asked[chat.id] = (DateTime.now(), r);
      rememberContext(chat.id, r);
      if (mounted) setState(() => _context = r);
    } on Object {
      // The card keeps what it had; it asks again after the next turn.
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  /// Asks on its own whenever the chat is idle, the Context card open or
  /// not (so it's there when opened): a moment after a turn ends or the
  /// chat becomes askable (woken, its commands listed), at most once a
  /// minute.
  void _schedule() {
    _timer?.cancel();
    bool ready() => mounted && _canAsk;
    if (!ready()) return;
    final last = _asked[chat.id]?.$1;
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
    _pull = ChatPull.of(daemon, chat)..watch();
  }

  @override
  void didUpdateWidget(DetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    // Another chat: follow it, with what was asked of it.
    old.chat.removeListener(_onChat);
    widget.chat.addListener(_onChat);
    _pull.unwatch();
    _pull = ChatPull.of(daemon, chat)..watch();
    _timer?.cancel();
    _context = _last(chat.id)?.$2;
    _couldAsk = _canAsk;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    chat.removeListener(_onChat);
    _pull.unwatch();
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

  // Live with the chat (usage, subagents), not only when a turn ends.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chat, _pull]),
    builder: (context, _) => _panel(),
  );

  Widget _panel() {
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
    return PanelCards([
      PanelCard(
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
      PanelCard(
        title: 'Context',
        // Nothing to show yet: one line.
        note:
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
        ],
      ),
      PanelCard(
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
      ?pullCard(_pull, onShow: widget.onPull),
      ?agentsCard(chat, daemon),
      mcpCard(chat, daemon),
      if (daemon.daemonApi >= previewApi) ?artifactsCard(chat),
    ]);
  }
}
