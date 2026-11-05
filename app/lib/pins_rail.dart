import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/pins_menu.dart';
import 'package:nushi/theme/theme.dart';

// The pins' rail (ADR 0085), as Claude's desktop app has it: a dash for the
// session's start and one for each pinned message, down the transcript's
// left margin at its top, the one for where you're reading long and bright.
// The pointer over it, a click, or the keyboard's focus opens its menu:
// each entry by its title, its dash beside it; a pick goes there.

/// One of the rail's entries: a pinned message's item and title; the
/// session's start is [PinEntry.start].
@immutable
class PinEntry {
  const new(this.id, this.title);

  /// The session's start, the rail's first entry.
  static const start = PinEntry('', 'Session start');

  /// The pinned message's item; '' for the start.
  final String id;

  /// What the menu lists it by: plain text, at most a line.
  final String title;

  @override
  bool operator ==(Object other) =>
      other is PinEntry && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// The room between the dashes, and their thickness.
const _pitch = 8.0;
const _thick = 2.0;

/// Where the rail's dashes stand and how long they are, given the room
/// beside the transcript's text ([margin], its left inset): as Claude's
/// (15 from the edge, 14 and 9 long), unless the margin is too narrow for
/// that and a gap of [gap] to the words; then nearer the edge, and if need
/// be shorter (the phone's, a narrow window's). A long dash nearer the
/// words reads as a dash opening the line beside it.
@immutable
class RailFit {
  const new _(this.margin, this.inset, this.long, this.short);

  factory of(double margin) {
    final inset = (margin - 14 - gap).clamp(3, 15).toDouble();
    final long = (margin - inset - gap).clamp(6, 14).toDouble();
    return RailFit._(margin, inset, long, (long * 9 / 14).roundToDouble());
  }

  /// As in a wide window: room enough.
  static const wide = RailFit._(40, 15, 14, 9);

  /// The room between a long dash and the words.
  static const gap = 8.0;

  final double margin;

  /// How far right of the transcript's left edge the dashes stand.
  final double inset;

  /// The current entry's dash, and the others'.
  final double long;
  final double short;

  /// An entry's dash, the current one's if [on].
  double dash({required bool on}) => on ? long : short;

  @override
  bool operator ==(Object other) =>
      other is RailFit &&
      other.margin == margin &&
      other.inset == inset &&
      other.long == long;

  @override
  int get hashCode => Object.hash(margin, inset, long);
}

/// The first daemon that sends each pin's title with its chat
/// (`Chat.message_pins`). Against an older one the phone takes the pages
/// its pins are on before the rail's menu opens, to list them by their
/// first lines; against this one the menu opens at once, and a pick takes
/// the page it goes to.
const pinTitlesApi = 104;

/// The rail: [entries] (the start first, then the pins in the transcript's
/// order) as dashes, [current]'s long and bright. Its menu lists them;
/// [onPick] goes to the one picked (its id, '' for the start). [before]
/// runs as it opens, the menu showing once it's done ([pinTitlesApi]). [fit] is
/// where the dashes stand from its left edge, which is the transcript's,
/// and how long they are.
class PinsRail extends StatefulWidget {
  const new({
    required this.entries,
    required this.current,
    required this.onPick,
    required this.fit,
    super.key,
    this.before,
  });

  final List<PinEntry> entries;
  final ValueListenable<int> current;
  final void Function(String id) onPick;
  final RailFit fit;
  final Future<void> Function()? before;

  /// How long the menu stays once the pointer has left it and the rail.
  static const linger = Duration(milliseconds: 150);

  @override
  State<PinsRail> createState() => _PinsRailState();
}

class _PinsRailState extends State<PinsRail> {
  final _menu = OverlayPortalController();
  final _link = LayerLink();
  final _region = Object();

  /// The row Enter picks and the menu fills: the keys' or the pointer's;
  /// null for none.
  final _lit = ValueNotifier<int?>(null);
  bool _overRail = false;
  bool _overMenu = false;

  /// The pointer came over the rail or the menu since it opened: its
  /// leaving both then closes it.
  bool _pointed = false;
  Timer? _leave;

  /// The press on the rail that's coming is a pointer's (a click, a tap),
  /// not Enter's or Space's.
  bool _pressed = false;

  /// Where the pointer is over the menu, and whether a pick made with it
  /// over the rail (the menu's first rows are) leaves the menu closed until
  /// the pointer has left the rail: closing it puts the pointer over the
  /// rail, without its moving, which would open it again at once.
  Offset? _menuPointer;
  bool _quiet = false;

  @override
  void dispose() {
    _leave?.cancel();
    _lit.dispose();
    super.dispose();
  }

  Future<void> _open({bool keys = false}) async {
    if (_menu.isShowing) return;
    await widget.before?.call();
    if (!mounted || _menu.isShowing) return;
    _lit.value = keys ? widget.current.value : null;
    _pointed = _overRail || _overMenu;
    setState(_menu.show);
  }

  void _close() {
    _leave?.cancel();
    if (!_menu.isShowing) return;
    setState(_menu.hide);
  }

  void _pick(int i) {
    final box = context.findRenderObject();
    if (_menuPointer case final at? when box is RenderBox && box.hasSize) {
      _quiet = (Offset.zero & box.size).contains(box.globalToLocal(at));
    }
    _close();
    if (i < widget.entries.length) widget.onPick(widget.entries[i].id);
  }

  /// A click or a tap on the rail opens or closes its menu; Enter or Space
  /// opens it, or picks the row the keys are on.
  void _tap() {
    final pointer = _pressed;
    _pressed = false;
    if (!_menu.isShowing) {
      unawaited(_open(keys: !pointer));
    } else if (pointer) {
      _close();
    } else {
      _pick(_lit.value ?? widget.current.value);
    }
  }

