import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';

/// A pane beside a view: its [name] (its remembered width's), the width
/// it starts at, and its least and most.
class SidePane {
  new(
    this.name, {
    required this.initial,
    required this.min,
    required this.cap,
    required this.child,
  }) : fixed = false;

  /// A pane of one [width], with no edge to drag: the details panel
  /// (ADR 0092), which shows or hides only.
  new fixed(this.name, {required double width, required this.child})
    : initial = width,
      min = width,
      cap = width,
      fixed = true;

  final String name;
  final double initial;
  final double min;
  final double cap;
  final bool fixed;
  final Widget child;

  double get width =>
      fixed ? initial : paneWidth(name, initial).clamp(min, cap);
}

/// [main] with [panes] beside it, left to right, and [details] at the
/// right, each resizable but a [SidePane.fixed] one, which has a hairline
/// at its left instead of an edge to drag. When [main] would get narrower
/// than [least], the panes lie over it, by the details, rather than beside
/// it: the details stay, and so does [main]'s width under the panes.
///
/// A pane slides its full width in from the right as it opens and out as
/// it closes ([Presence], [paneSlide]); one closing keeps its place until
/// it's gone, taking no pointer or focus, while the rest are laid out at
/// once where they go. [main] is laid out once at its new width and drawn
/// gliding there ([Glide]) from where its text was, [columnSides] saying
/// where that text's column lies in it (the chat's); so do the
/// panes that stay but move (the side chat, as the preview right of it
/// closes), and so does [main] as the sidebar comes and goes.
///
/// The pane named [cover] takes the whole of it, over the rest (an expanded
/// browser tab, ADR 0094): they stay laid out where they were, keeping
/// their state, but draw nothing and take no pointer or focus, so the pane
/// is the same widget throughout and its page doesn't load again.
class Beside extends StatefulWidget {
  const new({
    required this.main,
    required this.least,
    required this.panes,
    super.key,
    this.details,
    this.columnSides,
    this.cover,
  });

  final Widget main;
  final double least;
  final List<SidePane> panes;
  final SidePane? details;
  final EdgeInsets Function(double width)? columnSides;
  final String? cover;

  @override
  State<Beside> createState() => _BesideState();
}

class _BesideState extends State<Beside> {
  /// Every pane it has shown, so one closing keeps its place in the
  /// children (and its state) as it goes; a gone one is nothing.
  final _seen = <String>{};

  /// What showed in the last build.
  var _shown = <String>{};

  /// Whether it was built before: what it shows at first doesn't slide.
  bool _built = false;

  /// Each pane's x as last laid out: where one closing stays.
  final _at = <String, double>{};

  /// Each pane's width as last laid out beside [Beside.main]: what one
  /// over all ([Beside.cover]) leaves the rest.
  final _widths = <String, double>{};

