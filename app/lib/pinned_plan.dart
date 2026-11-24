import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/plan_view.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';

/// The chat's plan pinned over the composer (ADR 0135): [pinnedPlan], on a
/// card the composer's width, so where the agent is in it is always in
/// sight however far its card in the transcript has scrolled. Its summary
/// line is the card's foot: "Plan · 1 of 3 done", collapsed the running
/// step's dot and words too, the thin bar and a chevron at the line's end,
/// which never moves, since the steps open above it. The whole line is the
/// button; collapsed or not is the app's ([planCollapsed]), on the phone
/// the screen's (collapsed as it opens). Open, the steps scroll inside
/// it past about 40% of the window's height or eight steps. In a narrow
/// column the count is short ("Plan · 1/3"), and collapsed the bar gives
/// its room to the step's words.
///
/// It grows in as a plan is pinned and folds away once it's pinned no
/// longer; a plan done to its last step keeps its place until that check
/// has drawn, then folds. A new plan takes the old one's place at once.
/// With Reduce Motion it comes, goes and opens at once.
class PinnedPlan extends StatefulWidget {
  const new(this.chat, {super.key});

  final ChatState chat;

  /// The most steps it shows open before they scroll.
  static const maxSteps = 8;

  /// The share of the window's height it takes open, at most.
  static const maxShare = 0.4;

  @override
  State<PinnedPlan> createState() => _PinnedPlanState();
}

class _PinnedPlanState extends State<PinnedPlan> {
  Item? _shown;
  int _revision = -1;
  bool _working = false;
  Timer? _leaving; // a plan done to its last step, its check drawing
  bool _phoneOpen = false; // the phone keeps it collapsed until tapped

  @override
  void initState() {
    super.initState();
    widget.chat.addListener(_changed);
    _shown = pinnedPlan(widget.chat.items);
    _revision = widget.chat.revision;
    _working = _shown != null && planWorking(widget.chat, _shown!);
  }

  @override
  void didUpdateWidget(PinnedPlan old) {
    super.didUpdateWidget(old);
    if (old.chat == widget.chat) return;
    old.chat.removeListener(_changed);
    widget.chat.addListener(_changed);
    _leaving?.cancel();
    _leaving = null;
    _shown = pinnedPlan(widget.chat.items);
    _revision = widget.chat.revision;
    _working = _shown != null && planWorking(widget.chat, _shown!);
  }

  @override
  void dispose() {
    _leaving?.cancel();
    widget.chat.removeListener(_changed);
    super.dispose();
  }

  // Usage, config and status notify too: the items are looked at again only
  // once they changed.
  void _changed() {
    final chat = widget.chat;
    var shown = _shown;
    if (chat.revision != _revision) {
      _revision = chat.revision;
      shown = pinnedPlan(chat.items);
      final last = chat.items.reversed
          .where((it) => it.kind == ItemKind.ITEM_KIND_PLAN)
          .firstOrNull;
      if (shown != null) {
        _leaving?.cancel();
        _leaving = null;
      } else if (last != null &&
          last.id == _shown?.id &&
          !reduceMotion(context)) {
        // Done to its last step: so until that check has drawn.
        shown = last;
        _leaving ??= Timer(CheckPainter.drawFor + Motion.standard, _left);
      }
    }
    final working = shown != null && planWorking(chat, shown);
    if (shown != _shown || working != _working) {
      setState(() {
        _shown = shown;
        _working = working;
      });
    }
  }

  void _left() {
    _leaving = null;
    if (!mounted) return;
    setState(() => _shown = pinnedPlan(widget.chat.items));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final touch = TouchTargets.of(context);
    return _Fold(
      child: shown == null
          ? null
          : touch
          ? _Card(
              shown,
              working: _working,
              open: _phoneOpen,
              onToggle: () => setState(() => _phoneOpen = !_phoneOpen),
            )
          : ValueListenableBuilder(
              valueListenable: planCollapsed,
              builder: (context, collapsed, _) => _Card(
                shown,
                working: _working,
                open: !collapsed,
                onToggle: () => planCollapsed.value = !collapsed,
              ),
            ),
    );
  }
}

/// The pinned plan's card: its steps over its summary line when [open].
class _Card extends StatelessWidget {
  const new(
    this.plan, {
    required this.working,
    required this.open,
    required this.onToggle,
  });

  final Item plan;
  final bool working;
  final bool open;
  final VoidCallback onToggle;

