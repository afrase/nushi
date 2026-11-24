import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';

/// The agent's plan as a checklist on a card (ADR 0111), ticked off as the
/// agent works (the fluidity review's idea 16): "Plan · 2 of 4 done" and
/// that count as a thin bar at the card's top right. A step done while the
/// chat is open draws its check ([CheckPainter]) as its words dim; the
/// running step is a dot of the accent in a soft halo, its words medium,
/// and while the agent works on this plan (its turn runs and the plan is
/// the turn's) they shine and a ring grows out of the dot ([StatusMark]); a
/// step to come is a quiet ring. A plan the chat opened with shows still,
/// and so does one whose turn has ended. With Reduce Motion only colors
/// change: the check is whole at once, and nothing shines or rings.
///
/// In its chat's own transcript ([pinnable]), the plan pinned over the
/// composer ([pinnedPlan], ADR 0135) is a line saying so in the card's
/// place, and becomes the card once it's pinned no longer.
class PlanView extends StatefulWidget {
  const new(this.item, this.chat, {super.key, this.pinnable = false});

  final Item item;
  final ChatState chat;

  /// Whether it's a line in its card's place while it's the pinned plan.
  final bool pinnable;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  late bool _working = planWorking(widget.chat, widget.item);
  late bool _pinned = _isPinned();
  int _revision = -1; // the chat's items when [_pinned] was worked out

  bool _isPinned() {
    _revision = widget.chat.revision;
    return widget.pinnable &&
        pinnedPlan(widget.chat.items)?.id == widget.item.id;
  }

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_changed);
  }

  @override
  void didUpdateWidget(PlanView old) {
    super.didUpdateWidget(old);
    if (old.chat != widget.chat) {
      old.chat.removeListener(_changed);
      widget.chat.addListener(_changed);
    }
    _working = planWorking(widget.chat, widget.item);
    _pinned = _isPinned();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    super.dispose();
  }

  // Usage, config and status notify too: only a change of working or of the
  // pinned plan rebuilds, and the pinned one is looked for again only once
  // the items changed.
  void _changed() {
    final working = planWorking(widget.chat, widget.item);
    final pinned = widget.chat.revision == _revision ? _pinned : _isPinned();
    if (working != _working || pinned != _pinned) {
      setState(() {
        _working = working;
        _pinned = pinned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final plan = widget.item.plan;
    if (_pinned) {
      // Where the plan was made, while it shows over the composer.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          spacing: 10,
          children: [
            Icon(Icons.checklist, size: 15, color: t.textMuted),
            Expanded(child: PlanTitle(plan, more: ' · shown over the box')),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(NushiTheme.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              spacing: 10,
              children: [
                Icon(Icons.checklist, size: 15, color: t.textSecondary),
                Expanded(child: PlanTitle(plan)),
                if (plan.isNotEmpty) PlanProgress(plan),
              ],
            ),
          ),
          for (final e in plan)
            PlanStep(e.content, e.status, working: _working),
        ],
      ),
    );
  }
}

/// How many of [plan]'s steps are done.
int planDone(List<PlanEntry> plan) =>
    plan.where((e) => e.status == 'completed').length;

/// "Plan · 2 of 4 done", the plan's name and count on one line, cut short
/// at its end; [short], "Plan · 2/4", for a narrow line; [more] after it,
/// muted as the count.
class PlanTitle extends StatelessWidget {
  const new(this.plan, {super.key, this.short = false, this.more = ''});

  final List<PlanEntry> plan;
  final bool short;
  final String more;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final done = planDone(plan);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Plan',
            style: theme.ui(t.text, weight: FontWeight.w600),
          ),
          TextSpan(
            text: short
                ? ' · $done/${plan.length}$more'
                : ' · $done of ${plan.length} done$more',
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.ui(t.textMuted),
    );
  }
}

/// How much of [plan] is done, as a thin bar with round ends, [width]
/// long.
class PlanProgress extends StatelessWidget {
  const new(this.plan, {super.key, this.width = 120});

