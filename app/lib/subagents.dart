import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/live_text.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pickers.dart' show ConfigNames;
import 'package:nushi/status.dart';
import 'package:nushi/text_width.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/widgets.dart';

export 'package:nushi/live_text.dart';

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
bool subagentRunning(SubagentRun s) => subagentRuns(s.call);

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
  double padding = 5,
}) => IconTap(
  Icons.stop_rounded,
  tooltip: 'Stop',
  size: size,
  padding: padding,
  onTap: () => stopTask(context, daemon, chat, callId),
);

/// The subagent's own steps, without its report (that shows as its result).
List<Item> subagentSteps(SubagentRun s) => [
  for (final it in s.items)
    if (!it.report) it,
];

/// What ends a row that opens a side pane (a subagent's, a workflow's):
/// a chevron is for what opens in place.
const IconData paneIcon = Icons.view_sidebar_outlined;

/// A subagent's state in a few words, in the order the workflow card's
/// shares: "Reading notes.md · 6 tools · 40s" while it works, "39 tools ·
/// 182k tokens · 7m 55s" once done (its check says so, #106), "failed ·
/// 2 tools · 1m 03s". The count shows only when its steps are known (a
/// background subagent's aren't after the chat reopened), the tokens once
/// the agent reported them, the time only when the daemon knows it.
/// Without [time], its tokens and time are left to [subagentTime].
String subagentState(SubagentRun s, {bool time = true}) {
  final spent = time ? subagentTime(s) : '';
  return [..._stateWords(s), if (spent.isNotEmpty) spent].join(' · ');
}

/// What a subagent does or how it ended (nothing once done: its check
/// says that), and its tool calls' count.
List<String> _stateWords(SubagentRun s) {
  final calls = subagentSteps(s)
      .where((it) => it.kind == ItemKind.ITEM_KIND_TOOL_CALL)
      .length;
  final state = s.call.subagent.state;
  return [
    if (subagentRunning(s)) doing(s.items) else if (state != 'done') state,
    if (calls > 0) toolsCount(calls),
  ];
}

/// "1 tool", "39 tools": a count of tool calls where room is short (a
/// subagent's row, a workflow's card).
String toolsCount(int n) => '$n tool${n == 1 ? '' : 's'}';

/// A subagent's state for a narrow line, the fullest first, each next
/// without its first part: "6 tools · 48k tokens · 3m 12s", "48k tokens ·
/// 3m 12s", then the time alone. A line takes the first that fits whole
/// ([SubagentState.fitted]), so a word is never cut to a bare "…" (its
/// mark says how it ended). Without tokens or a time, its words alone.
List<String> subagentStatesNarrow(SubagentRun s) {
  final spent = subagentTimeParts(s);
  final parts = [..._stateWords(s), ...spent];
  if (spent.isEmpty) return [parts.join(' · ')];
  return [for (var i = 0; i < parts.length; i++) parts.sublist(i).join(' · ')];
}

/// A subagent's tokens and time: "48k tokens · 3m 12s", "40s" while it
/// works and the agent hasn't said; '' when neither is known.
String subagentTime(SubagentRun s) => subagentTimeParts(s).join(' · ');

/// [subagentTime]'s parts: its tokens, then its time.
List<String> subagentTimeParts(SubagentRun s) {
  final sa = s.call.subagent;
  final worked = subagentWorked(sa, running: subagentRunning(s));
  return [
    if (sa.tokens > 0) tokenCount(sa.tokens.toInt()),
    if (worked != null) elapsed(worked),
  ];
}

/// How long a subagent worked, its waits left out: what it worked before,
/// and, while it works ([running]), since it began to again; null when the
/// daemon doesn't know (it didn't see it start, or was gone as it ended).
Duration? subagentWorked(Subagent sa, {required bool running}) {
  final since = msTime(sa.workingSince.toInt());
  // design: the daemon's figure, not a motion's length
  final worked = Duration(milliseconds: sa.worked.toInt());
  final now = running && since != null ? clock().difference(since) : null;
  if (now == null && worked == Duration.zero) return null;
  return worked + (now == null || now.isNegative ? Duration.zero : now);
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
    return (name: o?.nameOf(value) ?? value, inherited: asked.isEmpty);
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
  const new(
    this.s, {
    required this.style,
    super.key,
    this.time = true,
    this.fitted = false,
  });

  final SubagentRun s;
  final TextStyle style;

  /// Whether its time and tokens show ([subagentState]).
  final bool time;

  /// Whether it's the fullest of [subagentStatesNarrow] that fits whole,
  /// its time first.
  final bool fitted;

  @override
  Widget build(BuildContext context) {
    final style = s.call.subagent.state == 'failed'
        ? this.style.copyWith(color: NushiTheme.of(context).t.crashed)
        : this.style;
    if (!fitted) {
      return LiveText(
        () => subagentState(s, time: time),
        live: subagentRunning(s),
        style: style,
      );
    }
    return LayoutBuilder(
      builder: (context, box) => LiveText(
        () {
          final states = subagentStatesNarrow(s);
          return states.firstWhere(
            (t) => liveTextWidth(context, t, style) <= box.maxWidth,
            orElse: () => states.last,
          );
        },
        live: subagentRunning(s),
        style: style,
      ),
    );
  }
}

