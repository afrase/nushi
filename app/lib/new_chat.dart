import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/agent_mark.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/issue_picker.dart';
import 'package:nushi/new_chat_issue.dart';
import 'package:nushi/open_session.dart';
import 'package:nushi/orrery.dart';
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
/// that isn't a chat (started in a terminal). It can take a Jira issue
/// (picked already, as [issue], or in it: IssuePicker), which turns on a
/// worktree on the issue's branch. Every way to start a chat comes through
/// here.
Future<void> newChat(
  BuildContext context,
  Daemon daemon,
  String folder, {
  IssueChat? issue,
}) async {
  if (daemon.starting != null) return;
  listAgents(daemon.client).ignore(); // as they are now, while it shows
  final pick = await showDialog<(String, FoundSession?, IssueChat?)>(
    context: context,
    builder: (_) => _NewChat(daemon, folder, issue),
  );
  if (pick == null || !context.mounted) return;
  final (agent, session, picked) = pick;
  if (agent.isEmpty || knownAgents[agent]?.ready == false) {
    await showSettings(context, daemon.client, agents: true);
  } else if (session == null) {
    await tryOrShow(
      context,
      () => daemon.startChat(folder, agent, issue: picked),
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
/// (SessionList), ← comes back. Under them, the issue (IssueLines): I, or
/// ⌘V with an issue's link, picks one (IssuePicker).
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

  late IssueChat? _issue = widget.issue;

  /// The sites added; none, and the dialog offers no issue.
  List<JiraSite> _sites = const [];

  /// While the issue picker shows: what its field started with.
  String? _picking;
  bool _editingBranch = false;

  @override
  void initState() {
    super.initState();
    unawaited(_listSites());
  }

  Future<void> _listSites() async {
    try {
      final r = await widget.daemon.client.listJiraSites(
        ListJiraSitesRequest(),
      );
      if (mounted) setState(() => _sites = r.sites);
    } on Object {
      // No Jira for now: the dialog offers no issue.
    }
  }

  void _start(int i) => Navigator.pop(context, (_agents[i], null, _issue));

  void _sessions(bool show) {
    if (show && knownAgents[_agents[_at]]?.ready == false) return _start(_at);
    setState(() => _sessionsOf = show ? _agents[_at] : null);
    if (!show) _focus.requestFocus();
  }

  bool get _offersIssue => _sites.isNotEmpty || _issue != null;

  void _pickIssue([String text = '']) {
    if (_offersIssue) setState(() => _picking = text);
  }

  void _picked(FoundJiraIssue? f) {
    setState(() {
      if (f != null) _issue = IssueChat.found(f);
      _picking = null;
    });
    _focus.requestFocus();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text != null && mounted) _pickIssue(text.trim());
  }

  void _branch(String? branch) {
    setState(() {
      if (branch != null && branch.isNotEmpty) _issue!.branch = branch;
      _editingBranch = false;
    });
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent || _editingBranch) {
      return KeyEventResult.ignored; // the branch's field has the keys
    }
    final n = _agents.length;
    final issue = _issue;
    final worktree = issue != null && widget.folder.isNotEmpty;
    final digit = int.tryParse(e.character ?? '') ?? 0;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        setState(() => _at = (_at + 1) % n);
      case LogicalKeyboardKey.arrowUp:
        setState(() => _at = (_at - 1 + n) % n);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _start(_at);
      case LogicalKeyboardKey.arrowRight when issue == null:
        _sessions(true);
      case LogicalKeyboardKey.keyV when HardwareKeyboard.instance.isMetaPressed:
        unawaited(_paste());
      case LogicalKeyboardKey.keyI when _offersIssue:
        _pickIssue();
      case LogicalKeyboardKey.backspace || LogicalKeyboardKey.delete
          when issue != null:
        setState(() => _issue = null);
      case LogicalKeyboardKey.keyW when worktree:
        setState(() => issue.worktree = !issue.worktree);
      case LogicalKeyboardKey.keyB
          when worktree && issue.worktree && issue.github?.pull != true:
        setState(() => _editingBranch = true);
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
    final issue = _issue;
    _at = min(_at, max(0, agents.length - 1));
    return Dialog(
      child: SizedBox(
        width: agent != null || _picking != null
            ? 440
            : _offersIssue
            ? 360
            : 300,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _picking != null
              ? IssuePicker(
                  daemon: widget.daemon,
                  sites: _sites,
                  text: _picking!,
                  onPick: _picked,
                  onBack: () => _picked(null),
                )
              : agent != null
              ? SessionList(
                  daemon: widget.daemon,
                  agent: agent,
                  folder: folder,
                  onOpen: (s) => Navigator.pop(context, (agent, s, null)),
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
                            if (issue case final i?)
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
                            onTap: () =>
                                Navigator.pop(context, ('', null, null)),
                          ),
                        ),
                      if (_offersIssue) ...[
                        Divider(height: 9, color: t.borderSubtle),
                        IssueLines(
                          issue: issue,
                          inFolder: folder.isNotEmpty,
                          editingBranch: _editingBranch,
                          onPick: _pickIssue,
                          onClear: () => setState(() => _issue = null),
                          onWorktree: () => setState(() {
                            issue!.worktree = !issue.worktree;
                          }),
                          onEditBranch: () =>
                              setState(() => _editingBranch = true),
                          onBranch: _branch,
                        ),
                      ],
                      if (agents.isNotEmpty && issue == null) ...[
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

/// The pane with no chat open: the mark, moving, over "Start a chat", or,
/// while no agent can start, where to set one up.
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
    return Orrery(
      label: none
          ? _SetUpLine(
              'Set up an agent in ',
              onTap: () => showSettings(context, daemon.client, agents: true),
            )
          : Text('Start a chat', style: theme.ui(theme.t.textMuted)),
    );
  }
}
