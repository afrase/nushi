import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:nushi/motion.dart';
import 'package:nushi/widgets.dart';

// Every chevron's motion (the fluidity review's idea 2): what a chevron
// opens grows to its height and folds back ([Disclosure]) as the chevron
// turns ([TurnChevron]), together, over [Motion.standard] on [Motion.size].
// A second click reverses it from where it is; with Reduce Motion it opens
// and folds at once. Not the file tree's folders: big lists, used at speed.

/// [child] while [open]: it grows from nothing to its height as [open]
/// turns on and folds back as it turns off, its top staying put; folded,
/// it isn't built. Its width is its parent's, as without it.
class Disclosure extends StatefulWidget {
  const new({required this.open, required this.child, super.key});

  final bool open;
  final Widget child;

  @override
  State<Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<Disclosure>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(
        vsync: this,
        duration: Motion.standard,
        value: widget.open ? 1 : 0,
      )..addStatusListener((s) {
        // Folded: the child goes; open: the clip goes.
        if (!s.isAnimating) setState(() {});
      });
  late final _eased = CurvedAnimation(parent: _c, curve: Motion.size);

  @override
  void didUpdateWidget(Disclosure old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (reduceMotion(context)) {
      _c.value = widget.open ? 1 : 0;
    } else {
      (widget.open ? _c.forward() : _c.reverse()).ignore();
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open && _c.isDismissed) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _eased,
      builder: (context, child) =>
          Fold(factor: _c.isCompleted ? 1 : _eased.value, child: child),
      child: widget.child,
    );
  }
}

/// [child] laid out as its parent lays it out, any height, taking
/// [factor] of its height from the top, and clipped to that while it's
/// less than 1 (unless not [clip]). Unlike a SizeTransition it doesn't
/// loosen the width: a stretched child stays stretched.
class Fold extends SingleChildRenderObjectWidget {
  const new({required this.factor, super.child, super.key, this.clip = true});

  final double factor;
  final bool clip;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFold(factor)..clip = clip;

  @override
  void updateRenderObject(BuildContext context, RenderFold renderObject) =>
      renderObject
        ..factor = factor
        ..clip = clip;
}

/// [Fold]'s render object.
class RenderFold extends RenderProxyBox {
  new(this._factor);

  bool _clip = true;
  bool get clip => _clip;
  set clip(bool v) {
    if (v == _clip) return;
    _clip = v;
    markNeedsPaint();
  }

  double _factor;
  double get factor => _factor;
  set factor(double v) {
    if (v == _factor) return;
    _factor = v;
    markNeedsLayout();
  }

  final _clipLayer = LayerHandle<ClipRectLayer>();

  BoxConstraints _inner(BoxConstraints c) =>
      _factor >= 1 ? c : c.copyWith(minHeight: 0, maxHeight: double.infinity);

  Size _outer(BoxConstraints c, Size child) => c.constrain(
    Size(child.width, _factor >= 1 ? child.height : child.height * _factor),
  );

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_inner(constraints), parentUsesSize: true);
    size = _outer(constraints, c.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    return _outer(constraints, c.getDryLayout(_inner(constraints)));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width) * _factor;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width) * _factor;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      size.contains(position) && super.hitTest(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    if (_factor >= 1 || !_clip) {
      _clipLayer.layer = null;
      context.paintChild(c, offset);
      return;
    }
    if (size.isEmpty) {
      _clipLayer.layer = null;
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(c, offset),
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _factor >= 1 || !_clip ? null : Offset.zero & size;

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// A [Chevron] that turns as it opens or closes, in step with a
/// [Disclosure]: right while closed, down while open; at rest it's drawn
/// as [Chevron] is.
class TurnChevron extends StatefulWidget {
  const new({required this.open, super.key, this.size = 14, this.color});

  final bool open;
  final double size;
  final Color? color;

  @override
  State<TurnChevron> createState() => _TurnChevronState();
}

class _TurnChevronState extends State<TurnChevron>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(
        vsync: this,
        duration: Motion.standard,
        value: widget.open ? 1 : 0,
      )..addStatusListener((s) {
        if (!s.isAnimating) setState(() {});
      });
  late final _eased = CurvedAnimation(parent: _c, curve: Motion.size);

  @override
  void didUpdateWidget(TurnChevron old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (reduceMotion(context)) {
      _c.value = widget.open ? 1 : 0;
    } else {
      (widget.open ? _c.forward() : _c.reverse()).ignore();
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // At rest the glyph itself, so a still frame is as it was; turning,
    // the closed one by a quarter at most.
    if (!_c.isAnimating) {
      return Chevron(open: widget.open, size: widget.size, color: widget.color);
    }
    return RotationTransition(
      turns: Tween(begin: 0.0, end: 0.25).animate(_eased),
      child: Chevron(open: false, size: widget.size, color: widget.color),
    );
  }
}