/// How wide [text] sets on one line in [style] as [LiveText] sets it: in
/// tabular figures.
double liveTextWidth(BuildContext context, String text, TextStyle style) =>
    textWidth(context, text, style.copyWith(fontFeatures: _tabular));

const _tabular = [FontFeature.tabularFigures()];

/// A related worktree's branch, as a tag on its subagent.
class WorktreeTag extends StatelessWidget {
  const new(this.branch, {super.key});

  final String branch;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Text(
      branch,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.code(theme.t.textMuted, size: 11),
    );
  }
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

/// What a subagent's pane shows that its row doesn't, for a find.
String subagentFolded(SubagentRun s) => [
  for (final it in s.items)
    if (it.kind == ItemKind.ITEM_KIND_TOOL_CALL) ...[
      callTitle(it),
      callFolded(it),
    ] else
      it.text,
].join('\n');

/// A subagent in the transcript, on one line (ADR 0111): a row filled with
/// the subagents' soft tint, no outline, its type and task ("Explore: find
/// the scroll handling") and its state at the end, live. A click opens its
/// pane, and while that is open the row is the accent's soft fill, as any
/// open row; a failed one is the failures' soft red. Under the pointer, a
/// running one's mark becomes its Stop.
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
    final state = theme.ui(t.textSecondary, size: 12);
    return Hover(
      builder: (context, {required hover}) => ValueListenableBuilder(
        valueListenable: chat.pane,
        builder: (context, open, _) => FoldedMarks(
          text: subagentFolded(s),
          builder: (context, found) => Tap(
            onTap: () => chat.pane.value = s.call.id,
            tooltip: 'Open its steps',
            fill: failed
                ? t.crashedSoft
                : open == s.call.id
                ? t.accentSoft
                : t.subagentTint,
            padding: const EdgeInsets.symmetric(horizontal: Collapsible.side),
            child: SizedBox(
              height: Collapsible.height, // one row, as a tool call's
              // Its tag comes and goes with the chat's related worktrees,
              // and a line stays built (ADR 0026).
              child: LayoutBuilder(
                builder: (context, box) => ListenableBuilder(
                  listenable: chat.related,
                  builder: (context, _) => Row(
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.smart_toy_outlined,
                        size: 15,
                        color: failed ? t.crashed : t.subagentAccent,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: subagentShine(
                                s,
                                subagentName(context, s),
                                still: still,
                              ),
                            ),
                            FoundCount(found),
                          ],
                        ),
                      ),
                      if (chat.related.tagFor(s.call.id) case final tag
                          when tag.isNotEmpty)
                        // A cap, not Flexible, which would
                        // take half the free width.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: (box.maxWidth * 0.25).clamp(72, 160),
                          ),
                          child: WorktreeTag(tag),
                        ),
                      // The name takes the room; the state ends the line,
                      // a third of it at most where the row is narrow (a
                      // phone's), so the name still says which it is.
                      // Narrow, its parts give way from the front, its
                      // tokens and time last; wide, those are apart, muted
                      // (and a done one's words may be none).
                      if (box.maxWidth < _timeApart ||
                          _stateWords(s).isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: math.min(
                              240,
                              math.max(
                                box.maxWidth / 3,
                                // Narrow, room for its time and tokens, up
                                // to half the line.
                                box.maxWidth < _timeApart
                                    ? math.min(
                                        box.maxWidth / 2,
                                        liveTextWidth(
                                              context,
                                              subagentTime(s),
                                              state,
                                            ) +
                                            1,
                                      )
                                    : 0,
                              ),
                            ),
                          ),
                          child: SubagentState(
                            s,
                            style: state,
                            time: box.maxWidth < _timeApart,
                            fitted: box.maxWidth < _timeApart,
                          ),
                        ),
                      if (box.maxWidth >= _timeApart)
                        if (subagentTime(s).isNotEmpty || subagentRunning(s))
                          LiveText(
                            // After its words, a dot joins them: "39 tools
                            // · 182k tokens · 7m 55s" reads as one line.
                            () => switch (subagentTime(s)) {
                              '' => '',
                              final time when _stateWords(s).isEmpty => time,
                              final time => '· $time',
                            },
                            live: subagentRunning(s),
                            style: theme.ui(t.textMuted, size: 12),
                          ),
                      if (hover && daemon != null && subagentStoppable(s))
                        stopButton(context, daemon, chat, s.call.id, size: 13)
                      else
                        subagentMark(s),
                      Icon(paneIcon, size: 15, color: t.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The narrowest subagent row whose time and tokens show apart from its
/// state, at its end.
const double _timeApart = 420;

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
