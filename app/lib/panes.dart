import 'dart:math';

import 'package:flutter/material.dart';

import 'settings.dart';
import 'theme/theme.dart';

/// A pane of a remembered width, with a draggable edge on its [left] or
/// right side: a thin line that highlights under the pointer. Dragging it
/// resizes the pane between [min] and [max]; a double-click resets it to
/// [initial]. The width is remembered across launches by [name]. With
/// [top], the edge is on top and it is the pane's height.
class Resizable extends StatefulWidget {
  const Resizable({
    super.key,
    required this.name,
    required this.initial,
    required this.min,
    required this.max,
    this.left = false,
    this.top = false,
    required this.child,
  });

  final String name;
  final double initial;
  final double min;
  final double max; // below [min] when there's no room: [min] wins
  final bool left;
  final bool top;
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

  void _start() => setState(() => _dragged = _width());

  void _end() {
    _set(_width().roundToDouble());
    setState(() => _dragged = null);
  }

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
      final top = widget.top;
      void drag(double d) => setState(() => _dragged = _dragged! + d);
      final edge = MouseRegion(
        cursor: top
            ? SystemMouseCursors.resizeRow
            : SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => _set(null),
          onHorizontalDragStart: top ? null : (_) => _start(),
          onHorizontalDragUpdate: top
              ? null
              : (d) => drag(widget.left ? -d.delta.dx : d.delta.dx),
          onHorizontalDragEnd: top ? null : (_) => _end(),
          onVerticalDragStart: top ? (_) => _start() : null,
          onVerticalDragUpdate: top ? (d) => drag(-d.delta.dy) : null,
          onVerticalDragEnd: top ? (_) => _end() : null,
          child: Align(
            alignment: top
                ? Alignment.topCenter
                : widget.left
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
              width: top ? null : (active ? 2 : 1),
              height: top ? (active ? 2 : 1) : null,
              color: active ? t.focus : t.borderSubtle,
            ),
          ),
        ),
      );
      return SizedBox(
        width: top ? null : _width(),
        height: top ? _width() : null,
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(
              top: 0,
              bottom: top ? null : 0,
              width: top ? null : 5,
              height: top ? 5 : null,
              left: widget.left || top ? 0 : null,
              right: widget.left ? null : 0,
              child: edge,
            ),
          ],
        ),
      );
    },
  );
}