  void _pointer({bool? rail, bool? menu}) {
    _overRail = rail ?? _overRail;
    _overMenu = menu ?? _overMenu;
    _leave?.cancel();
    if (_overRail || _overMenu) {
      _pointed = true;
      if ((rail ?? false) && !_quiet) unawaited(_open());
      return;
    }
    if (_pointed) _leave = Timer(PinsRail.linger, _close);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final n = widget.entries.length;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowUp:
        if (!_menu.isShowing) {
          unawaited(_open(keys: true));
          return KeyEventResult.handled;
        }
        final step = e.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _lit.value = ((_lit.value ?? widget.current.value) + step) % n;
      case LogicalKeyboardKey.escape when _menu.isShowing:
        _close();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The room under the rail's top, to the window's bottom.
  double _room(BuildContext context) {
    final box = this.context.findRenderObject();
    final top = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero).dy
        : 0.0;
    return MediaQuery.sizeOf(context).height - top - 8;
  }

  @override
  Widget build(BuildContext context) {
    final phone = TouchTargets.of(context);
    final rail = ValueListenableBuilder(
      valueListenable: widget.current,
      builder: (context, current, _) => Listener(
        onPointerDown: (_) => _pressed = true,
        child: Pressable(
          onTap: _tap,
          builder: (context, look) => _Dashes(
            // The menu over it has them, a little to the right.
            shown: !_menu.isShowing,
            count: widget.entries.length,
            current: current,
            fit: widget.fit,
            look: look,
            // On the phone a finger's width, past the margin into the text's
            // edge, where nothing's drawn: the dashes stay in the margin.
            padding: EdgeInsets.fromLTRB(
              widget.fit.inset,
              10,
              phone
                  ? TouchTargets.size - widget.fit.inset - widget.fit.long
                  : RailFit.gap,
              10,
            ),
          ),
        ),
      ),
    );
    // Only its top reaches past the margin (the phone's finger-wide
    // target): below, the text's edge under it takes touches and drags.
    return _RailHit(
      reach: widget.fit.margin,
      child: TapRegion(
        groupId: _region,
        onTapOutside: (_) => _close(),
        child: MouseRegion(
          onEnter: (_) => _pointer(rail: true),
          onExit: (_) {
            _quiet = false;
            _pointer(rail: false);
          },
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _key,
            onFocusChange: (focus) {
              if (!focus) {
                _close();
              } else if (FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional) {
                unawaited(_open(keys: true)); // focused from the keyboard
              }
            },
            child: Semantics(
              button: true,
              label: 'Pinned messages',
              child: CompositedTransformTarget(
                link: _link,
                child: OverlayPortal(
                  controller: _menu,
                  overlayChildBuilder: (context) => CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    offset: const Offset(PinsMenu.shift, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: TapRegion(
                        groupId: _region,
                        child: MouseRegion(
                          onEnter: (e) {
                            _menuPointer = e.position;
                            _pointer(menu: true);
                          },
                          onHover: (e) => _menuPointer = e.position,
                          onExit: (_) {
                            _menuPointer = null;
                            _pointer(menu: false);
                          },
                          child: PinsMenu(
                            entries: widget.entries,
                            current: widget.current,
                            lit: _lit,
                            fit: widget.fit,
                            room: _room(context),
                            onPick: _pick,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: rail,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [child], hit only within [reach] of its left edge, but for its top
/// [TouchTargets.size], hit across.
class _RailHit extends SingleChildRenderObjectWidget {
  const new({required this.reach, required super.child});

  final double reach;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRailHit(reach);

  @override
  void updateRenderObject(BuildContext context, _RenderRailHit renderObject) =>
      renderObject.reach = reach;
}

class _RenderRailHit extends RenderProxyBox {
  new(this.reach);

  double reach;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      (position.dx <= reach || position.dy <= TouchTargets.size) &&
      super.hitTest(result, position: position);
}

/// The most dashes the rail draws: with more pins, those around the
/// current one, so it stays short (the menu lists them all).
const railMost = 12;

/// The rail's dashes, [current]'s long and bright; at most [railMost].
class _Dashes extends StatelessWidget {
  const new({
    required this.shown,
    required this.count,
    required this.current,
    required this.fit,
    required this.look,
    required this.padding,
  });

  final bool shown;
  final int count;
  final int current;
  final RailFit fit;
  final ControlLook look;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final from = (current - railMost ~/ 2).clamp(0, max(0, count - railMost));
    return Container(
      padding: padding,
      foregroundDecoration: focusRing(t, look),
      child: Opacity(
        opacity: shown ? 1 : 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _pitch - _thick,
          children: [
            for (var i = from; i < min(count, from + railMost); i++)
              PinDash(on: i == current, fit: fit),
          ],
        ),
      ),
    );
  }
}

/// One entry's dash: long and bright for the current one ([on]), short and
/// dim otherwise; between the two if [bright] (its row under the pointer or
/// the keys), as Claude's hovered row has it.
class PinDash extends StatelessWidget {
  const new({
    required this.on,
    super.key,
    this.fit = RailFit.wide,
    this.bright = false,
  });

  final bool on;
  final RailFit fit;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return AnimatedContainer(
      duration: reduceMotion(context) ? Duration.zero : Motion.quick,
      width: fit.dash(on: on),
      height: _thick,
      decoration: BoxDecoration(
        color: on
            ? t.text
            : bright
            ? Color.lerp(t.borderStrong, t.text, 0.5)
            : t.borderStrong,
        borderRadius: BorderRadius.circular(_thick / 2),
      ),
    );
  }
}
