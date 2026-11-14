import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/rail_dashes.dart';
import 'package:nushi/rail_menu.dart';

export 'package:nushi/rail_dashes.dart';

// A rail, as Claude's desktop app has them: a dash for each place in a
// long text, down its left margin at its top, the one for where you're
// reading long and bright. The pointer over it, a click, or the keyboard's
// focus opens its menu: each entry by its title, its dash beside it; a pick
// goes there. The pins rail (ADR 0085, message_pins.dart) has a pinned
// message's.

/// One of the rail's entries: what [Rail.onPick] gets, its title, and in an
/// outline how deep it stands (0, 1 or 2).
@immutable
class RailEntry {
  const new(this.id, this.title, {this.depth = 0});

  /// What a pick of it gives [Rail.onPick].
  final String id;

  /// Its level under the outline's top ([Rail.outline]); 0 for the top.
  final int depth;

  /// What the menu lists it by: plain text, at most a line.
  final String title;

  @override
  bool operator ==(Object other) =>
      other is RailEntry &&
      other.id == id &&
      other.title == title &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(id, title, depth);
}

/// The rail: [entries], in the text's order, as dashes, [current]'s long
/// and bright. Its menu lists them; [onPick] goes to the one picked (its
/// id). [before] runs as it opens, the menu showing once it's done
/// (`pinTitlesApi`). [fit] is where the dashes stand from its left edge,
/// which is the text's, and how long they are. An [outline]'s (a Markdown
/// preview's headings) draws the current dash in the accent, each other one
/// by its entry's depth, and its menu lines the titles up, indented by it.
class Rail extends StatefulWidget {
  const new({
    required this.entries,
    required this.current,
    required this.onPick,
    required this.fit,
    required this.label,
    super.key,
    this.before,
    this.outline = false,
  });

  /// What a screen reader calls it ("Pinned messages").
  final String label;
  final List<RailEntry> entries;
  final ValueListenable<int> current;
  final void Function(String id) onPick;
  final RailFit fit;
  final Future<void> Function()? before;
  final bool outline;

  /// How long the menu stays once the pointer has left it and the rail.
  // design: a hover's grace, not motion
  static const linger = Duration(milliseconds: 150);

  @override
  State<Rail> createState() => _RailState();
}

class _RailState extends State<Rail> {
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
    if (_pointed) _leave = Timer(Rail.linger, _close);
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
          builder: (context, look) => RailDashes(
            // The menu over it has them, a little to the right.
            shown: !_menu.isShowing,
            entries: widget.entries,
            outline: widget.outline,
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
              label: widget.label,
              child: CompositedTransformTarget(
                link: _link,
                child: OverlayPortal(
                  controller: _menu,
                  overlayChildBuilder: (context) => CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    offset: const Offset(RailMenu.shift, 0),
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
                          child: RailMenu(
                            entries: widget.entries,
                            current: widget.current,
                            lit: _lit,
                            fit: widget.fit,
                            outline: widget.outline,
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
