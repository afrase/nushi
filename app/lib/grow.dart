import 'package:flutter/widgets.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/slides.dart';

/// A line that comes and goes in a column (the composer's plan, queue and
/// error lines): while [child] is there it grows in from no height over
/// [Motion.standard], fading in over [Motion.quick]; once it's null the
/// last child folds away and fades over [Motion.exit], taking no pointer
/// or focus as it goes. A change of the child's own height eases too. A
/// second change reverses from where it is. With Reduce Motion it comes
/// and goes at once. It takes the width it's given.
class GrowLine extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) => Presence(
    enter: Motion.standard,
    curve: Motion.size,
    builder: (context, run, last) {
      // The width it's given, as in a stretched column (the size eases
      // only the height).
      final line = EaseSize(
        child: SizedBox(width: double.infinity, child: last),
      );
      // The same widgets throughout, so the line keeps its state; at rest
      // the fade adds no layer. Coming, it's in by Motion.quick.
      final fade = run.status == AnimationStatus.reverse
          ? run
          : run.drive(CurveTween(curve: const Interval(0, 0.6)));
      return SizeTransition(
        sizeFactor: run,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: fade, child: line),
      );
    },
    child: child,
  );
}
