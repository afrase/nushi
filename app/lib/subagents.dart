import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// A tool call that started a subagent, and what the subagent did.
typedef SubagentRun = ({Item call, List<Item> items});

/// The subagents in [items], each with the items it made, in order, and
/// the user's messages the agent was asked to pass to it, where they were
/// sent.
List<SubagentRun> subagentsOf(List<Item> items) {
  final under = <String, List<Item>>{};
  for (final it in items) {
    final to = it.parent.isNotEmpty ? it.parent : it.toSubagent;
    if (to.isNotEmpty) (under[to] ??= []).add(it);
  }
  return [
    for (final it in items)
      if (it.agent.isNotEmpty) (call: it, items: under[it.id] ?? const []),
  ];
}

/// Whether the subagent works, as the daemon says.
bool subagentRunning(SubagentRun s) => s.call.subagent.state == 'running';

/// Whether the subagent can be stopped on its own (StopTask): it runs, and
/// the agent shows it as a session of its own or said how to reach it.
bool subagentStoppable(SubagentRun s) =>
    subagentRunning(s) &&
    (s.call.subagent.session.isNotEmpty || s.call.agentId.isNotEmpty);

/// Stops the subagent or background command [callId] started, alone; it
/// shows as stopped once the agent says so.
Future<void> stopTask(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  String callId,
) => tryOrShow(
  context,
  () =>
      daemon.client.stopTask(StopTaskRequest(chatId: chat.id, callId: callId)),
);

/// The stop button of a running subagent or background command.
Widget stopButton(
  BuildContext context,
  Daemon daemon,
  ChatState chat,
  String callId, {
  double size = 14,
}) => IconTap(
  Icons.stop_rounded,
  tooltip: 'Stop',
  size: size,
  onTap: () => stopTask(context, daemon, chat, callId),
);

/// The subagent's own steps, without its report (that shows as its result).
List<Item> subagentSteps(SubagentRun s) => [
  for (final it in s.items)
    if (!it.report) it,
];

/// A subagent's state in a few words: "Reading notes.md · 6 tool calls ·
/// 40s" while it works, "done · 6 tool calls · 1m 02s" once done, "failed".
/// The count shows only when its steps are known (a background subagent's
/// aren't after the chat reopened), the time only when the daemon saw it
/// start.
String subagentState(SubagentRun s) {
  final sa = s.call.subagent;
  final calls = subagentSteps(s)
      .where((it) => it.kind == ItemKind.ITEM_KIND_TOOL_CALL)
      .length;
  final running = subagentRunning(s);
  final since = msTime(sa.started.toInt());
  final end = running ? DateTime.now() : msTime(sa.ended.toInt());
  return [
    if (running) doing(s.items) else sa.state,
    if (calls > 0) '$calls tool call${calls == 1 ? '' : 's'}',
    if (since != null && end != null) elapsed(end.difference(since)),
  ].join(' · ');
}

/// What a subagent runs on: its model (the one it ran on, else the one it
/// was asked for, else the chat's) and effort (asked for, else the
/// chat's), by name; `inherited` when it is the chat's. The chat's is what
/// it uses now, '' when unknown.
typedef Setting = ({String name, bool inherited});

({Setting model, Setting effort}) subagentModel(ChatState chat, SubagentRun s) {
  final call = s.call;
  Setting named(String category, String asked) {
    final o = chat.option(category);
    final value = asked.isEmpty ? o?.current ?? '' : asked;
    final v = o?.values.where((v) => v.value == value).firstOrNull;
    return (name: v?.name ?? value, inherited: asked.isEmpty);
  }

  final model = named('model', call.model);
  return (
    model: call.ranModel.isEmpty
        ? model
        : (name: call.ranModel, inherited: model.inherited),
    effort: named('thought_level', call.effort),
  );
}

/// "Opus 5.5 (inherited)", or "inherited" when the chat's isn't known.
String settingText(Setting s) => s.name.isEmpty
    ? 'inherited'
    : s.inherited
    ? '${s.name} (inherited)'
    : s.name;

/// [subagentState] in [style] (red once it failed), its time ticking while
/// the subagent works.
class SubagentState extends StatelessWidget {
  const new(this.s, {required this.style, super.key});

  final SubagentRun s;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LiveText(
    () => subagentState(s),
    live: subagentRunning(s),
    style: s.call.subagent.state == 'failed'
        ? style.copyWith(color: NushiTheme.of(context).t.crashed)
        : style,
  );
}

/// [text] on one line in [style], again every second while [live].
class LiveText extends StatefulWidget {
  const new(this.text, {required this.live, required this.style, super.key});

  final String Function() text;
  final bool live;
  final TextStyle style;

  @override
  State<LiveText> createState() => _LiveTextState();
}

class _LiveTextState extends State<LiveText> {
  // Only while live: every subagent's line stays built (ADR 0026).
  Timer? _tick;

  void _sync() {
    if (!widget.live) {
      _tick?.cancel();
      _tick = null;
    } else {
      _tick ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(LiveText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    widget.text(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: widget.style,
  );
}

/// The subagent's [TaskMark]: room while it works (its words shine), a
/// check that draws as it's done, a stop mark once stopped with its agent,
/// a red mark when it failed.
Widget subagentMark(SubagentRun s) => TaskMark(s.call.subagent.state);

/// [child] shining while the subagent runs, unless [still].
Widget subagentShine(SubagentRun s, Widget child, {bool still = false}) =>
    Align(
      alignment: Alignment.centerLeft,
      child: Shine(on: subagentRunning(s) && !still, child: child),
    );

/// A subagent in the transcript, on one line: its type and task ("Explore:
/// find the scroll handling") and its state, live. A click opens its pane;
/// under the pointer, a running one's mark becomes its Stop.
class SubagentLine extends StatelessWidget {
  const new(this.s, this.chat, {super.key, this.still = false, this.daemon});

  final SubagentRun s;
  final ChatState chat;
  final bool still;

  /// The daemon to stop it through; none, no Stop.
  final Daemon? daemon;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final daemon = this.daemon;
    final failed = s.call.subagent.state == 'failed';
    return Hover(
      builder: (context, {required hover}) => ValueListenableBuilder(
        valueListenable: chat.pane,
        builder: (context, open, _) => framed(
          border: failed
              ? t.crashed
              : open == s.call.id
              ? t.focus
              : t.subagentBorder,
          fill: failed ? t.crashedSoft : t.subagentTint,
          child: Tap(
            onTap: () => chat.pane.value = s.call.id,
            tooltip: 'Open its steps',
            radius: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              height: 28,
              child: Row(
                spacing: 6,
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    size: 14,
                    color: failed ? t.crashed : t.subagentAccent,
                  ),
                  Expanded(
                    child: subagentShine(
                      s,
                      subagentName(context, s),
                      still: still,
                    ),
                  ),
                  // The name takes the room; the state ends the line.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: SubagentState(
                      s,
                      style: theme.ui(t.textMuted, size: 12),
                    ),
                  ),
                  if (hover && daemon != null && subagentStoppable(s))
                    stopButton(context, daemon, chat, s.call.id, size: 13)
                  else
                    subagentMark(s),
                  Icon(Icons.chevron_right, size: 14, color: t.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Explore: find the scroll handling", the type in bold and the subagents'
/// accent, on one line.
Widget subagentName(BuildContext context, SubagentRun s, {double size = 13}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '${s.call.agent}: ',
          style: theme.ui(
            t.subagentAccent,
            size: size,
            weight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: s.call.title,
          style: theme.ui(t.text, size: size),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
