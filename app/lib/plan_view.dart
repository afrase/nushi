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
class PlanView extends StatefulWidget {
  const new(this.item, this.chat, {super.key});

  final Item item;
  final ChatState chat;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  late bool _working = _isWorking();

  bool _isWorking() =>
      widget.chat.busy && turnPlan(widget.chat.items)?.id == widget.item.id;

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
    _working = _isWorking();
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    super.dispose();
  }

  // Every streamed chunk notifies: only a change of working rebuilds.
  void _changed() {
    final working = _isWorking();
    if (working != _working) setState(() => _working = working);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final plan = widget.item.plan;
    final done = plan.where((e) => e.status == 'completed').length;
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
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Plan',
                          style: theme.ui(t.text, weight: FontWeight.w600),
                        ),
                        TextSpan(text: ' · $done of ${plan.length} done'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.ui(t.textMuted),
                  ),
                ),
                if (plan.isNotEmpty) _Progress(done / plan.length),
              ],
            ),
          ),
          for (final e in plan) _Step(e.content, e.status, working: _working),
        ],
      ),
    );
  }
}

/// How much of a plan is done, [part] of 1, as a thin bar with round ends.
class _Progress extends StatelessWidget {
  const new(this.part);

  final double part;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      width: 120,
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

/// One step of a plan: its mark and its words, by its status.
class _Step extends StatefulWidget {
  const new(this.content, this.status, {required this.working});

  final String content;
  final String status;
  final bool working;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> with ClockRun {
  static const _size = 16.0;

  @override
  void didUpdateWidget(_Step old) {
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
      // frame (a golden) its dot in its halo ([loopRepaint]).
      'in_progress' => StatusMark(
        t.running,
        halo: t.accentSoft,
        ringing: widget.working && !still && loopRepaint != null,
      ),
      _ => _Ring(t.textMuted),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
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

/// A step to come: a ring of [color].
class _Ring extends CustomPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide / 2 - 3.5,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color,
  );

  @override
  bool shouldRepaint(_Ring old) => old.color != color;
}

/// The current step of the turn's plan, one line above the composer while
/// the agent works, as the plan itself may have scrolled away. The step
/// crossfades to the next over [Motion.quick]; the count changes at once.
class PlanStatus extends StatelessWidget {
  const new(this.plan, {super.key});

  final Item plan;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final entries = plan.plan;
    final done = entries.where((e) => e.status == 'completed').length;
    final now = entries.where((e) => e.status == 'in_progress').firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.checklist, size: 14, color: t.textSecondary),
          Text(
            '$done/${entries.length}',
            style: theme.ui(t.textSecondary, size: 12),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.quick,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                now?.content ?? '',
                key: ValueKey(now?.content),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan of the current turn (since the last prompt), if any.
Item? turnPlan(List<Item> items) {
  for (final it in items.reversed) {
    if (it.kind == ItemKind.ITEM_KIND_USER_MESSAGE) return null;
    if (it.kind == ItemKind.ITEM_KIND_PLAN) return it;
  }
  return null;
}
