import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Shows [card] floating under [child] after the pointer has been on it
/// for 400 ms ([onShow] runs then), held while the pointer is on either.
/// With [showOnTap] a click on [child] shows it at once, and it stays
/// until a second click, or one elsewhere. With [above], it opens over
/// [child] instead when the window has less than that much room under it.
/// With [around], it keeps clear of that box (global, [child]'s own
/// lines and those it speaks of) instead of [child]'s alone. It never
/// runs past the window's right edge: it narrows to the room there, down
/// to [minWidth], and moves left past that.
class HoverCard extends StatefulWidget {
  const new({
    required this.child,
    required this.card,
    super.key,
    this.onShow,
    this.showOnTap = false,
    this.above,
    this.around,
  });

  final Widget child;
  final WidgetBuilder card;
  final VoidCallback? onShow;
  final bool showOnTap;
  final double? above;
  final Rect Function()? around;

  /// The least room a card keeps from the window's edges.
  static const double margin = 8;

  /// The narrowest a card gets at the window's right edge.
  static const double minWidth = 240;

  // design: a hover card's wait, as a tooltip's
  static const _delay = Duration(milliseconds: 400);

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  Timer? _wait;
  Timer? _leave;

  /// Whether a click showed it: then the pointer leaving doesn't hide it.
  bool _tapped = false;

  void _enter() {
    _leave?.cancel();
    if (_portal.isShowing) return;
    _wait ??= Timer(HoverCard._delay, _show);
  }

  void _show() {
    _wait?.cancel();
    _wait = null;
    if (!mounted || _portal.isShowing) return;
    widget.onShow?.call();
    _portal.show();
  }

  void _hide() {
    _tapped = false;
    if (mounted && _portal.isShowing) _portal.hide();
  }

  void _tap() {
    _leave?.cancel();
    if (_tapped) return _hide();
    _tapped = true;
    _show();
  }

  // A moment's grace, so the pointer can cross the gap to the card.
  void _exit() {
    _wait?.cancel();
    _wait = null;
    _leave?.cancel();
    if (_tapped) return;
    // design: a hover card's linger, as a tooltip's
    _leave = Timer(const Duration(milliseconds: 150), _hide);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _leave?.cancel();
    super.dispose();
  }

  /// Where the card goes: over or under its child (over when
  /// [HoverCard.above] asks and the window has less room than that under
  /// what it keeps clear of), how far past the child's edge that is, and
  /// how far left and how wide it may be to stay in the window.
  ({bool over, Offset shift, double width}) _place() {
    final box = context.findRenderObject();
    final window = MediaQuery.sizeOf(context);
    if (box is! RenderBox || !box.hasSize) {
      return (over: false, shift: Offset.zero, width: window.width);
    }
    final own = box.localToGlobal(Offset.zero) & box.size;
    final clear = widget.around?.call() ?? own;
    final over =
        widget.above != null && window.height - clear.bottom < widget.above!;
    final room = window.width - own.left - HoverCard.margin;
    final width = max(room, HoverCard.minWidth);
    final left = max(room - width, HoverCard.margin - own.left);
    return (
      over: over,
      shift: Offset(
        left,
        over ? clear.top - own.top - 4 : clear.bottom - own.bottom + 4,
      ),
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: widget.child,
    );
    if (widget.showOnTap) {
      child = TapRegion(
        groupId: this,
        onTapOutside: (_) => _hide(),
        // design: a touch screen's tap shows the card
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: child,
        ),
      );
    }
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final (:over, :shift, :width) = _place();
          Widget card = MouseRegion(
            onEnter: (_) => _enter(),
            onExit: (_) => _exit(),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: widget.card(context),
            ),
          );
          if (widget.showOnTap) card = TapRegion(groupId: this, child: card);
          return CompositedTransformFollower(
            link: _link,
            targetAnchor: over ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: over ? Alignment.bottomLeft : Alignment.topLeft,
            offset: shift,
            child: Align(
              alignment: over ? Alignment.bottomLeft : Alignment.topLeft,
              child: card,
            ),
          );
        },
        child: child,
      ),
    );
  }
}
