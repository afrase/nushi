import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart';
import 'package:nushi/transcript.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/workflow_card.dart';
import 'package:nushi/workflows.dart';

/// A workflow beside the chat (ADR 0127): its head (what it does, its
/// state and totals), then its phases, each a fold of its agents with
/// their state and time. A click on an agent shows its steps in the pane,
/// with "All agents" to go back. It reads the daemon again as the run's
/// summary on its item changes, never on a timer of its own; an agent's
/// steps are read every few seconds while that agent runs and the pane
/// shows. Stop stops the run; × closes the pane.
class WorkflowPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.id,
    required this.onClose,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final String id; // the call that launched it
  final VoidCallback onClose;

  /// How long after the run's summary changes its agents are read again:
  /// a busy run changes it every second.
  static const Duration refetch = Waits.save;

  @override
  State<WorkflowPane> createState() => _WorkflowPaneState();
}

class _WorkflowPaneState extends State<WorkflowPane> {
  GetWorkflowResponse? _got;
  Object? _error;
  Workflow? _seen;
  Timer? _wait;

  /// The agent whose steps show, if one's do.
  final _agent = ValueNotifier<String?>(null);

  /// The phases folded, by title.
  final _folded = <String>{};

  Item? get _call =>
      widget.chat.withRunning.where((it) => it.id == widget.id).firstOrNull;

  @override
  void initState() {
    super.initState();
    _seen = _call?.workflow;
    widget.chat.addListener(_changed);
    unawaited(_fetch());
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    _wait?.cancel();
    _agent.dispose();
    super.dispose();
  }

  /// The run's summary changed: its agents are read again shortly.
  void _changed() {
    final w = _call?.workflow;
    if (w == null || w == _seen) return;
    _seen = w;
    _wait?.cancel();
    _wait = Timer(WorkflowPane.refetch, () => unawaited(_fetch()));
  }

  Future<void> _fetch() async {
    try {
      final got = await widget.daemon.client.getWorkflow(
        GetWorkflowRequest(chatId: widget.chat.id, callId: widget.id),
      );
      if (mounted) {
        setState(() {
          _got = got;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.chat, _agent]),
      builder: (context, _) {
        final call = _call;
        final w = call?.workflow;
        final agent = _agent.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaneHeader(
              child: Row(
                children: [
                  Expanded(
                    child: call == null
                        ? Text(
                            'Workflow',
                            maxLines: 1,
                            style: theme.ui(t.text, size: 12, weight: .w600),
                          )
                        : workflowName(context, call, size: 12),
                  ),
                  if (w != null && workflowLive(w))
                    stopButton(context, widget.daemon, widget.chat, widget.id),
                  IconTap(
                    Icons.close,
                    tooltip: 'Close',
                    size: 15,
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((call, agent)) {
                (null, _) => _empty('This workflow is no longer in the chat.'),
                (final call?, final id?) => _AgentSteps(
                  key: ValueKey(id),
                  chat: widget.chat,
                  daemon: widget.daemon,
                  call: call,
                  agent: _got?.agents.where((a) => a.id == id).firstOrNull,
                  agentId: id,
                  onBack: () => _agent.value = null,
                ),
                (final call?, null) => _tree(context, call.workflow),
              },
            ),
          ],
        );
      },
    );
  }

  Widget _empty(String text) => Builder(
    builder: (context) {
      final theme = NushiTheme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.ui(theme.t.textMuted, size: 12),
          ),
        ),
      );
    },
  );

  /// The head, then each phase and its agents.
  Widget _tree(BuildContext context, Workflow w) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme.ui(t.textMuted, size: 12);
    final got = _got;
    final error = _error;
    final agents = got?.agents ?? <WorkflowAgent>[];
    final groups = _grouped(w, agents);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (w.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(w.description, style: theme.ui(t.text, size: 12)),
          ),
        Row(
          spacing: 6,
          children: [
            Flexible(
              child: LiveText(
                () => workflowState(w),
                live: workflowLive(w) && !w.stalled,
                style: small.copyWith(
                  color: w.state == 'failed'
                      ? t.crashed
                      : w.stalled
                      ? t.needs
                      : null,
                ),
              ),
            ),
            TaskMark(w.state),
          ],
        ),
        if (workflowEndWords(w, widget.chat.agentName) case final words
            when words.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(words, style: small),
          ),
        const SizedBox(height: 12),
        if (error != null && got == null)
          Text(
            error is ConnectException && error.code == Code.notFound
                ? '${widget.chat.agentName} no longer has this run’s files.'
                : errorText(error),
            style: small,
          )
        else if (got == null)
          const SizedBox.shrink()
        else ...[
          if (agents.isEmpty) Text('No agents yet', style: small),
          for (final (title, list) in groups) ...[
            if (list.isEmpty)
              _PlannedRow(title, live: workflowLive(w))
            else ...[
              _PhaseRow(
                title: title.isEmpty ? 'No phase' : title,
                count: _phaseCount(w, title, list),
                folded: _folded.contains(title),
                onTap: () => setState(
                  () => _folded.contains(title)
                      ? _folded.remove(title)
                      : _folded.add(title),
                ),
              ),
              if (!_folded.contains(title))
                for (final a in list)
                  _AgentRow(a, onTap: () => _agent.value = a.id),
            ],
          ],
          if (got.more)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('and ${w.agents - agents.length} more', style: small),
            ),
        ],
      ],
    );
  }
}

