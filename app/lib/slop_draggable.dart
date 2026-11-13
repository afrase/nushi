import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How far the pointer moves, pressed, before something that's clicked as
/// well as dragged starts to drag (a project's tile in the rail); within
/// it a press is still a click (`Pressable.slop`). Flutter's own is a
/// point for a mouse, which a click on a trackpad can pass.
const dragSlop = 4.0;

/// A [Draggable] whose drag starts only once the pointer has moved more
/// than [slop] (or the device's own slop, if that's more: a finger's).
/// With none, it's Flutter's own [Draggable].
class SlopDraggable<T extends Object> extends Draggable<T> {
  const new({
    required super.child,
    required super.feedback,
    super.key,
    super.data,
    super.maxSimultaneousDrags,
    super.dragAnchorStrategy,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDragEnd,
    this.slop = 0,
  });

  final double slop;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      _SlopDragRecognizer(slop, allowedButtonsFilter: allowedButtonsFilter)
        ..onStart = onStart;
}

class _SlopDragRecognizer extends MultiDragGestureRecognizer {
  new(this.slop, {super.allowedButtonsFilter}) : super(debugOwner: null);

  final double slop;

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SlopPointerState(slop, event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'drag past a slop';
}

class _SlopPointerState extends MultiDragPointerState {
  new(this.slop, super.initialPosition, super.kind, super.gestureSettings);

  final double slop;

  @override
  void checkForResolutionAfterMove() {
    final past = math.max(slop, computeHitSlop(kind, gestureSettings));
    if (pendingDelta!.distance > past) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}