  final List<PlanEntry> plan;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final part = plan.isEmpty ? 0.0 : planDone(plan) / plan.length;
    return Container(
      width: width,
      height: 6,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.pill),
      ),
      child: FractionallySizedBox(
        widthFactor: part.clamp(0, 1),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.done,
            borderRadius: BorderRadius.circular(NushiTheme.pill),
          ),
        ),
      ),
    );
  }
}

/// One step of a plan: its mark and its words, by its status; [oneLine],
/// its words on one line cut short at their end (the pinned plan's
/// collapsed line), otherwise wrapped.
class PlanStep extends StatefulWidget {
  const new(
    this.content,
    this.status, {
    required this.working,
    super.key,
    this.oneLine = false,
  });

  final String content;
  final String status;
  final bool working;
  final bool oneLine;

  @override
  State<PlanStep> createState() => _PlanStepState();
}

class _PlanStepState extends State<PlanStep>
    with SingleTickerProviderStateMixin, ClockRun {
  static const _size = 16.0;

  @override
  void didUpdateWidget(PlanStep old) {
    super.didUpdateWidget(old);
    if (old.status != 'completed' &&
        widget.status == 'completed' &&
        !reduceMotion(context)) {
      runFor(CheckPainter.drawFor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final still = reduceMotion(context);
    final mark = switch (widget.status) {
      'completed' => CheckPainter(
        t.textMuted,
        running
            ? part(
                ranMs,
                0,
                CheckPainter.drawFor.inMilliseconds.toDouble(),
                Curves.easeOut,
              )
            : 1,
        1,
      ),
      // A working chat's ring while the agent works on it; in a still
      // frame (a golden) its dot in its halo ([loopRepaintOf]).
      'in_progress' => StatusMark(
        t.running,
        halo: t.accentSoft,
        ringing: widget.working && !still && loopRepaintOf(context) != null,
        repaint: loopRepaintOf(context),
      ),
      _ => StepRing(t.textMuted),
    };
    final one = widget.oneLine;
    return Row(
      crossAxisAlignment: one
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      spacing: one ? 8 : 10,
      children: [
        Padding(
          padding: EdgeInsets.only(top: one ? 0 : 1),
          child: CustomPaint(size: const Size.square(_size), painter: mark),
        ),
        Expanded(
          // The style eases, so a step done dims; outside the shine, which
          // comes and goes around the words as the step runs and ends.
          child: AnimatedDefaultTextStyle(
            duration: Motion.standard,
            curve: Motion.size,
            style: switch (widget.status) {
              'completed' => theme.ui(t.textMuted),
              'in_progress' => theme.ui(t.text, weight: FontWeight.w500),
              _ => theme.ui(t.textSecondary),
            },
            maxLines: one ? 1 : null,
            overflow: one ? TextOverflow.ellipsis : TextOverflow.clip,
            child: Shine(
              on: widget.status == 'in_progress' && widget.working,
              child: Text(widget.content),
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether the agent works on [plan] now: its chat's turn runs and the
/// plan is the turn's.
bool planWorking(ChatState chat, Item plan) =>
    chat.busy && turnPlan(chat.items)?.id == plan.id;

/// The plan of the current turn (since the last prompt), if any.
Item? turnPlan(List<Item> items) {
  for (final it in items.reversed) {
    if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return null;
    if (it.kind == ItemKind.ITEM_KIND_PLAN) return it;
  }
  return null;
}

/// The plan pinned over the composer (ADR 0135): the chat's latest plan
/// while a step of it isn't done, whichever turn made it. The daemon keeps
/// one plan a turn, updated in place, and a later turn's plan is a new
/// item only once it changed (`planLocked`), so the latest is the one the
/// agent works to; a plan whose every step is done is pinned no longer.
/// Only what the chat has loaded is looked in.
Item? pinnedPlan(List<Item> items) {
  for (final it in items.reversed) {
    if (it.kind != ItemKind.ITEM_KIND_PLAN) continue;
    return planDone(it.plan) < it.plan.length ? it : null;
  }
  return null;
}
