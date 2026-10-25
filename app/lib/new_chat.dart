import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/logo.dart';
import 'package:nushi/open_session.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘N: a new chat, as the sidebar's button starts one.
const newChatKey = SingleActivator(LogicalKeyboardKey.keyN, meta: true);

/// ⌘N from a widget that keeps the key for itself (a terminal).
class NewChatIntent extends Intent {
  const new();
}

/// Asks which agent a new chat in [folder] ('' for none) runs, then
/// starts it there; or, a step further, opens one of the agent's sessions
/// that isn't a chat (started in a terminal). A chat on a Jira [issue]
/// also says whether it gets a worktree on the issue's branch. Every way
/// to start a chat comes through here.
Future<void> newChat(
  BuildContext context,
  Daemon daemon,
  String folder, {
  IssueChat? issue,
}) async {
  if (daemon.starting != null) return;
  listAgents(daemon.client).ignore(); // as they are now, while it shows
  final pick = await showDialog<(String, FoundSession?)>(
    context: context,
    builder: (_) => _NewChat(daemon, folder, issue),
  );
  if (pick == null || !context.mounted) return;
  final (agent, session) = pick;
  if (agent.isEmpty || knownAgents[agent]?.ready == false) {
    await showSettings(context, daemon.client, agents: true);
  } else if (session == null) {
    await tryOrShow(
      context,
      () => daemon.startChat(folder, agent, issue: issue),
    );
  } else if (await mayOpen(context, session) && context.mounted) {
    await tryOrShow(context, () => daemon.openSession(folder, agent, session));
  }
}

/// The agents installed, the last one used selected (one that isn't
/// ready, or whose last start failed, shows dimmed and isn't, unless none
/// is): Enter starts it, a click, or a digit, starts another; the arrows
/// move. One that isn't ready goes to Settings › Agents instead. → (or the
/// row under them) lists the selected agent's sessions instead
/// (SessionList), ← comes back.
class _NewChat extends StatefulWidget {
  const new(this.daemon, this.folder, this.issue);

  final Daemon daemon;
  final String folder;
  final IssueChat? issue;

  @override
  State<_NewChat> createState() => _NewChatState();
}

class _NewChatState extends State<_NewChat> {
  List<String> get _agents => [
    for (final a in knownAgents.values)
      if (a.path.isNotEmpty) a.name,
  ];
  late int _at = () {
    final agents = _agents;
    bool ok(String a) =>
        knownAgents[a]!.ready && !widget.daemon.cantStart.containsKey(a);
    final last = max(0, agents.indexOf(lastAgent(widget.daemon.chats.values)));
    if (agents.isEmpty || ok(agents[last])) return last;
    final first = agents.indexWhere(ok);
    return first >= 0 ? first : last;
  }();

  /// The agent whose sessions show, once → was pressed.
  String? _sessionsOf;
  final _focus = FocusNode();

  void _start(int i) => Navigator.pop(context, (_agents[i], null));

  void _sessions(bool show) {
    if (show && knownAgents[_agents[_at]]?.ready == false) return _start(_at);
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
      case LogicalKeyboardKey.arrowRight when widget.issue == null:
        _sessions(true);
      case LogicalKeyboardKey.keyW
          when widget.issue != null && widget.folder.isNotEmpty:
        setState(() => widget.issue!.worktree = !widget.issue!.worktree);
      case _ when digit >= 1 && digit <= n && digit <= 9:
        _start(digit - 1);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: agentList, // found again as the dialog opened
    builder: (context, _, _) => _dialog(context),
  );

  Widget _dialog(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final folder = widget.folder;
    final agent = _sessionsOf;
    final agents = _agents;
    _at = min(_at, max(0, agents.length - 1));
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
                  onKeyEvent: agents.isEmpty ? null : _key,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Text(
                          [
                            if (widget.issue case final i?)
                              'Chat on ${i.key}'
                            else
                              'New chat',
                            if (folder.isNotEmpty)
                              'in ${folderParts(folder).$1}',
                          ].join(' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.ui(t.text, weight: FontWeight.w600),
                        ),
                      ),
                      for (final (i, name) in agents.indexed)
                        _row(theme, t, i, name),
                      if (agents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                          child: _SetUpLine(
                            'No agents found. ',
                            onTap: () => Navigator.pop(context, ('', null)),
                          ),
                        ),
                      if (widget.issue case final issue?
                          when folder.isNotEmpty) ...[
                        Divider(height: 9, color: t.borderSubtle),
                        _WorktreeLine(
                          issue,
                          onTap: () => setState(() {
                            issue.worktree = !issue.worktree;
                          }),
                        ),
                      ],
                      if (agents.isNotEmpty && widget.issue == null) ...[
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
                                  'Open ${_an(agentTitle(agents[_at]))} '
                                  'session…',
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
    final a = knownAgents[name]!;
    final failed = widget.daemon.cantStart[name];
    final setUp = !a.ready && a.problem.isEmpty;
    final why = !a.ready
        ? a.problem
        : failed == null
        ? null
        : _reason(failed, a.title);
    final color = why == null ? t.text : t.textMuted;
    return Tap(
      onTap: () => _start(i),
      selected: i == _at,
      tooltip: failed ?? '',
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          AgentMark(name, size: 18, color: color),
          const SizedBox(width: 10),
          Text(agentTitle(name), style: theme.ui(color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              why ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(t.textMuted, size: 11.5),
            ),
          ),
          if (setUp) ...[
            Text('Set up', style: theme.ui(t.link, size: 11.5)),
            const SizedBox(width: 10),
          ],
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

/// "[before]Settings › Agents" with the second part a link, for when no
/// agent can start yet.
class _SetUpLine extends StatelessWidget {
  const new(this.before, {required this.onTap});

  final String before;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(before, style: theme.ui(t.textMuted)),
        Tap(
          onTap: onTap,
          child: Text('Settings › Agents', style: theme.ui(t.link)),
        ),
      ],
    );
  }
}

/// The pane with no chat open: "Start a chat", or, while no agent can
/// start, where to set one up.
class NothingOpen extends StatelessWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: agentList,
    builder: (context, agents, _) => _pane(context, agents),
  );

  Widget _pane(BuildContext context, Map<String, Agent> agents) {
    final theme = NushiTheme.of(context);
    final none = agents.isNotEmpty && !agents.values.any((a) => a.ready);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Logo(color: theme.t.borderStrong),
          const SizedBox(height: 16),
          if (none)
            _SetUpLine(
              'Set up an agent in ',
              onTap: () => showSettings(context, daemon.client, agents: true),
            )
          else
            Text('Start a chat', style: theme.ui(theme.t.textMuted)),
        ],
      ),
    );
  }
}

/// Whether a chat on an issue gets a worktree on the issue's branch; a
/// click (or W) switches it.
class _WorktreeLine extends StatelessWidget {
  const new(this.issue, {required this.onTap});

  final IssueChat issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Tap(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(
            issue.worktree ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: t.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'In a new worktree on ',
                    style: theme.ui(t.textSecondary, size: 12.5),
                  ),
                  TextSpan(
                    text: issue.branch,
                    style: theme.code(t.text, size: 12),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          keyHint(context, 'W'),
        ],
      ),
    );
  }
}
