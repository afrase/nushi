import 'dart:async';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';

/// A diff's view ([child], a `UnifiedDiff` or a `SideBySideDiff` of
/// [controller]) whose presses on its lines are its own: a press of the
/// mouse there selects its text or its lines, and no gesture around it
/// takes it as well (the transcript's selection area would start a
/// selection of its own and take the keys, so ⌘C copied nothing). A
/// press on an inlay (a comment box's field) or on the divider between
/// the panes is left to what's there. A right-click on its lines opens
/// the app's menu with Copy, as a file's source has one (`SourceMenu`).
/// The menu is anchored beside the view, not around it, so a menu in an
/// inlay (the sent comments' list) is no submenu of it and closes on a
/// click in the code.
class DiffPresses extends StatefulWidget {
  const new({
    required this.controller,
    required this.unified,
    required this.theme,
    required this.child,
    super.key,
  });

  final DiffViewController controller;

  /// Whether [child] is the unified view (else side by side).
  final bool unified;

  /// The diff's theme: the side-by-side view's divider width.
  final DiffThemeData theme;

  final Widget child;

  @override
  State<DiffPresses> createState() => _DiffPressesState();
}

class _DiffPressesState extends State<DiffPresses> {
  final _menu = MenuController();
  final GlobalKey _anchor = GlobalKey();
  OpenMenu? _open;
  bool _canCopy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.selectionChanges.addListener(_selectionChanged);
  }

  @override
  void didUpdateWidget(DiffPresses old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.selectionChanges.removeListener(_selectionChanged);
      widget.controller.selectionChanges.addListener(_selectionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.selectionChanges.removeListener(_selectionChanged);
    super.dispose();
  }

  /// The menu is of the selection it opened on: Escape or a new one
  /// closes it.
  void _selectionChanged() {
    if (_menu.isOpen) _menu.close();
  }

  bool get _selected {
    final c = widget.controller;
    return c.textSelection.value != null ||
        c.selection.value != null ||
        c.unifiedSelection.value != null;
  }

  /// Whether [at], on the screen, is on a pane's lines: not on the
  /// divider, not on an inlay.
  bool _claims(Offset at) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(at);
    final width = box.size.width;
    final c = widget.controller;
    var side = PaneSide.neu;
    if (!widget.unified) {
      // Two equal panes either side of the divider (`SideBySideDiff`).
      final pane = (width - widget.theme.dividerWidth) / 2;
      if (local.dx < pane) {
        side = PaneSide.old;
      } else if (local.dx < width - pane) {
        return false;
      }
    }
    final g = widget.unified ? c.unifiedGeometry : c.geometry(side);
    final s = widget.unified ? c.unifiedScroll : c.scroll(side);
    if (!s.hasClients) return false;
    final hit = g.index.hit(s.position.pixels + local.dy);
    return hit.dy >= g.shownInlayHeight(hit.slot);
  }

  void _rightPressed(Offset _) => setState(() => _canCopy = _selected);

  void _rightReleased(Offset at) {
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    _open?.call(box.globalToLocal(at));
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent ||
        e.logicalKey != LogicalKeyboardKey.escape ||
        !_menu.isOpen) {
      return KeyEventResult.ignored;
    }
    _menu.close();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _key,
    child: Stack(
      fit: StackFit.expand,
      children: [
        RawGestureDetector(
          behavior: HitTestBehavior.translucent,
          gestures: {
            _Press: GestureRecognizerFactoryWithHandlers<_Press>(
              () => _Press(debugOwner: this),
              (r) => r
                ..claims = _claims
                ..onDown = _rightPressed
                ..onUp = _rightReleased,
            ),
          },
          child: widget.child,
        ),
        // Under no pointer: what it's anchored to is only a place.
        IgnorePointer(
          child: Menu(
            controller: _menu,
            filter: false,
            keepFocus: true,
            entries: [
              MenuEntry(
                'Copy',
                shortcut: cmdLabel(LogicalKeyboardKey.keyC),
                onPick: _canCopy
                    ? () => unawaited(widget.controller.copySelection())
                    : null,
              ),
            ],
            builder: (context, open) {
              _open = open;
              return SizedBox.expand(key: _anchor);
            },
          ),
        ),
      ],
    ),
  );
}

/// A press of the mouse on the diff's lines, taken at once where [claims]
/// says, so no gesture around it (a selection area's tap, drag or
/// right-click) sees it: its main button's, which the diff's panes follow
/// themselves outside the arena, and its right button's, which opens the
/// menu ([onDown] at the press, [onUp] at its release).
class _Press extends OneSequenceGestureRecognizer {
  new({super.debugOwner});

  bool Function(Offset at)? claims;
  ValueChanged<Offset>? onDown;
  ValueChanged<Offset>? onUp;
  bool _right = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      (event.buttons == kPrimaryButton || event.buttons == kSecondaryButton) &&
      (claims?.call(event.position) ?? false) &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    _right = event.buttons == kSecondaryButton;
    if (_right) onDown?.call(event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      if (_right) onUp?.call(event.position);
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'diff press';
}
