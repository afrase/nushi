import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/logo.dart';
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

/// The chip over a transcript scrolled up, back to the latest: a round
/// face ([face] across on the Mac, [round] on the phone) with the arrow
/// on it, its words ("Jump to latest") its tooltip. While the agent works
/// ([working]) Nushi's mark turns on it in the arrow's place, nothing else
/// changing: under the pointer or the keyboard's focus the arrow is back,
/// and a press jumps as ever (#51). While the agent waits on a permission
/// prompt or question ([needs]) it's amber, hopping once as it turns so
/// (still with Reduce Motion): on the Mac a pill of words, "Needs you ↓",
/// as high as the face; on the phone the amber arrow. Needing you wins.
class JumpChip extends StatefulWidget {
  const new({
    required this.needs,
    required this.onTap,
    this.working = false,
    super.key,
  });

  /// The round face, [round] points across on the phone (in a finger's
  /// target), [face] on the Mac; on the Mac, every look but Needs you.
  static const roundKey = Key('jump-round');

  /// The phone's round face's width.
  static const round = 38.0;

  /// The Mac's round face's width, a regular control's height.
  static double get face => ControlSize.regular.height;

  /// How long the working mark's outer ring takes to go round on the
  /// face: quicker than the mark's drift elsewhere, so a mark this small
  /// is seen to move.
  // design: a loop's beat on pulseClock
  static const outerTurn = Duration(milliseconds: 2400);

  /// Its inner ring's, the drift's ratio kept.
  // design: a loop's beat on pulseClock
  static const innerTurn = Duration(milliseconds: 1600);

  final bool needs;
  final bool working;
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
    final phone = TouchTargets.of(context);
    final mark = widget.working && !needs;
    final Widget chip;
    if (phone || !needs) {
      // One face, whatever the agent does: only what's on it changes. A
      // button to VoiceOver, named by its tooltip, as RoundButton is.
      final size = phone ? JumpChip.round : JumpChip.face;
      chip = Pressable(
        onTap: widget.onTap,
        tooltip: needs ? 'Needs you: jump to latest' : 'Jump to latest',
        builder: (context, look) => Container(
          key: JumpChip.roundKey,
          width: size,
          height: size,
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
          foregroundDecoration: focusRing(
            t,
            look,
            radius: BorderRadius.circular(NushiTheme.pill),
          ),
          child: mark && !look.hover && !look.focus
              // In the running ink, as a working chat's dot, and large
              // enough to be seen at a glance: a state cue (#51).
              ? Logo(
                  color: t.running,
                  size: size * 0.8,
                  turning: true,
                  outerTurn: JumpChip.outerTurn,
                  innerTurn: JumpChip.innerTurn,
                )
              : Icon(Icons.arrow_downward, size: phone ? 18 : 14, color: color),
        ),
      );
    } else {
      // Needs you wants its words; as high as the face, so its middle is
      // the face's.
      chip = DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(NushiTheme.pill),
          boxShadow: shadow,
        ),
        child: Tap(
          onTap: widget.onTap,
          tooltip: 'Needs you: jump to latest',
          radius: NushiTheme.pill,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: JumpChip.face,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  'Needs you',
                  style: theme.ui(color, size: 12, weight: FontWeight.w500),
                ),
                Icon(Icons.arrow_downward, size: 14, color: color),
              ],
            ),
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
