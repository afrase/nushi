import 'dart:async';

import 'package:flutter/material.dart';

import 'changes_span.dart';
import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'panel_cards.dart';
import 'settings.dart';
import 'terminal_panel.dart';
import 'markdown.dart';
import 'mcp_card.dart';
import 'agents_card.dart';
import 'theme/theme.dart';
import 'usage.dart';
import 'widgets.dart';
import 'worktree.dart';

/// The panel beside a chat: cards for its environment (folder or
/// repository, branch, worktree), its context and cost, and its folder's
/// changes (uncommitted, or the branch's for a worktree chat), as the
/// Changes view shows them. They reload when a turn ends or the chat moves.
class DetailsPanel extends StatefulWidget {
  const DetailsPanel({
    super.key,
    required this.chat,
    required this.daemon,
    required this.onChanges,
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

  /// Whether the agent can be asked what fills its context: it has a
  /// /context command, the chat is idle and has messages (Claude would
  /// name a new chat after /context).
  bool get _canAsk =>
      daemon.daemonApi >= 25 &&
      !chat.busy &&
      !chat.fresh &&
      !chat.archived &&
      chat.commands.any((c) => c.name == 'context');

  /// Whether the daemon asks in a throwaway fork of the session (API 31),
  /// so the card can ask on its own: in the chat's own session Claude keeps
  /// /context's answer, a few thousand tokens each time, so it then asks
  /// only on its refresh button.
  bool get _auto => daemon.daemonApi >= 31 && chat.canFork;

  /// Asks the agent, unseen, what fills its context.
  Future<void> _askContext() async {
    try {
      final r = await daemon.client.getContextUsage(
        GetContextUsageRequest(chatId: chat.id),
      );
      _asked[chat.id] = (DateTime.now(), r);
      if (mounted) setState(() => _context = r);
    } on Object catch (e) {
      if (mounted && !_auto) showError(context, e);
    }
  }

  /// Asks on its own while the Context card is open and the chat idle: a
  /// moment after a turn ends or the card opens, at most once a minute.
  void _schedule() {
    _timer?.cancel();
    bool ready() =>
        mounted &&
        _auto &&
        _canAsk &&
        !collapsedCards.value.contains('Context');
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
      if (ready()) _askContext();
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
    if (!daemon.canFolderStatus) return;
    try {
      final span = await ChangeSpan.of(daemon, chat);
      final branch = span.scope == Scope.branch;
      final status = !span.status.git
          ? span.status
          : await daemon.client.getFolderStatus(
              GetFolderStatusRequest(
                folder: chat.folder,
                base: branch ? span.base : null,
              ),
            );
      final commits = span.scope == Scope.commits && status.git
          ? (await daemon.client.listCommits(
              ListCommitsRequest(folder: chat.folder, base: span.commitsBase),
            )).commits
          : <Commit>[];
      if (mounted) {
        setState(() {
          _status = status;
          _scope = span.scope;
          _commits = commits;
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
    final theme = NushiTheme.of(context), t = theme.t;
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
          folderParts(chat.home).$1,
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
                if (daemon.canTerminals && !chat.archived)
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
                    : 'Its worktree was removed outside Nushi. Delete '
                          'the chat to clean up its branch '
                          '${chat.worktree!.branch}.',
                style: theme.ui(t.crashed, size: 12),
              ),
            ),
        ],
      ),
      PanelCard(
        title: 'Context',
        summary: ContextMeter(u),
        rows: [
          if (u.contextSize == 0 && cost(u).isEmpty && _context == null)
            (null, 'Claude reports it after a turn.'),
          if (u.contextSize > 0) ...[
            ('Used', ContextMeter(u)),
            (
              'Tokens',
              '${tokens(u.contextUsed.toInt())} of '
                  '${tokens(u.contextSize.toInt())}',
            ),
          ],
          if (lastTurn(u).isNotEmpty)
            (
              'Last turn',
              Tooltip(
                message: cacheUse(u).isEmpty ? '' : 'Cache: ${cacheUse(u)}',
                child: Text(lastTurn(u), style: theme.ui(t.text, size: 12)),
              ),
            ),
          if (cost(u).isNotEmpty)
            (
              'Cost',
              Tooltip(
                message: 'The session’s cost so far, as Claude reports it',
                child: Text(cost(u), style: theme.ui(t.text, size: 12)),
              ),
            ),
          if (_context != null || _canAsk)
            (
              'By category',
              IconTap(
                Icons.refresh,
                tooltip: _auto
                    ? 'Ask Claude again (/context, in a copy of the chat)'
                    : 'Ask Claude (/context). Its answer stays in the '
                          'conversation: a few thousand tokens each time.',
                size: 13,
                onTap: _canAsk ? _askContext : null,
              ),
            ),
          if (_context case final c?)
            (
              null,
              c.categories.isEmpty
                  ? AgentMarkdown(c.markdown)
                  : ContextBreakdown(c.categories),
            ),
        ],
      ),
      PanelCard(
        title: 'Changes',
        summary: lines,
        onTap: status != null && status.git ? widget.onChanges : null,
        rows: [
          if (_error != null)
            (null, _error!)
          else if (!daemon.canFolderStatus)
            (null, 'Needs a newer daemon.')
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
      ?mcpCard(chat, daemon),
    ]);
  }
}
