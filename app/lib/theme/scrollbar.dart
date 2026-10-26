import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A Mac's overlay scrollbar: a thin thumb that shows while scrolling and
/// fades; it also shows when the pointer comes near it, and then widens
/// and lays a faint track under it. The mouse drags the thumb, and a click
/// on the track pages towards it.
///
/// Material's desktop `Scrollbar` does the same gestures (both are a
/// [RawScrollbar]), but only shows a track when the thumb always shows.
class MacScrollbar extends RawScrollbar {
  const new({
    required super.child,
    super.controller,
    super.notificationPredicate,
    super.key,
  }) : super(interactive: true, mainAxisMargin: 2, crossAxisMargin: 2);

  static const thin = 6.0;
  static const wide = 10.0;

  @override
  RawScrollbarState<MacScrollbar> createState() => _MacScrollbarState();
}

class _MacScrollbarState extends RawScrollbarState<MacScrollbar> {
  // 0 thin, 1 wide: the pointer is near, or the thumb is being dragged.
  late final AnimationController _near;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _near = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(updateScrollbarPainter);
  }

  @override
  void dispose() {
    _near.dispose();
    super.dispose();
  }

  @override
  void updateScrollbarPainter() {
    super.updateScrollbarPainter();
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final ink = scheme.onSurface;
    final near = _near.value;
    final thickness = lerpDouble(MacScrollbar.thin, MacScrollbar.wide, near)!;
    final thumb = _dragging
        ? (dark ? 0.6 : 0.55)
        : lerpDouble(dark ? 0.32 : 0.3, dark ? 0.48 : 0.45, near)!;
    scrollbarPainter
      ..color = ink.withValues(alpha: thumb)
      ..trackColor = ink.withValues(alpha: (dark ? 0.05 : 0.035) * near)
      ..trackBorderColor = ink.withValues(alpha: (dark ? 0.1 : 0.07) * near)
      ..thickness = thickness
      ..radius = Radius.circular(thickness / 2)
      ..minLength = 24;
  }

  void _widen(bool near) {
    if (near || _dragging) {
      _near.forward();
    } else {
      _near.reverse();
    }
  }

  @override
  void handleHover(PointerHoverEvent event) {
    super.handleHover(event);
    _widen(isPointerOverScrollbar(event.position, event.kind, forHover: true));
  }

  @override
  void handleHoverExit(PointerExitEvent event) {
    super.handleHoverExit(event);
    _widen(false);
  }

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    _dragging = true;
    _widen(true);
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _dragging = false;
    _widen(
      scrollbarPainter.hitTestInteractive(
        localPosition,
        PointerDeviceKind.mouse,
        forHover: true,
      ),
    );
  }
}