/// The agents by phase: in the run's order of phases, then any other, then
/// those with none; then the phases it plans and hasn't reached (ADR
/// 0141), and those of its list it never reached, with no agents.
List<(String, List<WorkflowAgent>)> _grouped(
  Workflow w,
  List<WorkflowAgent> agents,
) {
  final by = <String, List<WorkflowAgent>>{
    for (final p in w.phases) p.title: [],
  };
  for (final a in agents) {
    (by[a.phase] ??= []).add(a);
  }
  final none = by.remove('');
  final unreached = {
    for (final p in w.phases)
      if (p.started == 0 && (by[p.title]?.isEmpty ?? true)) p.title,
    for (final p in w.planned)
      if (by[p.title]?.isEmpty ?? true) p.title,
  };
  return [
    for (final e in by.entries)
      if (e.value.isNotEmpty) (e.key, e.value),
    if (none != null && none.isNotEmpty) ('', none),
    for (final title in unreached) (title, const <WorkflowAgent>[]),
  ];
}

/// A phase not reached: an empty ring where a reached one's chevron is,
/// its title dimmed, and "planned" (or "not reached", once the run
/// ended) where its count is. Nothing to fold, so no toggle.
class _PlannedRow extends StatelessWidget {
  const new(this.title, {required this.live});

