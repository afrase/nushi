import 'dart:async';

import 'package:flutter/material.dart';

import 'chat.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'status.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// A tool call that started a subagent, and what the subagent did.
typedef SubagentRun = ({Item call, List<Item> items});

/// The subagents in [items], each with the items it made, in order.
List<SubagentRun> subagentsOf(List<Item> items) {
  final under = <String, List<Item>>{};
  for (final it in items) {
    if (it.parent.isNotEmpty) (under[it.parent] ??= []).add(it);
  }
  return [
    for (final it in items)
      if (it.agent.isNotEmpty) (call: it, items: under[it.id] ?? const []),
  ];
}

/// Whether the subagent works, as the daemon says.
bool subagentRunning(SubagentRun s) => s.call.subagent.state == 'running';

/// The subagent's own steps, without its report (that shows as its result).
List<Item> subagentSteps(SubagentRun s) => [
  for (final it in s.items)
    if (!it.report) it,
];

DateTime? _time(int ms) =>
    ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);

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
  final since = _time(sa.started.toInt());
  final end = running ? DateTime.now() : _time(sa.ended.toInt());
  return [
    if (running) doing(s.items) else sa.state,
    if (calls > 0) '$calls tool call${calls == 1 ? '' : 's'}',
    if (since != null && end != null) elapsed(end.difference(since)),
  ].join(' · ');
}

/// What a subagent runs on: its model (the one it ran on, else the one it
/// was asked for, else the chat's) and effort (asked for, else the
/// chat's), by name; [inherited] when it is the chat's. The chat's is what
/// it uses now, '' when unknown.
typedef Setting = ({String name, bool inherited});

({Setting model, Setting effort}) subagentModel(ChatState chat, SubagentRun s) {
  final call = s.call;
  Setting named(String category, String asked) {
    final o = chat.config.where((o) => o.category == category).firstOrNull;
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

/// [subagentState] in [style], its time ticking while the subagent works.
class SubagentState extends StatefulWidget {
  const SubagentState(this.s, {super.key, required this.style});

  final SubagentRun s;
  final TextStyle style;

  @override
  State<SubagentState> createState() => _SubagentStateState();
}

class _SubagentStateState extends State<SubagentState> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (subagentRunning(widget.s)) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    subagentState(widget.s),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: widget.style.copyWith(
      color: widget.s.call.subagent.state == 'failed'
          ? NushiTheme.of(context).t.crashed
          : null,
    ),
  );
}

/// A spinner while the subagent works (unless the agent waits on the user,
/// [still]), a check once done, nothing when it failed.
Widget subagentMark(BuildContext context, SubagentRun s, {bool still = false}) {
  final t = NushiTheme.of(context).t;
  return switch (s.call.subagent.state) {
    'running' when !still => const SizedBox.square(
      dimension: 10,
      child: CircularProgressIndicator(strokeWidth: 1.5),
    ),
    'done' => Icon(Icons.check, size: 13, color: t.done),
    _ => const SizedBox.shrink(),
  };
}

/// A subagent in the transcript, on one line: its type and task ("Explore:
/// find the scroll handling") and its state, live. A click opens its pane.
class SubagentLine extends StatelessWidget {
  const SubagentLine(this.s, this.chat, {super.key, this.still = false});

  final SubagentRun s;
  final ChatState chat;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final failed = s.call.subagent.state == 'failed';
    return ValueListenableBuilder(
      valueListenable: chat.subagent,
      builder: (context, open, _) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: box(
          failed
              ? t.crashed
              : open == s.call.id
              ? t.focus
              : t.borderSubtle,
          fill: failed ? t.crashedSoft : t.raised,
        ),
        child: Tap(
          onTap: () => chat.subagent.value = s.call.id,
          tooltip: 'Open its steps beside the chat',
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
                  color: t.textSecondary,
                ),
                Expanded(child: subagentName(context, s)),
                Flexible(
                  child: SubagentState(
                    s,
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                ),
                subagentMark(context, s, still: still),
                Icon(Icons.chevron_right, size: 14, color: t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Explore: find the scroll handling", the type in bold, on one line.
Widget subagentName(BuildContext context, SubagentRun s, {double size = 13}) {
  final theme = NushiTheme.of(context), t = theme.t;
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '${s.call.agent}: ',
          style: theme.ui(t.text, size: size, weight: FontWeight.w600),
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
