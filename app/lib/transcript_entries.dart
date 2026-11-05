import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/message_actions.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/subagents.dart';

// The transcript's entries: its items grouped into runs and subagents,
// their keys and the room above each, and a message on its way.

/// Whether [e] is a tool call that shows as a row, and can join a run of
/// them (a review's findings show as a card of their own).
bool _row(Object? e) =>
    e is Item && e.kind == ItemKind.ITEM_KIND_TOOL_CALL && !e.hasFindings();

/// The items, with each run of tool calls as one list, and each subagent
/// as one [SubagentRun] with what it did.
List<Object> transcriptEntries(List<Item> items) {
  final subs = {for (final s in subagentsOf(items)) s.call.id: s};
  final out = <Object>[];
  for (final it in items) {
    final last = out.lastOrNull;
    if (subs.containsKey(it.parent)) continue;
    if (subs[it.id] case final sub?) {
      out.add(sub);
    } else if (_row(it) && last is List<Item>) {
      last.add(it);
    } else if (_row(it) && _row(last)) {
      out.last = [last! as Item, it];
    } else {
      out.add(it);
    }
  }
  return out;
}

/// An entry's items: a run's calls, a subagent's call and steps, or one.
List<Item> entryItems(Object e) => switch (e) {
  final List<Item> run => run,
  final SubagentRun s => [s.call, ...s.items],
  _ => [e as Item],
};

/// An entry's key: a call and the group it becomes keep their place (and
/// state).
String entryKey(Object e) => switch (e) {
  final List<Item> run => run.first.id,
  final SubagentRun s => 'agent ${s.call.id}',
  _ => (e as Item).id,
};

/// A message of yours: faint while on its way ([state] 1), then whole over
/// [Motion.quick] as the daemon shows it; one whose send failed (2) fades
/// out and folds away over [Motion.exit] (the transcript then drops it).
/// With Reduce Motion it's faint, then whole, and goes at once.
class SendingEntry extends StatelessWidget {
  const new({required this.state, required this.child, super.key});

  final int state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final shown = AnimatedOpacity(
      opacity: state == 1 ? 0.7 : 1,
      duration: still ? Duration.zero : Motion.quick,
      child: child,
    );
    if (state != 2 || still) return shown;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: Motion.exit,
      curve: Motion.leave,
      builder: (context, v, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: v,
          child: Opacity(opacity: 0.7 * v, child: child),
        ),
      ),
      child: IgnorePointer(child: shown),
    );
  }
}

/// Whether [e] is a message of yours, which shows as a band.
bool isBand(Object e) => e is Item && e.kind == ItemKind.ITEM_KIND_USER_MESSAGE;

/// A user message's band, the agent starting on its own, or where a
/// reopened chat's history comes from changes.
bool _opens(Object e) =>
    isBand(e) ||
    e is Item &&
        e.kind == ItemKind.ITEM_KIND_NOTICE &&
        const {'own_turn', 'compacted', 'history_differs'}.contains(e.status);

/// The room above entry [i]: more around what opens a chapter than between
/// the agent's steps, so each exchange reads as one.
double entryGap(
  List<Object> entries,
  int i, {
  required bool header,
  required bool phone,
}) {
  final gap = _opens(entries[i])
      ? (i == 0 && !header
            ? 8.0
            : phone
            ? 28.0
            : 32.0)
      : (!phone
            ? 16.0
            : i > 0 && _opens(entries[i - 1])
            ? 18.0
            : 12.0);
  // A message's actions keep their room under it.
  final after = !phone && i > 0 && _hasActions(entries[i - 1]);
  return after ? max(0, gap - messageActionsHeight) : gap;
}

bool _hasActions(Object e) =>
    e is Item &&
    (e.kind == ItemKind.ITEM_KIND_USER_MESSAGE ||
        e.kind == ItemKind.ITEM_KIND_AGENT_MESSAGE);
