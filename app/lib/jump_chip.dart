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
/// with Reduce Motion).
class JumpChip extends StatefulWidget {
  const new({required this.needs, required this.onTap, super.key});

  final bool needs;
  final VoidCallback onTap;

  @override
  State<JumpChip> createState() => _JumpChipState();
}

class _JumpChipState extends State<JumpChip> with ClockRun {
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
    final icon = Icon(Icons.arrow_downward, size: 14, color: color);
    final chip = DecoratedBox(
      decoration: ShapeDecoration(
        color: needs ? t.needsSoft : t.raised,
        shape: StadiumBorder(
          side: BorderSide(color: needs ? t.needs : t.borderStrong),
        ),
      ),
      child: Tap(
        onTap: widget.onTap,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (!needs) icon,
            Text(
              needs ? 'Needs you' : 'Jump to latest',
              style: theme.ui(color, size: 12),
            ),
            if (needs) icon,
          ],
        ),
      ),
    );
    if (!running) return chip;
    return Transform.translate(
      offset: Offset(0, -hopHeight(ranMs / hopFor.inMilliseconds)),
      child: chip,
    );
  }
}
