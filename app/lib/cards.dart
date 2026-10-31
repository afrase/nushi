import 'package:flutter/material.dart';

import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart';
import 'package:nushi/widgets.dart';

/// A card for something the agent waits on: amber while it waits, with a
/// soft amber ring. As it comes ([Arriving]) the ring glows once: it grows
/// to 6 px and settles at its 2 over 700 ms (with Reduce Motion it's there
/// at once).
class WaitingCard extends StatefulWidget {
  const new({required this.waiting, required this.children, super.key});

  final bool waiting;
  final List<Widget> children;

  static const glowFor = Duration(milliseconds: 700);

  @override
  State<WaitingCard> createState() => _WaitingCardState();
}

class _WaitingCardState extends State<WaitingCard> with ClockRun {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.waiting && Arriving.of(context) && !reduceMotion(context)) {
      runFor(WaitingCard.glowFor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final waiting = widget.waiting;
    final decoration = box(
      waiting ? t.needs : t.borderSubtle,
      fill: waiting ? t.needsSoft : null,
    );
    // Its spread and alpha: up to 6 px at a third of the way, then 2.
    final v = running
        ? Curves.easeOut.transform(ranMs / WaitingCard.glowFor.inMilliseconds)
        : 1.0;
    final (spread, alpha) = v < 0.35
        ? (6 * v / 0.35, 0.28 * v / 0.35)
        : (6 - 4 * (v - 0.35) / 0.65, 0.28 - 0.1 * (v - 0.35) / 0.65);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: waiting
          ? decoration.copyWith(
              boxShadow: [
                BoxShadow(
                  color: t.needs.withValues(alpha: alpha),
                  spreadRadius: spread,
                ),
              ],
            )
          : decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: widget.children,
      ),
    );
  }
}

/// The card's first line: an icon and what it is about.
class CardTitle extends StatelessWidget {
  const new(this.title, {super.key, this.detail = '', this.waiting = true});

  final String title;
  final String detail;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Row(
      children: [
        Icon(
          waiting ? Icons.warning_amber_rounded : Icons.check,
          size: 14,
          color: waiting ? t.needs : t.textMuted,
        ),
        const SizedBox(width: 8),
        Text(title, style: theme.ui(t.text, weight: FontWeight.w600)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            detail,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.text, size: 12).copyWith(height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// The agent's permission prompt, with its own options as buttons: one
/// answer goes, however many clicks.
class PermissionCard extends StatefulWidget {
  const new(this.item, {required this.onAnswer, super.key});

  final Item item;
  final Future<void> Function(String optionId) onAnswer;

  @override
  State<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<PermissionCard> {
  final _answering = Runner();

  @override
  void dispose() {
    _answering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = NushiTheme.of(context);
    final pending = item.status == 'pending';
    final picked = item.options.where((o) => o.id == item.answer).firstOrNull;
    // A show call asks about a file: its raw tool name wouldn't say which.
    final shown = showPath(item);
    final title = shown == null ? item.title : 'Show $shown';
    final runs =
        shown != null &&
        const {PreviewKind.html, PreviewKind.svg}.contains(previewKind(shown));
    return WaitingCard(
      waiting: pending,
      children: [
        // Pending, what it asks for shows whole (a long command could hide
        // its end past one line), wrapped.
        CardTitle('Permission', detail: pending ? '' : title, waiting: pending),
        if (pending && title.isNotEmpty) FullTitle(title),
        if (pending && runs)
          Text(
            'A page runs as it opens in the preview.',
            style: theme.ui(theme.t.textMuted, size: 12),
          ),
        for (final d in item.diffs) DiffBox(d),
        if (item.text.isNotEmpty) AgentMarkdown(item.text),
        if (pending)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, o) in item.options.indexed)
                RunButton(
                  label: o.name,
                  kind: i == 0 ? ButtonKind.primary : ButtonKind.secondary,
                  runner: _answering,
                  run: () => widget.onAnswer(o.id),
                  wrap: true, // a phone shows what it allows whole
                ),
            ],
          )
        else
          Text(
            picked != null ? 'Answered: ${picked.name}' : 'Cancelled',
            style: theme.ui(theme.t.textMuted, size: 12),
          ),
      ],
    );
  }
}
