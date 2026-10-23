import 'dart:async';

import 'package:flutter/material.dart';

import 'changes_span.dart';
import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'panel_cards.dart';
import 'markdown.dart';
import 'settings.dart';
import 'subagents.dart';
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
  GetContextUsageResponse? _context; // what fills the context, last asked
  Timer? _askSoon;

  @override
  void initState() {
    super.initState();
    collapsedCards.addListener(_cardsChanged);
  }

  @override
  void dispose() {
    collapsedCards.removeListener(_cardsChanged);
    _askSoon?.cancel();
    super.dispose();
  }

  void _cardsChanged() => _askContext(Duration.zero);

  /// Asks the agent, unseen, what fills its context ([after] a turn ends,
  /// say): only while the Context card is open and the chat idle, and when
  /// the agent has a /context command. Not before the first message: Claude
  /// would name the chat after /context. The last answer stays meanwhile.
  void _askContext([Duration after = const Duration(milliseconds: 800)]) {
    _askSoon?.cancel();
    _askSoon = Timer(after, () async {
      if (!mounted ||
          daemon.daemonApi < 25 ||
          chat.busy ||
          chat.fresh ||
          chat.archived ||
          collapsedCards.value.contains('Context') ||
          !chat.commands.any((c) => c.name == 'context')) {
        return;
      }
      try {
        final r = await daemon.client.getContextUsage(
          GetContextUsageRequest(chatId: chat.id),
        );
        if (mounted) setState(() => _context = r);
      } on Object {
        // Busy after all, or gone: the last answer stands.
      }
    });
  }

  @override
  Future<void> reload() async {
    _askContext();
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
            FolderButton(chat: chat, daemon: daemon, stacked: true),
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
          if (_context case final c?) ...[
            (
              'By category',
              IconTap(
                Icons.refresh,
                tooltip: 'Ask Claude again',
                size: 13,
                onTap: chat.busy ? null : () => _askContext(Duration.zero),
              ),
            ),
            (
              null,
              c.categories.isEmpty
                  ? AgentMarkdown(c.markdown)
                  : ContextBreakdown(c.categories),
            ),
          ],
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
      if (subagentsOf(chat.items, busy: chat.busy) case final subs
          when subs.isNotEmpty)
        PanelCard(
          title: 'Agents',
          summary: Text(
            '${subs.length} subagent${subs.length == 1 ? '' : 's'}',
            style: muted,
          ),
          rows: [
            for (final s in subs)
              (
                null,
                Tap(
                  onTap: () => chat.reveal.value = s.call.id,
                  tooltip: 'Show it in the chat',
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.call.agent}: ${s.call.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(t.text, size: 12),
                      ),
                      Text(
                        subagentState(s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.ui(
                          s.call.status == 'failed' ? t.crashed : t.textMuted,
                          size: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
    ]);
  }
}
