import 'package:flutter/widgets.dart';

import 'package:nushi/motion.dart';

/// A line that comes and goes in a column (the composer's plan, queue and
/// error lines): while [child] is there it grows in from no height over
/// [Motion.standard], fading in over [Motion.quick]; once it's null the
/// last child folds away and fades over [Motion.exit], taking no pointer
/// or focus as it goes. A change of the child's own height eases too. A
/// second change reverses from where it is. With Reduce Motion it comes
/// and goes at once. It takes the width it's given.
class GrowLine extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget? child;

  @override
  State<GrowLine> createState() => _GrowLineState();
}

class _GrowLineState extends State<GrowLine>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.standard,
    reverseDuration: Motion.exit,
    value: widget.child == null ? 0 : 1,
  )..addStatusListener((_) => setState(() {}));
  late final _size = CurvedAnimation(
    parent: _c,
    curve: Motion.size,
    reverseCurve: Motion.leave.flipped,
  );
  late final _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.6), // Motion.quick of Motion.standard
    reverseCurve: Motion.leave.flipped,
  );
  late Widget? _last = widget.child; // what folds away

  @override
  void didUpdateWidget(GrowLine old) {
    super.didUpdateWidget(old);
    if (widget.child case final c?) _last = c;
    final show = widget.child != null;
    if (show == (old.child != null)) return;
    if (reduceMotion(context)) {
      _c.value = show ? 1 : 0;
    } else if (show) {
      _c.forward().ignore();
    } else {
      _c.reverse().ignore();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _fade.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isDismissed) {
      _last = null;
      return const SizedBox.shrink();
    }
    final leaving = widget.child == null;
    // The width it's given, as in a stretched column (the size eases only
    // the height). With Reduce Motion, no AnimatedSize (one of no length
    // relays out as it lays out).
    final fill = SizedBox(width: double.infinity, child: _last);
    final line = reduceMotion(context)
        ? fill
        : AnimatedSize(
            duration: Motion.standard,
            curve: Motion.size,
            alignment: AlignmentDirectional.topStart,
            child: fill,
          );
    // The same widgets throughout, so the line keeps its state; at rest
    // the fade adds no layer.
    return IgnorePointer(
      ignoring: leaving,
      child: ExcludeFocus(
        excluding: leaving,
        child: SizeTransition(
          sizeFactor: _size,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: _fade, child: line),
        ),
      ),
    );
  }
}

/// [child] coming in once, as it's first built: it fades in and grows
/// from [from] of its size over [Motion.quick] (a box's button, a queued
/// message's pill). Not [play], or with Reduce Motion, it's there at once.
class PopIn extends StatefulWidget {
  const new({
    required this.child,
    super.key,
    this.play = true,
    this.from = 0.85,
  });

  final Widget child;
  final bool play;
  final double from;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.play || reduceMotion(context)) return;
    _c = AnimationController(vsync: this, duration: Motion.quick)
      ..addStatusListener((s) {
        if (s.isCompleted) setState(() => _c = null);
      })
      ..forward().ignore();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final a = c ?? kAlwaysCompleteAnimation;
    // The same widgets throughout, so the child keeps its state.
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) {
        final v = Motion.settle.transform(a.value);
        return Opacity(
          opacity: a.value,
          child: Transform.scale(
            scale: widget.from + (1 - widget.from) * v,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
