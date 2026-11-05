import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag.dart';

/// A pane of a remembered width, with a draggable edge on its [left] or
/// right side: a thin line that highlights under the pointer. Dragging it
/// resizes the pane between [min] and [max]; a double-click resets it to
/// [initial]. The width is remembered across launches by [name]. With
/// [top], the edge is on top and it is the pane's height. The edge lies over
/// the pane's side; a platform view there keeps clear of it ([ClearOfEdge]).
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

  /// How far in from the pane's side the edge takes the pointer.
  static const edgeWidth = 5.0;

  @override
  State<Resizable> createState() => _ResizableState();
}

/// [child], a platform view (a WKWebView), kept clear of the edge of the
/// [Resizable] it's in, so the edge lies beside it, not over it. On the Mac
/// a platform view takes the pointer from the Flutter content over it except
/// where that content paints (the engine's hit-test ignore region, from what
/// each frame draws over it): over a web view only the edge's line would
/// start a drag, its unpainted rest giving the press to WebKit. A drag
/// started beside the view goes on over it: AppKit sends the drag and the
/// release to the view that took the press.
class ClearOfEdge extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding:
        context.dependOnInheritedWidgetOfExactType<_Edge>()?.inset ??
        EdgeInsets.zero,
    child: child,
  );
}

/// Where the edge of the [Resizable] around lies, for [ClearOfEdge].
class _Edge extends InheritedWidget {
  const new({required this.inset, required super.child});

  final EdgeInsets inset;

  @override
  bool updateShouldNotify(_Edge old) => inset != old.inset;
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
            Positioned.fill(
              child: _Edge(
                inset: top
                    ? const EdgeInsets.only(top: Resizable.edgeWidth)
                    : widget.left
                    ? const EdgeInsets.only(left: Resizable.edgeWidth)
                    : const EdgeInsets.only(right: Resizable.edgeWidth),
                child: widget.child,
              ),
            ),
            Positioned(
              top: 0,
              bottom: top ? null : 0,
              width: top ? null : Resizable.edgeWidth,
              height: top ? Resizable.edgeWidth : null,
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

/// A side pane's header: a raised bar as high as the chat header
/// ([PaneHeader.height]) with a hairline under it, [child] its row (a side
/// chat's, a subagent's, a command's, a preview's), [inset] from the left and
/// [end] from the right: by default the gutters, or what the row has always
/// had in a pane too narrow for them. [plain] leaves it unraised: a view's
/// header, at the window's top; with the sidebar hidden such a header runs
/// under the traffic lights, so its row starts past them and past the button
/// that shows the sidebar. Empty space in it moves the window, and its
/// hairline runs on from the sidebar's (ADR 0080). A plain header's [lead],
/// before [child] and taking the room it leaves, moves with the sidebar's
/// edge as the sidebar slides ([SidebarFollow]); [child] stays put.
class PaneHeader extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.inset,
    this.end,
    this.plain = false,
    this.lead,
  });

  /// The chat header's height too (ADR 0072).
  static const height = 44.0;

  /// Below this a pane's header keeps its row's room over the gutters: a side
  /// chat's title and buttons take most of the narrowest pane.
  static const gutterFrom = 320.0;

  final Widget child;
  final double? inset;
  final double? end;
  final bool plain;
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return ListenableBuilder(
      listenable: sidebarHidden,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth >= gutterFrom;
          final shut = plain && sidebarShut;
          return SizedBox(
            height: height,
            child: WindowDrag(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  color: plain ? null : t.raised,
                  border: Border(bottom: BorderSide(color: t.borderSubtle)),
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: shut
                        ? hiddenHeaderStart
                        : inset ?? (room ? NushiTheme.gutter : 14),
                    right: end ?? (room ? NushiTheme.gutter : 4),
                    bottom: 1, // the border's
                  ),
                  child: switch (lead) {
                    final lead? => Row(
                      children: [
                        Expanded(
                          child: SidebarFollow(
                            shut: shut,
                            clip: true,
                            child: lead,
                          ),
                        ),
                        child,
                      ],
                    ),
                    null => child,
                  },
                ),
                if (shut) const ShowSidebarButton(),
              ],
            ),
          );
        },
      ),
    );
  }
}
