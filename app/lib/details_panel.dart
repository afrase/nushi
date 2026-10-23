import 'package:flutter/material.dart';

import 'changes_view.dart';
import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';
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
  GetFolderStatusResponse? _status;
  String? _error;

  @override
  Future<void> reload() async {
    if (!daemon.canFolderStatus) return;
    try {
      final status = await daemon.client.getFolderStatus(
        GetFolderStatusRequest(folder: chat.folder, base: base),
      );
      if (mounted) {
        setState(() {
          _status = status;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final u = chat.usage;
    final status = _status;
    final muted = theme.ui(t.textMuted, size: 12);
    final lines = status == null || !status.git
        ? null
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '+${status.added}',
                  style: theme.code(t.done, size: 12),
                ),
                TextSpan(
                  text: '  −${status.removed}',
                  style: theme.code(t.crashed, size: 12),
                ),
              ],
            ),
          );
    return Container(
      width: DetailsPanel.width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.borderSubtle)),
      ),
      child: _Cards([
        _Card(
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
        _Card(
          title: 'Context',
          summary: ContextMeter(u),
          rows: u.contextSize == 0 && cost(u).isEmpty
              ? [(null, 'Claude reports it after a turn.')]
              : [
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
                        message: cacheUse(u).isEmpty
                            ? ''
                            : 'Cache: ${cacheUse(u)}',
                        child: Text(
                          lastTurn(u),
                          style: theme.ui(t.text, size: 12),
                        ),
                      ),
                    ),
                  if (cost(u).isNotEmpty)
                    (
                      'Cost',
                      Tooltip(
                        message:
                            'The session’s cost so far, as Claude reports it',
                        child: Text(cost(u), style: theme.ui(t.text, size: 12)),
                      ),
                    ),
                ],
        ),
        _Card(
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
              (base.isEmpty ? 'Uncommitted' : 'Branch', lines!),
              ('Files', status.files == 0 ? 'None' : '${status.files}'),
            ],
          ],
        ),
      ]),
    );
  }
}

/// The cards in the order they were dragged into (remembered in
/// [cardOrder]; cards it doesn't name go last), each moved by dragging its
/// title row, without a lifted look.
class _Cards extends StatelessWidget {
  const _Cards(this.cards);

  final List<_Card> cards;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: cardOrder,
    builder: (context, saved, _) {
      final byTitle = {for (final c in cards) c.title: c};
      final titles = [
        ...saved.where(byTitle.containsKey),
        ...byTitle.keys.where((k) => !saved.contains(k)),
      ];
      return ReorderableListView(
        padding: const EdgeInsets.all(12),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, _, _) => child,
        onReorderItem: (from, to) {
          titles.insert(to, titles.removeAt(from));
          cardOrder.value = titles;
        },
        children: [
          for (final (i, title) in titles.indexed) byTitle[title]!.at(i),
        ],
      );
    },
  );
}

/// A rounded card: a title that collapses it (remembered in
/// [collapsedCards]), with [summary] on its right while collapsed; then rows
/// of a quiet label on the left and a value on the right (a row without a
/// label is a line of its own). With [onTap] the rows are a button.
class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.title,
    required this.rows,
    this.summary,
    this.onTap,
    this.index = 0,
  });

  /// This card as the [i]th of the list, which its title row drags in.
  _Card at(int i) => _Card(
    key: ValueKey(title),
    title: title,
    rows: rows,
    summary: summary,
    onTap: onTap,
    index: i,
  );

  final String title;
  final List<(String?, Object)> rows;
  final Widget? summary;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final muted = theme.ui(t.textMuted, size: 12);
    return ValueListenableBuilder(
      valueListenable: collapsedCards,
      builder: (context, collapsed, _) {
        final open = !collapsed.contains(title);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: box(
            t.borderSubtle,
            fill: t.raised,
            radius: NushiTheme.card * 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Tap(
                  onTap: () => collapsedCards.value = open
                      ? {...collapsed, title}
                      : ({...collapsed}..remove(title)),
                  radius: NushiTheme.card * 1.5,
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: theme.ui(
                          t.textSecondary,
                          size: 12,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        open ? Icons.expand_more : Icons.chevron_right,
                        size: 15,
                        color: t.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: open ? null : summary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (open)
                Tap(
                  onTap: onTap,
                  padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (label, v) in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: label == null
                              ? (v is String
                                    ? Text(v, style: muted)
                                    : v as Widget)
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: theme.ui(t.textMuted, size: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: v is String
                                            ? Text(
                                                v,
                                                style: theme.ui(
                                                  t.text,
                                                  size: 12,
                                                ),
                                              )
                                            : v as Widget,
                                      ),
                                    ),
                                  ],
                                ),
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
}
