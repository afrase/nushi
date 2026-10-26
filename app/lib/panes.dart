import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

/// A pane of a remembered width, with a draggable edge on its [left] or
/// right side: a thin line that highlights under the pointer. Dragging it
/// resizes the pane between [min] and [max]; a double-click resets it to
/// [initial]. The width is remembered across launches by [name]. With
/// [top], the edge is on top and it is the pane's height.
class Resizable extends StatefulWidget {
  const new({
    required this.name,
    required this.initial,
    required this.min,
    required this.max,
    required this.child,
    super.key,
    this.left = false,
    this.top = false,
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

/// A pane beside a view: its remembered width's [name], the width it
/// starts at, and its least and most.
class SidePane {
  new(
    this.name, {
    required this.initial,
    required this.min,
    required this.cap,
    required this.child,
  });

  final String name;
  final double initial;
  final double min;
  final double cap;
  final Widget child;

  double get width => paneWidth(name, initial).clamp(min, cap);
}

/// [main] with [panes] beside it, left to right, and [details] at the
/// right, each resizable. When [main] would get narrower than [least], the
/// panes lie over it, by the details, rather than beside it: the details
/// stay, and so does [main]'s width under the panes.
class Beside extends StatelessWidget {
  const new({
    required this.main,
    required this.least,
    required this.panes,
    super.key,
    this.details,
  });

  final Widget main;
  final double least;
  final List<SidePane> panes;
  final SidePane? details;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ValueListenableBuilder(
      valueListenable: paneWidths,
      builder: (context, _, _) {
        final room = box.maxWidth;
        final details = this.details;
        final detailsWidth = details?.width ?? 0;
        final panesWidth = panes.fold(0.0, (w, p) => w + p.width);
        final over = room - detailsWidth - panesWidth < least;
        final t = NushiTheme.of(context).t;
        Widget resizable(SidePane p, double most) => Resizable(
          key: ValueKey(p.name),
          name: p.name,
          initial: p.initial,
          min: p.min,
          max: min(p.cap, most),
          left: true,
          child: p.child,
        );
        return CustomMultiChildLayout(
          delegate: _Beside(least),
          children: [
            LayoutId(id: _Slot.main, child: main),
            if (panes.isNotEmpty)
              LayoutId(
                id: _Slot.panes,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.base,
                    boxShadow: [
                      if (over)
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(
                            alpha: t.brightness == Brightness.dark ? 0.4 : 0.12,
                          ),
                          blurRadius: 12,
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Beside, a pane leaves [main] its least width; over
                      // it, a strip of it.
                      for (final p in panes)
                        resizable(
                          p,
                          room -
                              detailsWidth -
                              (panesWidth - p.width) -
                              (over ? 48 : least),
                        ),
                    ],
                  ),
                ),
              ),
            if (details != null)
              LayoutId(
                id: _Slot.details,
                child: resizable(
                  details,
                  room - (over ? 0 : panesWidth) - least,
                ),
              ),
          ],
        );
      },
    ),
  );
}

enum _Slot { main, panes, details }

/// Lays the details at the right, the panes left of them, and the main
/// view in what's left; when that would be under [least], it runs under
/// the panes instead. Measured as laid out, so a pane being resized moves the
/// rest with it.
class _Beside extends MultiChildLayoutDelegate {
  new(this.least);

  final double least;

  @override
  void performLayout(Size size) {
    final tall = BoxConstraints(
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
    );
    var right = size.width;
    if (hasChild(_Slot.details)) {
      right -= layoutChild(_Slot.details, tall).width;
      positionChild(_Slot.details, Offset(right, 0));
    }
    var main = right;
    if (hasChild(_Slot.panes)) {
      final panes = layoutChild(_Slot.panes, tall).width;
      positionChild(_Slot.panes, Offset(right - panes, 0));
      if (right - panes >= least) main = right - panes;
    }
    layoutChild(
      _Slot.main,
      BoxConstraints.tightFor(width: max(0, main), height: size.height),
    );
    positionChild(_Slot.main, Offset.zero);
  }

  @override
  bool shouldRelayout(_Beside old) => old.least != least;
}
