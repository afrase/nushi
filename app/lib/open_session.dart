import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The agents found not to list their sessions, while the app runs: the
/// New chat dialog offers them no "Sessions →".
final cantListSessions = <String>{};

/// The New chat dialog's second step: [agent]'s sessions in [folder] ('':
/// every folder's) that aren't chats, newest first, for [onOpen]. The
/// arrows move, Enter opens, ← or Esc goes [onBack].
class SessionList extends StatefulWidget {
  const new({
    required this.daemon,
    required this.agent,
    required this.folder,
    required this.onOpen,
    required this.onBack,
    super.key,
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
  // The selected row's, to keep it in view.
  final GlobalKey<State<StatefulWidget>> _shown = GlobalKey();

  final _scroll = ScrollController();

  /// Moves the selection, keeping it in view: a row away from the screen
  /// isn't built, but then the selection wrapped to the first or last.
  void _move(int by) {
    setState(() => _at = (_at + by + _rows) % _rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shown.currentContext case final c?) {
        Scrollable.ensureVisible(
          c,
          alignmentPolicy: by > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(_at == 0 ? 0 : _scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_more());
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
      if (!r.canList) cantListSessions.add(widget.agent);
      setState(() {
        _last = r;
        _sessions.addAll(r.sessions);
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
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
      if (!_loading) unawaited(_more());
    } else if (_why(_sessions[i]) == null) {
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
        _move(1);
      case LogicalKeyboardKey.arrowUp when _rows > 0:
        _move(-1);
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
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final title = agentTitle(widget.agent);
    final last = _last;
    final note = switch (()) {
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
                controller: _scroll,
                shrinkWrap: true,
                children: [
                  for (final (i, s) in _sessions.indexed) _row(theme, i, s),
                  if (_hasMore)
                    Tap(
                      key: _at == _sessions.length ? _shown : null,
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

  /// Why [s] can't be opened, if it can't: its folder is gone, or it's
  /// open elsewhere and the agent lets one app at a time write to it.
  String? _why(FoundSession s) => switch (s) {
    _ when s.folderGone => '${tildePath(s.folder)} no longer exists',
    _ when s.openIn.isNotEmpty && (_last?.oneWriter ?? false) =>
      '${agentTitle(widget.agent)} lets one app at a time use a session: '
          'close it there first',
    _ => null,
  };

  Widget _row(NushiTheme theme, int i, FoundSession s) {
    final t = theme.t;
    final why = _why(s);
    final when = DateTime.fromMillisecondsSinceEpoch(s.updatedUnixMs.toInt());
    final details = [
      if (s.updatedUnixMs != 0) ago(clock().difference(when), when),
      if (s.messages > 0) '${s.messages} messages',
      if (widget.folder.isEmpty && s.folder.isNotEmpty)
        folderParts(s.folder).$1,
      if (s.folderGone) 'folder gone',
    ].join(' · ');
    return Tap(
      key: i == _at ? _shown : null,
      onTap: why != null ? null : () => _pick(i),
      selected: i == _at,
      tooltip: why ?? '',
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.title.isEmpty ? 'Untitled' : s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(why != null ? t.textMuted : t.text),
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
/// its history, so that asks first (it doesn't refuse). An agent that
/// allows one writer never gets here (SessionList doesn't offer it).
Future<bool> mayOpen(BuildContext context, FoundSession s) async =>
    s.openIn.isEmpty ||
    await confirm(
      context,
      'Open it here too?',
      "It's open in ${s.openIn}. Both will write to its history, and neither "
          "sees the other's turns.",
      'Open',
    );
