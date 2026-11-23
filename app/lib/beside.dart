import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/beside_fit.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';
import 'package:nushi/top_notices.dart';

part 'beside_layout.dart';

/// A chat's room, left to right (ADR 0123): [main], the [details] rail
/// while it's wanted (a [SidePane.fixed], a hairline at its left), and
/// [panes], each resizable; [head] over [main] and the rail,
/// [PaneHeader.height] high, and [foot] under them (the chat's header and
/// its terminal). The panes run its full height, their own top rows level
/// with [head], whether beside [main] or over it.
///
/// How the room is shared is [besideFit]'s: when [main] would keep less
/// than [railLeast] beside the rail, the rail tucks itself away (kept,
/// not drawn; never saved, as it's still wanted); when [main] would keep
/// less than [least] beside the panes alone, they narrow, the widest
/// first, never saved; and once each is at its least, they lie over it.
/// Then [main], [head] and [foot] keep [least] and lie under the panes,
/// which cover their right: nothing changes place at that line. A pane's
/// edge, dragged while the panes are beside [main], stops where [main]
/// keeps [least]; the rail tucks and comes back as the edge moves.
///
/// A pane slides its full width in from the right as it opens and out as
/// it closes ([Presence], [paneSlide]), and so does the rail as it's shown,
/// hidden, tucked or brought back; one going keeps its place until it's
/// gone, taking no pointer or focus, while the rest are laid out at once
/// where they go. [main] is laid out once at its new width and drawn
/// gliding there ([Glide]) from where its text was, [columnSides] saying
/// where that text's column lies in it (the chat's); so do the panes that
/// stay but move, and [head]'s trailing buttons ([Beside.glideOf]). The
/// rail tucked with the focus in it gives the focus to [keep].
///
/// A new [scene] (another of the chat's tabs) is a new set of [main], its
/// panes and details: they're there at once, with no slide, while [head]
/// and [foot] stay the same widgets (a terminal keeps its shell).
///
/// The pane named [cover] takes the whole of it, over the rest, [head] and
/// [foot] too (an expanded browser tab, ADR 0094): they stay laid out where
/// they were, keeping their state, but draw nothing and take no pointer or
/// focus, so the pane is the same widget throughout and its page doesn't
/// load again.
///
/// With it, [notices]: the bars in a row of their own (ADR 0128, amended
/// 2026-11-17) under [head], as wide as it while the panes are beside
/// [main], pushing [main] and the rail down; across it all while the panes
/// lie over [main], which go down under them; and across the top while a
/// pane covers it all, which goes down by their height; the
/// toasts over [main], under the bars, what the rail and the panes leave
/// of it, and the newer release's card in its bottom right corner, over
/// whatever is there ([NoticesPlace], amended 2026-11-19), above the bars
/// at the foot of [main] and of the panes that it would otherwise cover
/// ([UnderCard], [CardLift]).
class Beside extends StatefulWidget {
  const new({
    required this.main,
    required this.least,
    required this.panes,
    super.key,
    this.head,
    this.foot,
    this.details,
    double? railLeast,
    this.columnSides,
    this.cover,
    this.scene,
    this.keep,
    this.notices,
  }) : railLeast = railLeast ?? least;

  final Widget main;
  final Widget? head;
  final Widget? foot;
  final double least;
  final double railLeast;
  final List<SidePane> panes;
  final SidePane? details;
  final EdgeInsets Function(double width)? columnSides;
  final String? cover;
  final Object? scene;
  final FocusNode? keep;
  final ({Widget bars, Widget card})? notices;

  /// What [head]'s trailing part glides by: it changes as the panes beside
  /// it come and go (and the rail and the sidebar), so a [Glide] given it
  /// slides with them; null outside a [Beside].
  static Object? glideOf(BuildContext context) => _scope(context)?.glide;

  /// The [Beside.scene] [head] is in: a [Glide] given it jumps when it
  /// changes, as the rest do.
  static Object? sceneOf(BuildContext context) => _scope(context)?.scene;

  /// Whether the rail is wanted but tucked away for the panes' room.
  static bool railHeldOf(BuildContext context) =>
      _scope(context)?.held ?? false;

  static _BesideScope? _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BesideScope>();

  @override
  State<Beside> createState() => _BesideState();
}

class _BesideState extends State<Beside> {
  /// Every pane it has shown, so one closing keeps its place in the
  /// children (and its state) as it goes; a gone one is nothing. The
  /// rail's name is in it once it was wanted.
  final _seen = <String>{};

  /// What showed in the last build.
  var _shown = <String>{};

  /// Whether it was built before: what it shows at first doesn't slide.
  bool _built = false;

  /// Each pane's rect, and the rail's, as last laid out: where one going
  /// stays, laid out as it was.
  final _at = <String, Rect>{};

  /// Each pane's width as last laid out beside [Beside.main]: what one
  /// over all ([Beside.cover]) leaves the rest.
  final _widths = <String, double>{};

  /// Each pane's [Glide] token, changed only while it stays shown: a pane
  /// coming in slides, it doesn't glide.
  final _tokens = <String, Object>{};