  /// The card's room around its line, which the line's tint keeps inside.
  static const _pad = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final touch = TouchTargets.of(context);
    final steps = plan.plan;
    // About a step's height with its gap, for the most that show open.
    const step = 27.0;
    final most = min(
      PinnedPlan.maxSteps * step,
      MediaQuery.sizeOf(context).height * PinnedPlan.maxShare - 48,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: t.raised,
          borderRadius: BorderRadius.circular(NushiTheme.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Fold(
              // The steps scroll above a hairline, the line under it.
              child: open
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: max(step, most),
                          ),
                          child: _Steps(steps, working: working),
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: t.line,
                        ),
                      ],
                    )
                  : null,
            ),
            Tap(
              onTap: onToggle,
              radius: NushiTheme.inner(NushiTheme.card, _pad),
              tooltip: open ? 'Collapse the plan' : 'Expand the plan',
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: touch ? 12 : 8,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: touch ? TouchTargets.size - 24 : 18,
                ),
                child: _Line(plan, working: working, open: open),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The summary line: the plan's name and count, collapsed the running
/// step too, the bar, and the chevron at its end.
class _Line extends StatelessWidget {
  const new(this.plan, {required this.working, required this.open});

  final Item plan;
  final bool working;
  final bool open;

  /// Narrower than this, the count is short and the bar shorter, and
  /// collapsed the line has no bar.
  static const _roomy = 440.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final steps = plan.plan;
    final now = steps.where((e) => e.status == 'in_progress').firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final roomy = box.maxWidth >= _roomy;
        final title = PlanTitle(steps, short: !roomy && !open);
        return Row(
          children: [
            Icon(Icons.checklist, size: 15, color: t.textSecondary),
            const SizedBox(width: 10),
            if (open || now == null)
              Expanded(child: title)
            else ...[
              title,
              const SizedBox(width: 14),
              Expanded(
                // The step crossfades to the next.
                child: AnimatedSwitcher(
                  duration: Motion.quick,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: PlanStep(
                    now.content,
                    now.status,
                    working: working,
                    oneLine: true,
                    key: ValueKey(now.content),
                  ),
                ),
              ),
            ],
            // Narrow and collapsed, the step's words before the bar.
            if (roomy || open) ...[
              const SizedBox(width: 12),
              PlanProgress(steps, width: roomy ? 120 : 64),
            ],
            const SizedBox(width: 10),
            Icon(
              open ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: t.textSecondary,
            ),
          ],
        );
      },
    );
  }
}

/// The open plan's steps, scrolling inside it past its height, the running
/// one brought into sight as it changes.
class _Steps extends StatefulWidget {
  const new(this.steps, {required this.working});

  final List<PlanEntry> steps;
  final bool working;

  @override
  State<_Steps> createState() => _StepsState();
}

class _StepsState extends State<_Steps> {
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[]; // a step's by its place: it keeps its state
  int _nowAt = -1;

  int _running() => widget.steps.indexWhere((e) => e.status == 'in_progress');

  @override
  void initState() {
    super.initState();
    _nowAt = _running();
    _show(glide: false);
  }

  @override
  void didUpdateWidget(_Steps old) {
    super.didUpdateWidget(old);
    final at = _running();
    if (at != _nowAt) {
      _nowAt = at;
      _show(glide: true);
    }
  }

  /// Brings the running step into sight once laid out.
  void _show({required bool glide}) {
    if (_nowAt < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _nowAt < _keys.length ? _keys[_nowAt].currentContext : null;
      if (!mounted || at == null || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) return;
      Scrollable.ensureVisible(
        at,
        alignment: 0.5,
        duration: glide && !reduceMotion(context)
            ? Motion.standard
            : Duration.zero,
        curve: Motion.settle,
      );
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.steps.length) {
      _keys.add(GlobalKey());
    }
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 7,
        children: [
          for (final (i, e) in widget.steps.indexed)
            PlanStep(
              e.content,
              e.status,
              working: widget.working,
              key: _keys[i],
            ),
        ],
      ),
    );
  }
}

/// [child] growing in from no height over [Motion.standard], fading in
/// over the first of it, and folding away once it's null, as the
/// composer's lines do (`GrowLine`), but with its bottom edge where it
/// is: the card stands on the composer and its steps on the summary line,
/// so what grows or folds is above them. Its height eases only so: a
/// change inside it shows at once, rather than an easing that would trail
/// the steps' own. With Reduce Motion it comes and goes at once.
class _Fold extends StatelessWidget {
  const new({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => Presence(
    enter: Motion.standard,
    curve: Motion.size,
    builder: (context, run, last) {
      final fade = run.status == AnimationStatus.reverse
          ? run
          : run.drive(CurveTween(curve: const Interval(0, 0.6)));
      return SizeTransition(
        sizeFactor: run,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(
          opacity: fade,
          child: SizedBox(width: double.infinity, child: last),
        ),
      );
    },
    child: child,
  );
}
