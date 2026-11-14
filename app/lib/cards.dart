import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart';
import 'package:nushi/web_views.dart' show webEmbedded;
import 'package:nushi/widgets.dart';

/// A card for something the agent waits on (ADR 0111): a card's fill, no
/// outline; that it waits is its amber mark and its "Needs you" pill
/// ([CardTitle]). As it comes ([Arriving]) an amber ring glows around it
/// once: it grows to 6 px and fades away over 700 ms (not with Reduce
/// Motion). Answered, it settles into its answered line ([SettleCard]).
class WaitingCard extends StatefulWidget {
  const new({required this.waiting, required this.children, super.key});

  final bool waiting;
  final List<Widget> children;

  // design: a waiting card's glow, a one-off flourish
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
    final decoration = cardBox(t);
    // Its spread and alpha: up to 6 px at a third of the way, then gone.
    final v = running
        ? Curves.easeOut.transform(ranMs / WaitingCard.glowFor.inMilliseconds)
        : 1.0;
    final (spread, alpha) = v < 0.35
        ? (6 * v / 0.35, 0.4 * v / 0.35)
        : (6 - 4 * (v - 0.35) / 0.65, 0.4 * (1 - (v - 0.35) / 0.65));
    return SettleCard(
      state: waiting,
      decoration: waiting && running
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

/// A card's box that settles as what it holds changes [state] (a prompt
/// answered): its fill and glow crossfade from what they were to
/// [decoration] over [Motion.standard], its new content fades in over
/// [Motion.quick] and its height eases over [Motion.standard], so the
/// transcript under it slides rather than jumps. With Reduce Motion the
/// colors and the height change at once.
class SettleCard extends StatefulWidget {
  const new({
    required this.decoration,
    required this.state,
    required this.child,
    super.key,
  });

  final BoxDecoration decoration;
  final Object state;
  final Widget child;

  @override
  State<SettleCard> createState() => _SettleCardState();
}

class _SettleCardState extends State<SettleCard> with ClockRun {
  BoxDecoration? _from; // the box as the state changed

  BoxDecoration _box(BoxDecoration to) {
    final from = _from;
    if (from == null || !running) return to;
    final v = Motion.size.transform(
      (ranMs / Motion.standard.inMilliseconds).clamp(0.0, 1.0),
    );
    return BoxDecoration.lerp(from, to, v)!;
  }

  @override
  void didUpdateWidget(SettleCard old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state) return;
    if (reduceMotion(context)) {
      _from = null;
      stopRun();
      return;
    }
    _from = _box(old.decoration);
    runFor(Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      key: ValueKey(widget.state),
      width: double.infinity,
      child: widget.child,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _box(widget.decoration),
      child: Marks(
        child: EaseSize(
          child: AnimatedSwitcher(
            duration: reduceMotion(context) ? Duration.zero : Motion.quick,
            // The old content goes at once and the new fades in, as the
            // card eases from the old height to its own: two texts over
            // each other read as a mess.
            layoutBuilder: (current, _) => current ?? const SizedBox(),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The card's first line: an icon and what it is about, and while it
/// [waiting] the "Needs you" pill at its end, as the chat's header and
/// its row in the sidebar say it. With no [detail], the title wraps (an
/// answered question's is the question, however long), the icon beside its
/// first line.
class CardTitle extends StatelessWidget {
  const new(this.title, {super.key, this.detail = '', this.waiting = true});

  final String title;
  final String detail;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final icon = Icon(
      waiting ? Icons.warning_amber_rounded : Icons.check,
      size: 15,
      color: waiting ? t.needs : t.textMuted,
    );
    final style = theme.ui(t.text, weight: FontWeight.w600);
    if (detail.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centred on the first line, as the row centres it on one line.
          Padding(
            padding: EdgeInsets.only(
              top:
                  (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
                          style.height! -
                      15) /
                  2,
            ),
            child: icon,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: style)),
          if (waiting) ...[const SizedBox(width: 8), const NeedsYou()],
        ],
      );
    }
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Text(title, style: style),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            overflow: TextOverflow.ellipsis,
            style: theme.code(t.text, size: 12).copyWith(height: 1.3),
          ),
        ),
        if (waiting) ...[const SizedBox(width: 8), const NeedsYou()],
      ],
    );
  }
}

/// The pill on a card the agent waits on: "Needs you", the waiting
/// state's ink on its soft fill ([PhasePill]).
class NeedsYou extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const PhasePill(ChatPhase.waiting, small: true);
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
    // A show call asks about a file or a page, a dev server tool about an
    // entry: their raw tool names wouldn't say which.
    final shown = showPath(item);
    final page = showUrl(item);
    final server = serverTool(item);
    final title = switch (serverVerbs[server]) {
      _ when shown != null => 'Show $shown',
      _ when page != null => 'Show $page',
      (_, _, final ask)? when server == 'preview_list' => ask,
      (_, _, final ask)? => '$ask ${serverName(item) ?? 'a server'}',
      null => item.title,
    };
    final runs =
        shown != null &&
        const {PreviewKind.html, PreviewKind.svg}.contains(previewKind(shown));
    final muted = theme.ui(theme.t.textMuted, size: 12);
    return WaitingCard(
      waiting: pending,
      children: [
        // Pending, what it asks for shows whole (a long command could hide
        // its end past one line), wrapped.
        CardTitle('Permission', detail: pending ? '' : title, waiting: pending),
        if (pending && title.isNotEmpty) FullTitle(title),
        // The host's app shows it: the Mac's own web view runs it unasked,
        // Linux's browser waits for a click (ADR 0104). The phone can't
        // tell which app its host has, so it says so.
        if (pending && runs && (kIsWeb || webEmbedded))
          Text('A page runs as it opens in the preview.', style: muted),
        // What the entry runs, as the daemon resolved it when it asked
        // (ADR 0100): the start that follows runs only this.
        if (pending && server == 'preview_start')
          if (item.serverCommand.isEmpty)
            Text(
              'No entry of the launch files by that name can run: '
              'the start will be refused.',
              style: theme.ui(theme.t.crashed, size: 12),
            )
          else ...[
            Text('It runs:', style: muted),
            FullTitle(plainPath(item.serverCommand)),
          ],
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
