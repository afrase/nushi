import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_mark.dart';
import 'agents.dart';
import 'daemon.dart';
import 'folder_button.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'open_session.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// ⌘N: a new chat, as the sidebar's button starts one.
const newChatKey = SingleActivator(LogicalKeyboardKey.keyN, meta: true);

/// ⌘N from a widget that keeps the key for itself (a terminal).
class NewChatIntent extends Intent {
  const NewChatIntent();
}

/// Asks which agent a new chat in [folder] ('' for none) runs, then
/// starts it there; or, a step further, opens one of the agent's sessions
/// that isn't a chat (started in a terminal). Every way to start a chat
/// comes through here.
Future<void> newChat(BuildContext context, Daemon daemon, String folder) async {
  if (daemon.starting != null) return;
  final pick = await showDialog<(String, FoundSession?)>(
    context: context,
    builder: (_) => _NewChat(daemon, folder),
  );
  if (pick == null || !context.mounted) return;
  final (agent, session) = pick;
  if (session == null) {
    await tryOrShow(context, () => daemon.startChat(folder, agent));
  } else if (await mayOpen(context, session) && context.mounted) {
    await tryOrShow(context, () => daemon.openSession(folder, agent, session));
  }
}

/// The agents, the last one used selected (one whose last start failed
/// shows dimmed and isn't, unless all failed): Enter starts it, a click,
/// or a digit, starts another; the arrows move. → (or the row under them)
/// lists the selected agent's sessions instead (SessionList), ← comes
/// back.
class _NewChat extends StatefulWidget {
  const _NewChat(this.daemon, this.folder);

  final Daemon daemon;
  final String folder;

  @override
  State<_NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<_NewChat> {
  final _agents = knownAgents.keys.toList();
  late int _at = () {
    final failed = widget.daemon.cantStart;
    final last = max(0, _agents.indexOf(lastAgent(widget.daemon.chats.values)));
    if (_agents.isEmpty || !failed.containsKey(_agents[last])) return last;
    final ok = _agents.indexWhere((a) => !failed.containsKey(a));
    return ok >= 0 ? ok : last;
  }();

  /// The agent whose sessions show, once → was pressed.
  String? _sessionsOf;
  final _focus = FocusNode();

  void _start(int i) => Navigator.pop(context, (_agents[i], null));

  void _sessions(bool show) {
    setState(() => _sessionsOf = show ? _agents[_at] : null);
    if (!show) _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final n = _agents.length;
    final digit = int.tryParse(e.character ?? '') ?? 0;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _at = (_at + 1) % n);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _at = (_at - 1 + n) % n);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _start(_at);
      case LogicalKeyboardKey.arrowRight:
        _sessions(true);
      case _ when digit >= 1 && digit <= n && digit <= 9:
        _start(digit - 1);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final folder = widget.folder;
    final agent = _sessionsOf;
    return Dialog(
      child: SizedBox(
        width: agent == null ? 300 : 440,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: agent != null
              ? SessionList(
                  daemon: widget.daemon,
                  agent: agent,
                  folder: folder,
                  onOpen: (s) => Navigator.pop(context, (agent, s)),
                  onBack: () => _sessions(false),
                )
              : Focus(
                  focusNode: _focus,
                  autofocus: true,
                  onKeyEvent: _agents.isEmpty ? null : _key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Text(
                          folder.isEmpty
                              ? 'New chat'
                              : 'New chat in ${folderParts(folder).$1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.text, weight: FontWeight.w600),
                        ),
                      ),
                      for (final (i, name) in _agents.indexed)
                        _row(theme, t, i, name),
                      if (_agents.isNotEmpty) ...[
                        Divider(height: 9, color: t.borderSubtle),
                        Tap(
                          onTap: () => _sessions(true),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 16,
                                color: t.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Open ${_an(agentTitle(_agents[_at]))} session…',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.ui(t.textSecondary, size: 12.5),
                                ),
                              ),
                              keyHint(context, '→'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _row(NushiTheme theme, Tokens t, int i, String name) {
    final why = widget.daemon.cantStart[name];
    final color = why == null ? t.text : t.textMuted;
    return Tap(
      onTap: () => _start(i),
      selected: i == _at,
      tooltip: why ?? '',
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          AgentMark(name, size: 18, color: color),
          const SizedBox(width: 10),
          Text(agentTitle(name), style: theme.ui(color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              why == null ? '' : _reason(why, agentTitle(name)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.textMuted, size: 11.5),
            ),
          ),
          if (i < 9) keyHint(context, '${i + 1}'),
        ],
      ),
    );
  }
}

/// The daemon's "couldn't start Ante: initialize: acp error -32603: Ante
/// isn't installed: there's no ante …" in a few words: "Ante isn't
/// installed". The daemon's own steps ("start agent", "initialize", an
/// ACP error's code) are left out.
String _reason(String error, String title) => error
    .replaceFirst("couldn't start $title: ", '')
    .split(': ')
    .firstWhere(
      (clause) => !_step.hasMatch(clause),
      orElse: () => "couldn't start",
    );

final _step = RegExp(r'^(start agent|initialize|session/\w+|acp error -?\d+)$');

/// [word] after "a" or "an".
String _an(String word) =>
    '${'aeiouAEIOU'.contains(word.isEmpty ? '-' : word[0]) ? 'an' : 'a'} $word';
