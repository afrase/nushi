import 'package:flutter/material.dart';

import 'chat.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';
import 'theme/theme.dart';
import 'usage.dart';
import 'worktree.dart';

/// The panel beside a chat: cards for its environment (folder or
/// repository, branch, worktree), its context and cost, and its folder's
/// uncommitted changes. The changes reload when a turn ends or the chat
/// moves.
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

class _DetailsPanelState extends State<DetailsPanel> {
  GetFolderStatusResponse? _status;
  String? _error;
  bool _wasBusy = false;
  late String _folder = widget.chat.folder;

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_chatChanged);
    _load();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_chatChanged);
    super.dispose();
  }

  void _chatChanged() {
    if (_wasBusy && !widget.chat.busy || _folder != widget.chat.folder) {
      _folder = widget.chat.folder;
      _load();
    }
    _wasBusy = widget.chat.busy;
  }

  Future<void> _load() async {
    if (!widget.daemon.canFolderStatus) return;
    try {
      final status = await widget.daemon.client.getFolderStatus(
        GetFolderStatusRequest(folder: widget.chat.folder),
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final chat = widget.chat;
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
    final value = theme.ui(t.text, size: 12);
    return Container(
      width: DetailsPanel.width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.borderSubtle)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Card(
            title: 'Environment',
            summary: Text(
              isScratch(chat.folder) ? 'No folder' : _name(chat.home),
              style: muted,
              overflow: TextOverflow.ellipsis,
            ),
            rows: [
              (
                chat.worktree == null ? 'Folder' : 'Repository',
                FolderButton(chat: chat, daemon: widget.daemon, stacked: true),
              ),
              if (status != null && status.git)
                ...worktreeRows(context, chat, widget.daemon, status.branch),
            ],
          ),
          _Card(
            title: 'Context',
            summary: ContextMeter(u),
            rows: u.contextSize == 0 && cost(u).isEmpty
                ? [
                    (
                      null,
                      Text('Claude reports it after a turn.', style: muted),
                    ),
                  ]
                : [
                    if (u.contextSize > 0) ...[
                      ('Used', ContextMeter(u)),
                      (
                        'Tokens',
                        Text(
                          '${tokens(u.contextUsed.toInt())} of ${tokens(u.contextSize.toInt())}',
                          style: value,
                        ),
                      ),
                    ],
                    if (lastTurn(u).isNotEmpty)
                      (
                        'Last turn',
                        Tooltip(
                          message: cacheUse(u).isEmpty
                              ? ''
                              : 'Cache: ${cacheUse(u)}',
                          child: Text(lastTurn(u), style: value),
                        ),
                      ),
                    if (cost(u).isNotEmpty)
                      (
                        'Cost',
                        Tooltip(
                          message:
                              'The session’s cost so far, as Claude reports it',
                          child: Text(cost(u), style: value),
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
                (null, Text(_error!, style: muted))
              else if (!widget.daemon.canFolderStatus)
                (null, Text('Needs a newer daemon.', style: muted))
              else if (status == null)
                (null, Text('…', style: muted))
              else if (!status.git)
                (null, Text('Not a git repository.', style: muted))
              else ...[
                ('Uncommitted', lines!),
                (
                  'Files',
                  Text(
                    status.files == 0 ? 'None' : '${status.files}',
                    style: value,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _name(String folder) => folder
    .split('/')
    .lastWhere((part) => part.isNotEmpty, orElse: () => folder);

/// A rounded card: a title that collapses it (remembered in
/// [collapsedCards]), with [summary] on its right while collapsed; then rows
/// of a quiet label on the left and a value on the right (a row without a
/// label is a line of its own). With [onTap] the rows are a button.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.rows,
    this.summary,
    this.onTap,
  });

  final String title;
  final List<(String?, Widget)> rows;
  final Widget? summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ValueListenableBuilder(
      valueListenable: collapsedCards,
      builder: (context, collapsed, _) {
        final open = !collapsed.contains(title);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: t.raised,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: t.borderSubtle),
              borderRadius: BorderRadius.circular(NushiTheme.card * 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => collapsedCards.value = open
                      ? {...collapsed, title}
                      : ({...collapsed}..remove(title)),
                  child: Padding(
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
                  InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (label, value) in rows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: label == null
                                  ? value
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          label,
                                          style: theme.ui(
                                            t.textMuted,
                                            size: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: value,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