  /// The widths of the panes being dragged, as their edges say: only open
  /// ones not over all. A pane closed, or covering it all, mid-drag never
  /// says its drag ended (its edge is gone), so what it said last would
  /// otherwise stay and decide for it when it's back at its saved width.
  final _live = <String, double>{};

  /// Whether [name] is a pane whose drag decides: open, and not over all.
  bool _drags(String name) =>
      name != widget.cover && widget.panes.any((p) => p.name == name);

  /// The room as last laid out, whether the rail showed in it, and the
  /// panes' widths ([besideFit]'s) in it.
  double _room = 0;
  bool _rail = false;
  Map<String, double> _fitted = const {};

  /// Holds the focus while it's in the rail.
  final _railFocus = FocusNode(skipTraversal: true, canRequestFocus: false);

  /// The bars at the foot of [Beside.main] and of the panes that the newer
  /// release's card stands above ([CardLift]).
  final _floor = CardFloor();

  @override
  void didUpdateWidget(Beside old) {
    super.didUpdateWidget(old);
    if (widget.scene == old.scene) return;
    // Another scene: what it shows is there at once, as at the first build.
    _seen.clear();
    _shown = {};
    _tokens.clear();
    _at.clear();
    _widths.clear();
    _live.clear();
    _built = false;
  }

  @override
  void dispose() {
    _railFocus.dispose();
    _floor.dispose();
    super.dispose();
  }

  BesideFit _fit(double room) => besideFit(
    room: room,
    panes: widget.panes,
    saved: paneWidths.value,
    live: _live,
    wantRail: widget.details != null,
    least: widget.least,
    railLeast: widget.railLeast,
    rail: widget.details?.width ?? 0,
  );