  /// Each pane's [Glide] token, changed only while it stays shown: a pane
  /// coming in slides, it doesn't glide.
  final _tokens = <String, Object>{};

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ValueListenableBuilder(
      valueListenable: paneWidths,
      builder: (context, _, _) {
        final room = box.maxWidth;
        final details = widget.details;
        final panes = widget.panes;
        final detailsWidth = details?.width ?? 0;
        final panesWidth = panes.fold(0.0, (w, p) => w + p.width);
        final over = room - detailsWidth - panesWidth < widget.least;
        final t = NushiTheme.of(context).t;
        final shown = [...panes, ?details];
        final now = {for (final p in shown) p.name};
        // What glides: the panes open, and the sidebar, which moves
        // everything here sideways.
        final token = [for (final p in shown) p.name, sidebarShut].join(',');
        for (final slot in now) {
          if (_shown.contains(slot)) _tokens[slot] = token;
          _tokens.putIfAbsent(slot, () => token);
        }
        final built = _built;
        _built = true;
        _seen.addAll(now);
        _shown = now;
        final cover = now.contains(widget.cover) ? widget.cover : null;
        // Under the pane over all: kept, but not drawn or reached.
        Widget under(String slot, Widget child) => ExcludeFocus(
          excluding: cover != null && slot != cover,
          child: Offstage(
            offstage: cover != null && slot != cover,
            child: child,
          ),
        );
        Widget resizable(SidePane p, double most) => p.fixed
            ? SizedBox(
                key: ValueKey(p.name),
                width: p.width,
                // Over the pane, whose own fill would hide it.
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: t.line)),
                  ),
                  child: p.child,
                ),
              )
            : Resizable(
                key: ValueKey(p.name),
                name: p.name,
                initial: p.initial,
                min: p.min,
                max: min(p.cap, most),
                left: true,
                locked: p.name == cover,
                child: p.child,
              );
        Widget pane(String slot, Widget? child) => LayoutId(
          key: ValueKey(slot),
          id: slot,
          child: under(
            slot,
            Glide(
              token: _tokens[slot],
              child: Presence(
                // What showed as the view came is there; what opens after
                // slides in.
                arrives: built,
                child: child,
                builder: (_, run, c) => paneSlide(run, c),
              ),
            ),
          ),
        );
        Widget backed(Widget child, {required bool shadow}) => DecoratedBox(
          decoration: BoxDecoration(
            color: t.base,
            boxShadow: [
              if (shadow)
                BoxShadow(
                  color: const Color(0xFF000000).withValues(
                    alpha: t.brightness == Brightness.dark ? 0.4 : 0.12,
                  ),
                  blurRadius: 12,
                ),
            ],
          ),
          child: child,
        );
        final children = [
          LayoutId(
            key: const ValueKey(_Slot.main),
            id: _Slot.main,
            child: under(
              '',
              Glide(
                token: token,
                sides: widget.columnSides,
                // Its foot is its full width: cut at its left as it
                // glides, it doesn't lie over the sidebar.
                clip: true,
                child: widget.main,
              ),
            ),
          ),
          // Those closing: over the main view, under the rest.
          for (final s in _seen)
            if (!now.contains(s)) pane(s, null),
          // Beside, a pane leaves [main] its least width; over it, a
          // strip of it. One with no cap can be dragged on over it. Over
          // it, the first one's shadow falls on it.
          for (final (i, p) in panes.indexed)
            pane(
              p.name,
              backed(
                resizable(
                  p,
                  room -
                      detailsWidth -
                      (panesWidth - p.width) -
                      (over || p.cap.isInfinite ? 48 : widget.least),
                ),
                shadow: over && i == 0,
              ),
            ),
          if (details != null)
            pane(
              details.name,
              resizable(details, room - (over ? 0 : panesWidth) - widget.least),
            ),
        ];
        // The pane over all is drawn last; keyed, it keeps its state as it
        // moves in the list.
        if (cover != null) {
          final top = children.indexWhere(
            (c) => c.key == ValueKey<String>(cover),
          );
          children.add(children.removeAt(top));
        }
        return CustomMultiChildLayout(
          delegate: _Beside(
            widget.least,
            panes: [for (final p in panes) p.name],
            details: details?.name,
            going: [
              for (final s in _seen)
                if (!now.contains(s)) s,
            ],
            at: _at,
            widths: _widths,
            cover: cover,
          ),
          children: children,
        );
      },
    ),
  );
}

enum _Slot { main }

/// Lays the details at the right, the panes left of them, and the main
/// view in what's left; when that would be under [least], it runs under
/// the panes instead. Those [going] stay where they were ([at], which it
/// keeps up to date). Measured as laid out, so a pane being resized moves
/// the rest with it.
class _Beside extends MultiChildLayoutDelegate {
  new(
    this.least, {
    required this.panes,
    required this.details,
    required this.going,
    required this.at,
    required this.widths,
    this.cover,
  });

  final double least;
  final List<String> panes; // left to right
  final String? details;
  final List<String> going;
  final Map<String, double> at;
  final Map<String, double> widths; // each pane's, as last laid out beside
  final String? cover; // the pane over all, the whole of it

  @override
  void performLayout(Size size) {
    final tall = BoxConstraints(
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
    );
    var right = size.width;
    if (details case final d?) {
      right -= layoutChild(d, tall).width;
      positionChild(d, Offset(at[d] = right, 0));
    }
    var x = right;
    for (final p in panes.reversed) {
      if (p == cover) {
        // It fills it all; the rest keep the room they had beside it, so
        // nothing under it is laid out anew.
        layoutChild(p, BoxConstraints.tight(size));
        positionChild(p, Offset.zero);
        x -= widths[p] ?? 0;
        continue;
      }
      x -= widths[p] = layoutChild(p, tall).width;
      positionChild(p, Offset(at[p] = x, 0));
    }
    final main = x >= least ? x : right;
    for (final g in going) {
      layoutChild(g, tall);
      positionChild(g, Offset(at[g] ?? size.width, 0));
    }
    layoutChild(
      _Slot.main,
      BoxConstraints.tightFor(width: max(0, main), height: size.height),
    );
    positionChild(_Slot.main, Offset.zero);
  }

  @override
  bool shouldRelayout(_Beside old) => true; // cheap: a few panes
}
