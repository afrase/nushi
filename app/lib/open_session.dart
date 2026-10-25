import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agents.dart';
import 'commits.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// The New chat dialog's second step: [agent]'s sessions in [folder] ('':
/// every folder's) that aren't chats, newest first, for [onOpen]. The
/// arrows move, Enter opens, ← or Esc goes [onBack].
class SessionList extends StatefulWidget {
  const SessionList({
    super.key,
    required this.daemon,
    required this.agent,
    required this.folder,
    required this.onOpen,
    required this.onBack,
  });

  final Daemon daemon;
  final String agent;
  final String folder;
  final ValueChanged<FoundSession> onOpen;
  final VoidCallback onBack;

  @override
  State<SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  final _sessions = <FoundSession>[];
  ListAgentSessionsResponse? _last;
  String? _error;
  bool _loading = false;
  int _at = 0;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    setState(() => _loading = true);
    try {
      final r = await widget.daemon.client.listAgentSessions(
        ListAgentSessionsRequest(
          agent: widget.agent,
          folder: widget.folder,
          cursor: _last?.nextCursor ?? '',
        ),
      );
      if (!mounted) return;
      setState(() {
        _last = r;
        _sessions.addAll(r.sessions);
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e is ConnectException ? e.message : '$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasMore => _last?.nextCursor.isNotEmpty ?? false;

  /// The rows the arrows move over: the sessions, then "More".
  int get _rows => _sessions.length + (_hasMore ? 1 : 0);

  void _pick(int i) {
    if (i == _sessions.length) {
      if (!_loading) _more();
    } else if (!_sessions[i].folderGone) {
      widget.onOpen(_sessions[i]);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.escape:
        widget.onBack();
      case LogicalKeyboardKey.arrowDown when _rows > 0:
        setState(() => _at = (_at + 1) % _rows);
      case LogicalKeyboardKey.arrowUp when _rows > 0:
        setState(() => _at = (_at - 1 + _rows) % _rows);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when _rows > 0:
        _pick(_at);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final title = agentTitle(widget.agent);
    final last = _last;
    final String? note = switch (()) {
      _ when _error != null => _error,
      _ when last == null => 'Looking…',
      _ when !last.canList => "$title can't list its sessions.",
      _ when _sessions.isEmpty => 'No other sessions here.',
      _ => null,
    };
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 8, 6),
            child: Row(
              children: [
                IconTap(
                  Icons.arrow_back,
                  size: 16,
                  tooltip: 'Back',
                  onTap: widget.onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.folder.isEmpty
                        ? '$title sessions'
                        : '$title sessions in ${folderParts(widget.folder).$1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.text, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Text(note, style: theme.ui(t.textMuted, size: 12.5)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, s) in _sessions.indexed) _row(theme, i, s),
                  if (_hasMore)
                    Tap(
                      onTap: () => _pick(_sessions.length),
                      selected: _at == _sessions.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Text(
                        _loading ? 'Looking…' : 'More',
                        style: theme.ui(t.textSecondary, size: 12.5),
                      ),
                    ),
                ],
              ),
            ),
          if (last != null && !last.seesOpen && _sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
              child: Text(
                'If one is still open in a terminal, both will write to '
                'its history.',
                style: theme.ui(t.textMuted, size: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(NushiTheme theme, int i, FoundSession s) {
    final t = theme.t;
    final when = DateTime.fromMillisecondsSinceEpoch(s.updatedUnixMs.toInt());
    final details = [
      if (s.updatedUnixMs != 0) ago(DateTime.now().difference(when), when),
      if (s.messages > 0) '${s.messages} messages',
      if (widget.folder.isEmpty && s.folder.isNotEmpty)
        folderParts(s.folder).$1,
      if (s.folderGone) 'folder gone',
    ].join(' · ');
    return Tap(
      onTap: s.folderGone ? null : () => _pick(i),
      selected: i == _at,
      tooltip: s.folderGone ? '${tildePath(s.folder)} no longer exists' : '',
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title.isEmpty ? 'Untitled' : s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(s.folderGone ? t.textMuted : t.text),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: details),
                if (s.openIn.isNotEmpty)
                  TextSpan(
                    text: '${details.isEmpty ? '' : ' · '}open in ${s.openIn}',
                    style: TextStyle(color: t.needs),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.textMuted, size: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Whether to open [s], which may be open elsewhere: both would write to
/// its history, so that asks first (it doesn't refuse).
Future<bool> mayOpen(BuildContext context, FoundSession s) async =>
    s.openIn.isEmpty ||
    await confirm(
      context,
      'Open it here too?',
      "It's open in ${s.openIn}. Both will write to the same history.",
      'Open',
    );
