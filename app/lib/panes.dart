import 'dart:math';

import 'package:flutter/material.dart';

import 'settings.dart';
import 'theme/theme.dart';

/// A pane of a remembered width, with a draggable edge on its [left] or
/// right side: a thin line that highlights under the pointer. Dragging it
/// resizes the pane between [min] and [max]; a double-click resets it to
/// [initial]. The width is remembered across launches by [name].
class Resizable extends StatefulWidget {
  const Resizable({
    super.key,
    required this.name,
    required this.initial,
    required this.min,
    required this.max,
    this.left = false,
    required this.child,
  });

  final String name;
  final double initial;
  final double min;
  final double max; // below [min] when there's no room: [min] wins
  final bool left;
  final Widget child;

  @override
  State<Resizable> createState() => _ResizableState();
}

/// The width the pane [name] was given, or [initial].
double paneWidth(String name, double initial) =>
    paneWidths.value[name] ?? initial;

class _ResizableState extends State<Resizable> {
  double? _dragged; // the width the drag asks for, not yet clamped
  bool _hover = false;

  double _width() => (_dragged ?? paneWidth(widget.name, widget.initial)).clamp(
    widget.min,
    max(widget.min, widget.max),
  );

  void _set(double? width) => paneWidths.value = {
    ...{...paneWidths.value}..remove(widget.name),
    widget.name: ?width,
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: paneWidths,
    builder: (context, _, _) {
      final t = NushiTheme.of(context).t;
      final active = _hover || _dragged != null;
      final edge = MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => _set(null),
          onHorizontalDragStart: (_) => setState(() => _dragged = _width()),
          onHorizontalDragUpdate: (d) => setState(
            () =>
                _dragged = _dragged! + (widget.left ? -d.delta.dx : d.delta.dx),
          ),
          onHorizontalDragEnd: (_) {
            _set(_width().roundToDouble());
            setState(() => _dragged = null);
          },
          child: Align(
            alignment: widget.left
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: active ? 2 : 1,
              color: active ? t.focus : t.borderSubtle,
            ),
          ),
        ),
      );
      return SizedBox(
        width: _width(),
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: 0,
              bottom: 0,
              width: 5,
              left: widget.left ? 0 : null,
              right: widget.left ? null : 0,
              child: edge,
            ),
          ],
        ),
      );
    },
  );
}
