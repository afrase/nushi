import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// What [builder] builds, while [show]: it fades in rising 6 px over
/// [Motion.standard] and fades out over [Motion.exit], taking no pointer
/// or focus as it goes; not shown, nothing is built. With Reduce Motion it
/// comes and goes at once.
class ChipFade extends StatefulWidget {
  const new({required this.show, required this.builder, super.key});

  final bool show;
  final WidgetBuilder builder;

  @override
  State<ChipFade> createState() => _ChipFadeState();
}

class _ChipFadeState extends State<ChipFade>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.standard,
    reverseDuration: Motion.exit,
    value: widget.show ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(ChipFade old) {
    super.didUpdateWidget(old);
    if (widget.show == old.show) return;
    if (reduceMotion(context)) {
      _c.value = widget.show ? 1 : 0;
    } else if (widget.show) {
      _c.forward().ignore();
    } else {
      _c.reverse().ignore();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isDismissed) return const SizedBox.shrink();
    final leaving = !widget.show;
    return IgnorePointer(
      ignoring: leaving,
      child: ExcludeFocus(
        excluding: leaving,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final v = _c.value;
            final rise = leaving ? 0.0 : 1 - Motion.settle.transform(v);
            return Opacity(
              opacity: leaving ? 1 - Motion.leave.transform(1 - v) : v,
              child: Transform.translate(
                offset: Offset(0, 6 * rise),
                child: child,
              ),
            );
          },
          child: Builder(builder: widget.builder),
        ),
      ),
    );
  }
}

/// The chip over a transcript scrolled up, back to the latest: "Jump to
/// latest", or, while the agent waits on a permission prompt or question
/// ([needs]), amber and "Needs you ↓", hopping once as it turns so (still
/// with Reduce Motion). On the phone ([TouchTargets]) it's the arrow
/// alone, on a round button of the same fill, its words its tooltip.
class JumpChip extends StatefulWidget {
  const new({required this.needs, required this.onTap, super.key});

  /// The phone's round face, [round] points across, in a finger's target.
  static const roundKey = Key('jump-round');

  /// The phone's round face's width.
  static const round = 38.0;

  final bool needs;
  final VoidCallback onTap;

  @override
  State<JumpChip> createState() => _JumpChipState();
}

class _JumpChipState extends State<JumpChip>
    with SingleTickerProviderStateMixin, ClockRun {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.needs) _hop();
    });
  }

  @override
  void didUpdateWidget(JumpChip old) {
    super.didUpdateWidget(old);
    if (widget.needs && !old.needs) _hop();
  }

  void _hop() {
    if (!reduceMotion(context)) runFor(hopFor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final needs = widget.needs;
    final color = needs ? t.needs : t.text;
    final fill = needs ? t.needsSoft : t.lifted;
    // On a card's fill, lifted off the text under it by a soft shadow, not
    // an outline (ADR 0111).
    final shadow = [
      BoxShadow(color: t.shadow, blurRadius: 12, offset: const Offset(0, 3)),
    ];
    final Widget chip;
    if (TouchTargets.of(context)) {
      // The phone's: the arrow says it; a pill of words is too much there.
      // A button to VoiceOver, named by its tooltip, as RoundButton is.
      chip = Semantics(
        button: true,
        child: Pressable(
          onTap: widget.onTap,
          tooltip: needs ? 'Needs you: jump to latest' : 'Jump to latest',
          builder: (context, look) => Container(
            key: JumpChip.roundKey,
            width: JumpChip.round,
            height: JumpChip.round,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: look.pressed
                  ? Color.alphaBlend(t.pressed, fill)
                  : look.hover
                  ? Color.alphaBlend(t.hover, fill)
                  : fill,
              shape: BoxShape.circle,
              boxShadow: shadow,
            ),
            child: Icon(Icons.arrow_downward, size: 18, color: color),
          ),
        ),
      );
    } else {
      final icon = Icon(Icons.arrow_downward, size: 14, color: color);
      chip = DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(NushiTheme.pill),
          boxShadow: shadow,
        ),
        child: Tap(
          onTap: widget.onTap,
          radius: NushiTheme.pill,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (!needs) icon,
              Text(
                needs ? 'Needs you' : 'Jump to latest',
                style: theme.ui(color, size: 12, weight: FontWeight.w500),
              ),
              if (needs) icon,
            ],
          ),
        ),
      );
    }
    if (!running) return chip;
    return Transform.translate(
      offset: Offset(0, -hopHeight(ranMs / hopFor.inMilliseconds)),
      child: chip,
    );
  }
}