  /// A pane's edge is dragged to [width] (null: let go): the rail shows or
  /// tucks as the room it leaves says, and the rest, narrowed for the
  /// transcript, take back what it gives (ADR 0123); otherwise nothing is
  /// built again.
  void _dragged(String name, double? width) {
    if (width == null || !_drags(name)) {
      _live.remove(name);
    } else {
      _live[name] = width;
    }
    if (!mounted) return;
    final fit = _fit(_room);
    final moved = fit.widths.entries.any(
      (e) => e.key != name && e.value != _fitted[e.key],
    );
    if (fit.rail != _rail || moved) setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ValueListenableBuilder(
      valueListenable: paneWidths,
      builder: (context, _, _) {
        final room = _room = box.maxWidth;
        _live.removeWhere((name, _) => !_drags(name));
        final fit = _fit(room);
        _fitted = fit.widths;
        final scene = widget.scene;
        final details = widget.details;
        final panes = widget.panes;
        final over = fit.over;
        final rail = fit.rail;
        // The rail going with the focus in it: the keys stay with [keep].
        if (_rail && !rail && _railFocus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.keep?.requestFocus();
          });
        }
        _rail = rail;
        final t = NushiTheme.of(context).t;
        final now = {for (final p in panes) p.name, if (rail) ?details?.name};
        // What glides: what's open beside [main] and the sidebar, which
        // moves everything sideways. The panes lying over [main] moves
        // nothing: the layout is the same either side of that line.
        final token = [...now, sidebarShut].join(',');
        // The rail has its token from the first build it's in, tucked or
        // not: coming back, it slides in, never gliding from where it was
        // laid out tucked.
        if (details != null) _tokens.putIfAbsent(details.name, () => token);
        for (final slot in now) {
          if (_shown.contains(slot)) _tokens[slot] = token;
          _tokens.putIfAbsent(slot, () => token);
        }
        final built = _built;
        _built = true;
        _seen.addAll(now);
        if (details != null) _seen.add(details.name);
        _shown = now;
        final cover = panes.any((p) => p.name == widget.cover)
            ? widget.cover
            : null;
        // Under the pane over all: kept, but not drawn or reached, and its
        // tickers and loops still.
        Widget under(Object slot, Widget child) => ExcludeFocus(
          excluding: cover != null && slot != cover,
          child: Offstage(
            offstage: cover != null && slot != cover,
            child: TickerMode(
              enabled: cover == null || slot == cover,
              child: child,
            ),
          ),
        );
        Widget slide(String slot, Widget? child, {bool shown = true}) => under(
          slot,
          FocusTraversalGroup(
            child: Glide(
              token: _tokens[slot],
              child: Presence(
                // What showed as the view came is there; what opens
                // after slides in.
                arrives: built,
                shown: shown,
                child: child,
                builder: (_, run, c) => paneSlide(run, c),
              ),
            ),
          ),
        );
        // Tab goes the header, [main], the rail, the panes left to right,
        // then [foot] (a terminal keeps Tab for its shell), whatever their
        // places: beside [main] the panes run its full height and the
        // terminal only its width, and reading order would put the
        // terminal before the rail.
        final order = {for (final (i, p) in panes.indexed) p.name: 3.0 + i};
        final last = 3.0 + panes.length;
        Widget ordered(double at, Widget child) =>
            FocusTraversalOrder(order: NumericFocusOrder(at), child: child);
        Widget pane(String slot, Widget? child) => LayoutId(
          key: ValueKey((scene, slot)),
          id: slot,
          child: ordered(order[slot] ?? last, slide(slot, child)),
        );
        Widget backed(Widget child, {required bool shadow}) => DecoratedBox(
          decoration: BoxDecoration(
            color: t.base,
            boxShadow: [
              if (shadow)
                BoxShadow(
                  color: t.shadow.withValues(
                    alpha: t.brightness == Brightness.dark ? 0.4 : 0.12,
                  ),
                  blurRadius: 12,
                ),
            ],
          ),
          child: child,
        );
        // Over [main] a pane is never narrower than its least; in a room
        // narrower than theirs, they narrow to fit ([squeeze]): each to the
        // least its rows hold, then all alike, the first never past its
        // left edge nor, with the sidebar hidden, under the title buttons
        // (ADR 0118), which would lie over its top row.
        final fits = max(0.0, room - (sidebarShut ? hiddenHeaderStart : 0));
        final squeezed = over
            ? squeeze(fit.widths, panes, fits)
            : const <String, double>{};
        final railName = details?.name ?? _BesideState._railName;
        // Over all, the card too: it's the window's, in its corner.
        final notices = [
          if (widget.notices case (:final bars, :final card))
            ...TopNotices.slots(
              bars: bars,
              card: CardLift(floor: _floor, child: card),
            ),
        ];
        final children = [
          // First in the tree, as they were above and below the rest: they
          // never lie over what's after them.
          if (widget.head case final head?)
            LayoutId(
              key: const ValueKey(_Slot.head),
              id: _Slot.head,
              child: ordered(
                0,
                under(
                  _Slot.head,
                  FocusTraversalGroup(
                    child: _BesideScope(
                      glide: token,
                      scene: scene,
                      held: details != null && !rail,
                      child: head,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.foot case final foot?)
            LayoutId(
              key: const ValueKey(_Slot.foot),
              id: _Slot.foot,
              child: ordered(
                last,
                under(_Slot.foot, FocusTraversalGroup(child: foot)),
              ),
            ),
          LayoutId(
            key: ValueKey((scene, _Slot.main)),
            id: _Slot.main,
            child: ordered(
              1,
              under(
                _Slot.main,
                FocusTraversalGroup(
                  child: Glide(
                    token: token,
                    sides: widget.columnSides,
                    // Its foot is its full width: cut at its left as it
                    // glides, it doesn't lie over the sidebar.
                    clip: true,
                    child: CardFloors(floor: _floor, child: widget.main),
                  ),
                ),
              ),
            ),
          ),
          // The rail: kept while it's tucked away for room, gone only once
          // it's not wanted. Under the panes, which it slides out under.
          if (_seen.contains(railName))
            LayoutId(
              key: ValueKey((scene, railName)),
              id: railName,
              child: ordered(
                2,
                Focus(
                  focusNode: _railFocus,
                  child: slide(
                    railName,
                    shown: rail,
                    details == null
                        ? null
                        : SizedBox(
                            key: ValueKey(details.name),
                            width: details.width,
                            // Over the rail, whose own fill would hide it.
                            child: DecoratedBox(
                              position: DecorationPosition.foreground,
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: t.line)),
                              ),
                              child: details.child,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          // Those closing: over the main view and the rail, under the rest.
          for (final s in _seen)
            if (!now.contains(s) && s != railName) pane(s, null),
          // Beside, a pane's edge stops where [main] keeps its least; over
          // it, at the pane's own least. Over it, the first one's shadow
          // falls on it.
          for (final (i, p) in panes.indexed)
            pane(
              p.name,
              backed(
                Resizable(
                  key: ValueKey(p.name),
                  name: p.name,
                  initial: p.initial,
                  min: p.min,
                  max: fit.most[p.name]!,
                  left: true,
                  locked: p.name == cover,
                  onDrag: (w) => _dragged(p.name, w),
                  child: CardFloors(floor: _floor, pane: true, child: p.child),
                ),
                shadow: over && i == 0,
              ),
            ),
        ];
        // The pane over all is drawn last; keyed, it keeps its state as it
        // moves in the list.
        if (cover != null) {
          final top = children.indexWhere(
            (c) => c.key == ValueKey((scene, cover)),
          );
          children.add(children.removeAt(top));
        }
        children.addAll(notices);
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: CustomMultiChildLayout(
            delegate: _Beside(
              panes: [for (final p in panes) p.name],
              rail: _seen.contains(railName) ? railName : null,
              railShown: rail,
              railWidth: details?.width ?? 0,
              block: over ? fit.left : null,
              squeezed: squeezed,
              going: [
                for (final s in _seen)
                  if (!now.contains(s) && s != railName) s,
              ],
              at: _at,
              widths: _widths,
              cover: cover,
              floor: _floor,
              // Across the top with the sidebar hidden, past the lights
              // and the title buttons, which stay at the window's top.
              barsStart: sidebarShut
                  ? max(0, hiddenHeaderStart - TopBar.side)
                  : 0,
            ),
            children: children,
          ),
        );
      },
    ),
  );

  /// The rail's slot while no rail is wanted: its last name.
  static const _railName = 'details';
}