  final String title;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: SizedBox(
        height: 24,
        child: Row(
          spacing: 6,
          children: [
            const SizedBox(
              width: 14,
              child: Center(child: TaskMark('planned')),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.ui(t.textSecondary, size: 12),
                    ),
                  ),
                  Text(
                    ' · ${plannedWords(live: live)}',
                    maxLines: 1,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A phase's count as the card's [phaseProgress] says it ("5/7"): its
/// agents that ended done or failed of those started, from the run's
/// summary; for a phase the summary doesn't hold, from its agents listed,
/// one stopped with the run not counted as ended.
String _phaseCount(Workflow w, String title, List<WorkflowAgent> agents) {
  for (final p in w.phases) {
    if (title.isNotEmpty && p.title == title) {
      return '${p.done + p.failed}/${p.started}';
    }
  }
  final ended = agents.where((a) => a.state == 'done' || a.state == 'failed');
  return '${ended.length}/${agents.length}';
}

/// A phase's title and progress ("Review 5/7", as the card says it), which
/// folds its agents.
class _PhaseRow extends StatelessWidget {
  const new({
    required this.title,
    required this.count,
    required this.folded,
    required this.onTap,
  });

  final String title;
  final String count;
  final bool folded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme.ui(theme.t.textSecondary, size: 12, weight: .w600);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Tap(
        onTap: onTap,
        tint: false,
        child: SizedBox(
          height: 24,
          child: Row(
            spacing: 6,
            children: [
              Chevron(open: !folded),
              // A long title is cut, never its count.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    Text(' $count', maxLines: 1, style: style),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An agent: its mark (the running dot while it runs), label, time and
/// tokens; a click shows its steps.
class _AgentRow extends StatelessWidget {
  const new(this.a, {required this.onTap});

  final WorkflowAgent a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme.ui(t.textMuted, size: 12);
    return Tap(
      onTap: onTap,
      tooltip: 'Show its steps',
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 28,
        child: Row(
          spacing: 8,
          children: [
            // A running row has no state words to say so, as a card's
            // does: its mark is the running dot (design.md).
            SizedBox(
              width: 14,
              child: Center(
                child: a.state == 'running'
                    ? CustomPaint(
                        size: const Size.square(TaskMark.size),
                        painter: StatusMark(t.running),
                      )
                    : TaskMark(a.state),
              ),
            ),
            Expanded(
              child: Shine(
                on: a.state == 'running',
                child: Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(
                    a.state == 'failed' ? t.crashed : t.text,
                    size: 12,
                  ),
                ),
              ),
            ),
            if (a.tokens > 0) Text(tokenCount(a.tokens), style: small),
            LiveText(
              () => _agentTime(a),
              live: a.state == 'running' && a.started != 0,
              style: small,
            ),
          ],
        ),
      ),
    );
  }
}

/// How long an agent ran, or runs; '' when not known.
String _agentTime(WorkflowAgent a) =>
    ranFor(a.started.toInt(), a.ended.toInt(), runs: a.state == 'running');

/// How often a running agent's steps are read while they show.
const _stepsEvery = Duration(seconds: 3);

/// One agent's steps (GetWorkflowAgent), under "All agents", which goes
/// back to the tree.
class _AgentSteps extends StatefulWidget {
  const new({
    required this.chat,
    required this.daemon,
    required this.call,
    required this.agent,
    required this.agentId,
    required this.onBack,
    super.key,
  });

  final ChatState chat;
  final Daemon daemon;
  final Item call;
  final WorkflowAgent? agent;
  final String agentId;
  final VoidCallback onBack;

  @override
  State<_AgentSteps> createState() => _AgentStepsState();
}

class _AgentStepsState extends State<_AgentSteps> {
  GetWorkflowAgentResponse? _got;
  Object? _error;
  Timer? _tick;

  WorkflowAgent? get _agent => _got?.agent ?? widget.agent;

  bool get _runs => _agent?.state == 'running';

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Reads again every few seconds only while the agent runs and the pane
  /// shows (a tucked pane's TickerMode is off).
  void _sync() {
    if (_runs && TickerMode.valuesOf(context).enabled) {
      _tick ??= Timer.periodic(_stepsEvery, (_) => unawaited(_fetch()));
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _fetch() async {
    try {
      final got = await widget.daemon.client.getWorkflowAgent(
        GetWorkflowAgentRequest(
          chatId: widget.chat.id,
          callId: widget.call.id,
          agentId: widget.agentId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _got = got;
        _error = null;
      });
      _sync();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme.ui(t.textMuted, size: 12);
    final a = _agent;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
          child: Row(
            spacing: 4,
            children: [
              IconTap(
                Icons.arrow_back,
                tooltip: 'All agents',
                size: 15,
                onTap: widget.onBack,
              ),
              Expanded(
                child: Text(
                  a?.label ?? widget.agentId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, size: 12, weight: .w600),
                ),
              ),
              if (a != null) TaskMark(a.state),
            ],
          ),
        ),
        Expanded(
          child: error != null && _got == null
              ? Center(
                  child: Text(
                    error is ConnectException && error.code == Code.notFound
                        ? '${widget.chat.agentName} no longer has this '
                              'agent’s files.'
                        : errorText(error),
                    style: small,
                  ),
                )
              : _got == null
              ? const SizedBox.shrink()
              : Transcript(
                  chat: widget.chat,
                  daemon: widget.daemon,
                  onReply: null,
                  items: _got!.items,
                  live: _runs,
                  header: _AgentHead(a, earlier: _got!.earlier),
                ),
        ),
      ],
    );
  }
}

/// An agent's task (folded), its model and state.
class _AgentHead extends StatelessWidget {
  const new(this.a, {required this.earlier});

  final WorkflowAgent? a;
  final int earlier;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final small = theme.ui(t.textMuted, size: 12);
    final a = this.a;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (a != null && a.prompt.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: cardBox(t),
              child: FoldedText(
                a.prompt,
                style: theme.ui(t.text, size: 12),
                folded: 5,
                padding: const EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          if (a != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (a.model.isNotEmpty) 'Model ${a.model}',
                  a.state,
                  if (_agentTime(a) case final time when time.isNotEmpty) time,
                  if (a.toolCalls > 0)
                    '${a.toolCalls} tool call${a.toolCalls == 1 ? '' : 's'}',
                ].join('  ·  '),
                style: small,
              ),
            ),
          if (earlier > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('$earlier earlier steps not shown', style: small),
            ),
        ],
      ),
    );
  }
}
