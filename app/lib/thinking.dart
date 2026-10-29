import 'package:flutter/material.dart';

import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/paced.dart';
import 'package:nushi/status.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thought_line.dart';
import 'package:nushi/widgets.dart';

/// The agent's thinking: a dim "Thinking…" line that opens to the
/// thoughts, shining while they stream ([live]), the newest sentence
/// under it while folded ([ThoughtLine]). Once done, "Thought for 12s",
/// as long as the app watched it stream; "Thought" for one it loaded.
class ThoughtView extends StatefulWidget {
  const new(this.item, {required this.live, super.key});

  final Item item;
  final bool live;

  @override
  State<ThoughtView> createState() => _ThoughtViewState();
}

class _ThoughtViewState extends State<ThoughtView> {
  late DateTime? _since = widget.live ? DateTime.now() : null;
  Duration? _took;

  @override
  void didUpdateWidget(ThoughtView old) {
    super.didUpdateWidget(old);
    if (widget.live) _since ??= DateTime.now();
    if (old.live && !widget.live && _since != null) {
      _took = DateTime.now().difference(_since!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    final took = _took;
    // Its words come as a message's do, paced ([Paced]).
    return Paced(
      widget.item.text,
      live: live,
      builder: (context, shown) => Folded(
        live
            ? 'Thinking…'
            : took == null
            ? 'Thought'
            : 'Thought for ${elapsed(took)}',
        widget.item.text,
        live: live,
        shown: shown,
        line: _since == null
            ? null
            : (style) => ThoughtLine(
                shown?.text ?? widget.item.text,
                live: live,
                style: style,
              ),
      ),
    );
  }
}

/// What streamed of a response the model's safeguards stopped (the agent
/// dropped it and went on): folded and dim, above the agent's notice.
class StoppedView extends StatelessWidget {
  const new(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) =>
      Folded('Stopped by safeguards', item.text, live: false);
}

/// A dim, italic [label] that opens to [text], shining while [live]; folded,
/// [line] under it, in its style.
class Folded extends StatefulWidget {
  const new(
    this.label,
    this.text, {
    required this.live,
    super.key,
    this.line,
    this.shown,
  });

  final String label;
  final String text;
  final bool live;
  final Widget Function(TextStyle style)? line;

  /// While [text] is paced, what of it shows, opened.
  final Shown? shown;

  @override
  State<Folded> createState() => _FoldedState();
}

class _FoldedState extends State<Folded> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final style = theme
        .ui(theme.t.textMuted, size: 12.5)
        .copyWith(fontStyle: FontStyle.italic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Chevron(open: _open),
              Shine(
                on: widget.live,
                child: Text(widget.label, style: style),
              ),
            ],
          ),
        ),
        if (!_open && widget.line != null)
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: widget.line!(style),
          ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(left: 6, top: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.t.borderStrong, width: 2),
              ),
            ),
            child: switch (widget.shown) {
              final shown? => Text.rich(pacedSpan(shown, style)),
              null => Text(widget.text, style: style),
            },
          ),
      ],
    );
  }
}

/// The agent's plan as a checklist, ticked off as the agent works.
class PlanView extends StatelessWidget {
  const new(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final done = item.plan.where((e) => e.status == 'completed').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: box(t.borderSubtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            'Plan · $done of ${item.plan.length} done',
            style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
          ),
          for (final e in item.plan)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: switch (e.status) {
                    'completed' => Icon(
                      Icons.check_circle,
                      size: 14,
                      color: t.done,
                    ),
                    'in_progress' => Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: t.running,
                    ),
                    _ => Icon(
                      Icons.radio_button_unchecked,
                      size: 14,
                      color: t.textMuted,
                    ),
                  },
                ),
                Expanded(
                  child: Text(
                    e.content,
                    style: switch (e.status) {
                      'completed' => theme.ui(t.textMuted),
                      'in_progress' => theme.ui(
                        t.text,
                        weight: FontWeight.w600,
                      ),
                      _ => theme.ui(t.text),
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The current step of the turn's plan, one line above the composer while
/// the agent works, as the plan itself may have scrolled away.
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
          if (now != null)
            Expanded(
              child: Text(
                now.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.ui(t.text, size: 12),
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
