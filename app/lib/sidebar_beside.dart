import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:nushi/menu.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';

/// [main] with the sidebar at its left while it shows: the sidebar slides
/// in from the window's edge as it comes and out as it goes, over [main],
/// which is laid out at once where it goes and keeps its state either way.
/// What's in [main] that should glide (the chat's column) does so itself
/// (`Beside`), and what leads a header past the lights follows the
/// sidebar's edge ([SidebarGlide]). Over all of it, at one place whatever
/// the sidebar does, [TitleButtons] (ADR 0116).
///
/// While it's hidden ([shut]), the pointer on the sidebar's button, or
/// resting on the window's left edge, peeks at it (ADR 0116): it slides in
/// over [main], floating ([sidebar] given true: a raised card with a
/// shadow), without moving [main], and works as it does shown. It slides
/// away once the pointer has been off it, the title buttons and the edge
/// for [grace], never while one of its menus or a dialog is open. The
/// sidebar's button, pressed then, shows it for good, at once where it
/// floated.
class SidebarBeside extends StatefulWidget {
  const new({
    required this.sidebar,
    required this.shut,
    required this.main,
    super.key,
  });

  /// The sidebar, floating in a peek or not.
  final Widget Function({required bool floating}) sidebar;
  final bool shut;
  final Widget main;

  /// How long a peek stays once the pointer is off it: a move from the
  /// button or the edge to it on a slant, through the window's margin,
  /// doesn't close it.
  static const grace = Duration(milliseconds: 300);

  /// How long the pointer rests on the window's left edge before the
  /// sidebar peeks: a pass on the way elsewhere doesn't bring it.
  static const dwell = Duration(milliseconds: 150);

  @override
  State<SidebarBeside> createState() => _SidebarBesideState();
}

class _SidebarBesideState extends State<SidebarBeside> {
  final _glide = SidebarGlide();

  /// Whether the sidebar peeks.
  bool _peek = false;

  /// Where the pointer is: on the peek's card, on the title buttons, on
  /// the window's left edge, on the sidebar's button.
  bool _onCard = false;
  bool _onTitle = false;
  bool _onEdge = false;
  bool _onButton = false;

  /// Whether the sidebar's button may peek: not from its press that hid
  /// the sidebar until the pointer has left it.
  bool _armed = true;

  /// The menus open in the peek.
  int _menus = 0;

  Timer? _close;
  Timer? _dwell;

  /// Counts the sidebar's comings at once: the sidebar shown from a peek
  /// takes its place without sliding in, as it's already there.
  int _docked = 0;

  bool get _onIt => _onCard || _onTitle || _onEdge;

  @override
  void didUpdateWidget(SidebarBeside old) {
    super.didUpdateWidget(old);
    if (old.shut == widget.shut) return;
    _close?.cancel();
    _dwell?.cancel();
    _menus = 0;
    if (!widget.shut && _peek) _docked++;
    _peek = false;
    if (widget.shut && _onButton) _armed = false;
  }

  @override
  void dispose() {
    _close?.cancel();
    _dwell?.cancel();
    super.dispose();
  }

  void _open() {
    _close?.cancel();
    if (!_peek && widget.shut) setState(() => _peek = true);
  }

  /// The pointer left something of it: it goes after [SidebarBeside.grace]
  /// unless the pointer is back by then.
  void _leave() {
    if (!_peek || _onIt) return;
    _close?.cancel();
    _close = Timer(SidebarBeside.grace, _end);
  }

  void _end() {
    if (!mounted || !_peek || _onIt) return;
    // A menu of it, or a dialog it opened, keeps it until it's gone.
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    if (_menus > 0 || covered) {
      _close = Timer(SidebarBeside.grace, _end);
      return;
    }
    setState(() => _peek = false);
  }

  void _sidebarHover(bool on) {
    _onButton = on;
    if (!on) {
      _armed = true;
    } else if (_armed) {
      _open();
    }
  }

  void _titleHover(bool on) {
    _onTitle = on;
    if (on) {
      _close?.cancel();
    } else {
      _leave();
    }
  }

  void _edgeHover(bool on) {
    _onEdge = on;
    _dwell?.cancel();
    if (on) {
      _close?.cancel();
      _dwell = Timer(SidebarBeside.dwell, _open);
    } else {
      _leave();
    }
  }

