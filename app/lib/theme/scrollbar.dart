import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Says the lists below reach the corners of a container rounded by
/// [corner]: their scrollbars' ends keep half of it off the list's ends,
/// where the curve would otherwise cut the thumb (or, unclipped, the thumb
/// would stand out past it).
class RoundedScroll extends InheritedWidget {
  const new({required this.corner, required super.child, super.key});

  final double corner;

  /// A scrollbar's distance from its list's ends at [context].
  static double ends(BuildContext context) => max(
    MacScrollbar.margin,
    (context.dependOnInheritedWidgetOfExactType<RoundedScroll>()?.corner ?? 0) /
        2,
  );

  @override
  bool updateShouldNotify(RoundedScroll old) => old.corner != corner;
}

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
    this.past,
    double ends = margin,
    super.key,
  }) : super(interactive: true, mainAxisMargin: ends, crossAxisMargin: margin);

  /// How far the thumb keeps from its list's edges.
  static const margin = 2.0;

  static const thin = 6.0;
  static const wide = 10.0;

  /// How far its track runs on below its list's viewport, beside what's
  /// under the list (the transcript's composer): a [RawScrollbar]'s track
  /// is as long as the viewport, so it's padded by as much less.
  final ValueListenable<double>? past;

  @override
  RawScrollbarState<MacScrollbar> createState() => _MacScrollbarState();
}

class _MacScrollbarState extends RawScrollbarState<MacScrollbar> {
  // 0 thin, 1 wide: the pointer is near, or the thumb is being dragged.
  late final AnimationController _near;
  bool _dragging = false;
  EdgeInsets _padding = EdgeInsets.zero; // as RawScrollbar has it

  @override
  void initState() {
    super.initState();
    _near = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(updateScrollbarPainter);
    widget.past?.addListener(_pad);
  }

  @override
  void didUpdateWidget(MacScrollbar old) {
    super.didUpdateWidget(old);
    if (old.past != widget.past) {
      old.past?.removeListener(_pad);
      widget.past?.addListener(_pad);
      _pad();
    }
  }

  @override
  void dispose() {
    widget.past?.removeListener(_pad);
    _near.dispose();
    super.dispose();
  }

  /// The track the viewport's length and [MacScrollbar.past] more.
  void _pad() => scrollbarPainter.padding = _padding.copyWith(
    bottom: _padding.bottom - (widget.past?.value ?? 0),
  );

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
    _padding = scrollbarPainter.padding.resolve(Directionality.of(context));
    _pad();
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

  // A thumb drag's last place, and the list's extent then.
  Offset? _dragAt;
  double? _dragExtent;

  double? get _extent => switch (widget.controller) {
    final c? when c.hasClients => c.position.maxScrollExtent,
    _ => null,
  };

  @override
  void handleThumbPressStart(Offset localPosition) {
    super.handleThumbPressStart(localPosition);
    _dragging = true;
    _dragAt = localPosition;
    _dragExtent = _extent;
    _widen(true);
  }

  /// A thumb drag goes from where its thumb is: RawScrollbar maps it from
  /// where it started, against the extent at the time, so with more come
  /// in above (a transcript's page, ADR 0026) the list would jump to where
  /// that start falls now. When the extent changed since the last move,
  /// the drag starts again where the pointer is.
  @override
  void handleThumbPressUpdate(Offset localPosition) {
    if (_dragAt case final at? when _extent != _dragExtent) {
      super.handleThumbPressEnd(at, Velocity.zero);
      super.handleThumbPress();
      super.handleThumbPressStart(at);
    }
    super.handleThumbPressUpdate(localPosition);
    _dragAt = localPosition;
    _dragExtent = _extent;
  }

  @override
  void handleThumbPressEnd(Offset localPosition, Velocity velocity) {
    super.handleThumbPressEnd(localPosition, velocity);
    _dragging = false;
    _dragAt = _dragExtent = null;
    _widen(
      scrollbarPainter.hitTestInteractive(
        localPosition,
        PointerDeviceKind.mouse,
        forHover: true,
      ),
    );
  }
}
