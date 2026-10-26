import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents_card.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/mcp_card.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/worktree.dart';

/// The panel beside a chat: cards for its environment (folder or
/// repository, branch, worktree), its context and cost, and its folder's
/// changes (uncommitted, or the branch's for a worktree chat), as the
/// Changes view shows them. They reload when a turn ends or the chat moves.
class DetailsPanel extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.onChanges,
    super.key,
  });

  static const width = 264.0;

  final ChatState chat;
  final Daemon daemon;
  final VoidCallback onChanges;

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
  String? _error;
  late GetContextUsageResponse? _context = _asked[chat.id]?.$2;

  /// What fills each chat's context, and when it was asked: kept across
  /// panels, so switching chats doesn't ask again.
  static final _asked = <String, (DateTime, GetContextUsageResponse)>{};
  Timer? _timer;

  /// Whether the agent can be asked what fills its context: the daemon
  /// says so, and the chat is idle.
  bool get _canAsk => chat.canAskContext && !chat.busy && !chat.archived;

  /// Asks the agent, unseen, what fills its context.
  Future<void> _askContext() async {
    try {
      final r = await daemon.client.getContextUsage(
        GetContextUsageRequest(chatId: chat.id),
      );
      _asked[chat.id] = (DateTime.now(), r);
      if (mounted) setState(() => _context = r);
    } on Object {
      // The card keeps what it had; it asks again after the next turn.
    }
  }

  /// Asks on its own while the Context card is open and the chat idle: a
  /// moment after a turn ends or the card opens, at most once a minute.
  void _schedule() {
    _timer?.cancel();
    bool ready() =>
        mounted && _canAsk && !collapsedCards.value.contains('Context');
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

  @override
  void initState() {
    super.initState();
    collapsedCards.addListener(_schedule);
  }

  @override
  void dispose() {
    _timer?.cancel();
    collapsedCards.removeListener(_schedule);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    _schedule();
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
      if (mounted) setState(() => _error = '$e');
    }
  }

  // Live with the chat (usage, subagents), not only when a turn ends.
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: chat, builder: (context, _) => _panel());

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FolderButton(
                    chat: chat,
                    daemon: daemon,
                    stacked: true,
                  ),
                ),
                if (!chat.archived)
                  IconTap(
                    Icons.terminal,
                    size: 14,
                    tooltip: 'Open in terminal',
                    onTap: () => tryOrShow(
                      context,
                      () => openTerminalIn(daemon, chat, chat.folder),
                    ),
                  ),
              ],
            ),
          ),
          if (status != null && status.git)
            ...worktreeRows(context, chat, daemon, status.branch),
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
        summary: ContextMeter(u),
        action: _context != null || _canAsk
            ? IconTap(
                Icons.refresh,
                tooltip: 'Ask again',
                size: 13,
                onTap: _canAsk ? _askContext : null,
              )
            : null,
        rows: [
          if (u.contextSize == 0 && cost(u).isEmpty && _context == null)
            (null, 'Not reported yet'),
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
              ContextBreakdown(c.categories),
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
      ?agentsCard(chat),
      mcpCard(chat, daemon),
    ]);
  }
}
