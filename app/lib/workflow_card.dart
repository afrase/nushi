import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:nushi/workflow_phases.dart';
import 'package:nushi/workflows.dart';

/// A workflow where its call is in the transcript (ADR 0127): a row on the
/// subagents' soft tint, as a subagent's, no outline, that says each
/// thing once (#103): its name, then where it is and how long, live
/// ("Review 5/7 · 3 running · 4m 12s"), in a subagent row's order, at the
/// line's end. Narrow, the state takes a line of its own. How a run that
/// didn't end well ended has a line under it. Its chevron, at its start
/// as a tool call's, opens it in place to its description and its phases
/// with who runs in each ([WorkflowPhases]); it stays open as the chat
/// rebuilds ([Collapsible.opened]). A click elsewhere opens its pane, the
/// whole tree (the accent's soft fill while open; the failures' soft red
/// once it failed); under the pointer, a running one's mark becomes its
/// Stop, in the same room. On the phone ([Daemon.remote]) a tap anywhere
/// opens it in place, and it has no Stop: the chat's sheet stops it.
class WorkflowCard extends StatefulWidget {
  const new(this.call, this.chat, {super.key, this.daemon, this.still = false});

  final Item call;
  final ChatState chat;

  /// The daemon to stop it through; none, no Stop.
  final Daemon? daemon;

  /// No shine and no ticking (a golden, a waiting chat).
  final bool still;

  /// Below this width the state has a line of its own (a phone's
  /// transcript).
  static const narrow = 480.0;

  /// Where the lines under the name start: past the chevron and the icon.
  static const double indent = _chevronRoom + 8 + 15 + 8;

  @override
  State<WorkflowCard> createState() => _WorkflowCardState();
}

class _WorkflowCardState extends State<WorkflowCard> {
  late bool _open = Collapsible.opened.contains(widget.call.id);

  void _toggle() => setState(() {
    _open = !_open;
    _open
        ? Collapsible.opened.add(widget.call.id)
        : Collapsible.opened.remove(widget.call.id);
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final call = widget.call;
    final chat = widget.chat;
    final daemon = widget.daemon;
    final still = widget.still;
    final w = call.workflow;
    final phone = daemon?.remote ?? false;
    final failed = w.state == 'failed';
    final live = workflowLive(w);
    final ended = workflowEndWords(w, chat.agentName);
    return Hover(
      builder: (context, {required hover}) => ValueListenableBuilder(
        valueListenable: chat.pane,
        builder: (context, open, _) => Tap(
          // A click opens it in place, as a tool call's; its pane is
          // the button's at its end, so each does one thing.
          onTap: _toggle,
          // A control's corners while it's a row or two, a card's once
          // open (ADR 0110), as a tool call's.
          radius: _open ? NushiTheme.card : NushiTheme.control,
          fill: failed
              ? t.crashedSoft
              : open == call.id && !phone
              ? t.accentSoft
              : t.subagentTint,
          // The chevron's glyph where a tool call's is.
          padding: EdgeInsets.only(
            left: Collapsible.side - _chevronPad,
            right: phone ? Collapsible.side : Collapsible.side - _panePad,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < WorkflowCard.narrow;
              final style = theme.ui(
                failed
                    ? t.crashed
                    : w.stalled
                    ? t.needs
                    : t.textSecondary,
                size: 12,
              );
              // Narrow, the fullest that fits its line: its count, then
              // its tokens give way, never where it is or its time.
              final room =
                  box.maxWidth -
                  WorkflowCard.indent -
                  (phone ? _endRoomPhone : _endRoom);
              final state = LiveText(
                () => narrow
                    ? workflowStates(w).firstWhere(
                        (s) => liveTextWidth(context, s, style) <= room,
                        orElse: () => workflowStates(w).last,
                      )
                    : workflowState(w),
                live: live && !w.stalled && !still,
                style: style,
              );
              final name = Row(
                spacing: 8,
                children: [
                  // On the phone the whole card takes the tap, so its
                  // chevron is only drawn, in the same room (a button
                  // there would grow to a finger's size).
                  if (phone)
                    SizedBox(
                      width: _chevronRoom,
                      child: Center(
                        child: TurnChevron(open: _open, color: t.textSecondary),
                      ),
                    )
                  else
                    IconTap.drawn(
                      (size, color) =>
                          TurnChevron(open: _open, size: size, color: color),
                      tooltip: _open ? 'Hide its phases' : 'Show its phases',
                      size: 14,
                      padding: _chevronPad,
                      onTap: _toggle,
                    ),
                  Icon(
                    Icons.account_tree_outlined,
                    size: 15,
                    color: failed ? t.crashed : t.subagentAccent,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Shine(
                        on: live && !w.stalled && !still,
                        child: workflowName(context, call),
                      ),
                    ),
                  ),
                  // The name takes the room; the state ends its line,
                  // half of the card at most.
                  if (!narrow)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(360, box.maxWidth / 2),
                      ),
                      child: state,
                    ),
                ],
              );
              final under = [
                if (narrow) state,
                if (ended.isNotEmpty)
                  Text(
                    ended,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(failed ? t.crashed : t.textMuted, size: 12),
                  ),
              ];
              // One line as a subagent's row; with more, its mark and
              // chevron stay at the middle of its end.
              final head = ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Collapsible.height,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: under.isEmpty
                          ? SizedBox(height: Collapsible.height, child: name)
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 2,
                                children: [
                                  SizedBox(height: 20, child: name),
                                  for (final line in under)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: WorkflowCard.indent,
                                      ),
                                      child: line,
                                    ),
                                ],
                              ),
                            ),
                    ),
                    // The mark and its Stop share one room, so neither
                    // moves the state as the pointer comes and goes.
                    SizedBox(
                      width: _markRoom,
                      height: _markRoom,
                      child: Center(
                        child: hover && !phone && live && daemon != null
                            ? stopButton(
                                context,
                                daemon,
                                chat,
                                call.id,
                                size: 13,
                              )
                            : TaskMark(w.state),
                      ),
                    ),
                    if (!phone)
                      IconTap(
                        paneIcon,
                        tooltip: 'Open its agents',
                        size: 14,
                        padding: _panePad,
                        color: t.textSecondary,
                        lit: open == call.id,
                        onTap: () => chat.pane.value = call.id,
                      ),
                  ],
                ),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  head,
                  Disclosure(
                    open: _open,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: WorkflowCard.indent,
                        bottom: 10,
                      ),
                      child: WorkflowPhases(w, still: still),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The room around the card's chevron's glyph, and the chevron's whole
/// room.
const double _chevronPad = 4;
const double _chevronRoom = 14 + _chevronPad * 2;

/// The room of a card's mark, its Stop's size: Stop's 13 and its padding.
const double _markRoom = 13 + 5 * 2;

/// The room at a card's end past its words: the gaps, the mark's room and
/// the pane's button; the phone has no pane, and keeps a chevron's room.
const double _endRoom = 8 + _markRoom + 8 + 14 + _panePad * 2;
const double _endRoomPhone = 8 + _markRoom + 8 + 15;

/// The room around the pane button's glyph.
const double _panePad = 4;

/// "Workflow: review-changes", the kind in bold and the subagents'
/// accent, on one line: the card's and its pane's head, as [subagentName]
/// for a subagent.
Widget workflowName(BuildContext context, Item call, {double size = 13}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  final w = call.workflow;
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Workflow: ',
          style: theme.ui(
            t.subagentAccent,
            size: size,
            weight: FontWeight.w600,
          ),
        ),
        TextSpan(
          text: w.name.isNotEmpty ? w.name : w.runId,
          style: theme.ui(t.text, size: size),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
