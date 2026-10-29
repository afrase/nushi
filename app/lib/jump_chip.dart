import 'package:flutter/material.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

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
