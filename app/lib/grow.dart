import 'package:flutter/widgets.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/slides.dart';

/// A line that comes and goes in a column (the composer's plan, queue and
/// error lines): while [child] is there it grows in from no height over
/// [Motion.standard] on [Motion.size], fading in with it; once it's null
/// the last child folds away and fades over [Motion.exit], taking no
/// pointer or focus as it goes. A change of the child's own height eases
/// too. A second change reverses from where it is. With Reduce Motion it
/// comes and goes at once. It takes the width it's given, and paints
/// apart from what's around it (the composer's box under it).
class GrowLine extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) => BarSlide(
    down: false,
    curve: Motion.size,
    child: switch (child) {
      final child? => EaseSize(child: RepaintBoundary(child: child)),
      null => null,
    },
  );
}