  void _cardHover(bool on) {
    _onCard = on;
    if (on) {
      _close?.cancel();
    } else {
      _leave();
    }
  }

  bool _menu(MenuOpened n) {
    _menus = max(0, _menus + (n.open ? 1 : -1));
    if (_menus == 0) _leave();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shut = widget.shut;
    final view = LayoutId(
      key: const ValueKey(#main),
      id: #main,
      child: widget.main,
    );
    final side = LayoutId(
      key: const ValueKey(#sidebar),
      id: #sidebar,
      child: Presence(
        key: ValueKey(_docked),
        child: shut ? null : widget.sidebar(floating: false),
        builder: (_, run, child) =>
            paneSlide(run, _glide.origin(run, child), left: true),
      ),
    );
    final peek = LayoutId(
      key: const ValueKey(#peek),
      id: #peek,
      child: Presence(
        child: _peek ? _card(context) : null,
        builder: (_, run, child) => paneSlide(run, child, left: true),
      ),
    );
    final edge = LayoutId(
      key: const ValueKey(#edge),
      id: #edge,
      child: MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) => _edgeHover(true),
        onExit: (_) => _edgeHover(false),
        child: const SizedBox.expand(),
      ),
    );
    final buttons = LayoutId(
      key: const ValueKey(#buttons),
      id: #buttons,
      // Opaque, as what it holds: a press on a button is the button's
      // alone, never the header's under it too.
      child: MouseRegion(
        onEnter: (_) => _titleHover(true),
        onExit: (_) => _titleHover(false),
        child: TitleButtons(onSidebarHover: _sidebarHover),
      ),
    );
    // Keyed, so each keeps its state as they swap: the sidebar first, as it
    // reads, while it shows; over the view as it goes. A peek over the
    // view, the edge over that, and the buttons over all.
    return _glide.scope(
      CustomMultiChildLayout(
        delegate: _SidebarBeside(shut: shut),
        children: [
          if (shut) ...[view, side] else ...[side, view],
          if (shut) ...[peek, edge],
          buttons,
        ],
      ),
    );
  }

  /// The sidebar floating over the view, in from the window's top, left
  /// and bottom edges by its margin: as what floats (ADR 0111), a soft
  /// shadow under it and a hairline where its edge meets the pane, drawn
  /// over its edge, so it lies where it would shown. Its fill is its own,
  /// the window's, so New chat and the status card stand out on it as
  /// they do shown.
  Widget _card(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final corners = BorderRadius.circular(NushiTheme.panel);
    return MouseRegion(
      onEnter: (_) => _cardHover(true),
      onExit: (_) => _cardHover(false),
      child: NotificationListener<MenuOpened>(
        onNotification: _menu,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.window,
            borderRadius: corners,
            boxShadow: floatShadows(t),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: t.floatLine),
            borderRadius: corners,
          ),
          child: widget.sidebar(floating: true),
        ),
      ),
    );
  }
}

class _SidebarBeside extends MultiChildLayoutDelegate {
  new({required this.shut});

  final bool shut;

  @override
  void performLayout(Size size) {
    final width = layoutChild(
      #sidebar,
      BoxConstraints(
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
      ),
    ).width;
    positionChild(#sidebar, Offset.zero);
    final x = shut ? 0.0 : width;
    layoutChild(
      #main,
      BoxConstraints.tightFor(
        width: max(0, size.width - x),
        height: size.height,
      ),
    );
    positionChild(#main, Offset(x, 0));
    if (hasChild(#peek)) {
      const pad = NushiTheme.windowPad;
      layoutChild(
        #peek,
        BoxConstraints(
          maxWidth: max(0, size.width - 2 * pad),
          minHeight: max(0, size.height - 2 * pad),
          maxHeight: max(0, size.height - 2 * pad),
        ),
      );
      positionChild(#peek, const Offset(pad, pad));
      // Under the headers' band, the margin's width.
      const top = TitleButtons.top + TitleButtons.height;
      layoutChild(
        #edge,
        BoxConstraints.tightFor(width: pad, height: max(0, size.height - top)),
      );
      positionChild(#edge, const Offset(0, top));
    }
    layoutChild(#buttons, BoxConstraints.loose(size));
    positionChild(#buttons, Offset(TitleButtons.left, TitleButtons.top));
  }

  @override
  bool shouldRelayout(_SidebarBeside old) => old.shut != shut;
}
