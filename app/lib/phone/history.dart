import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nushi/phone/platform.dart';

/// iOS's slide between screens without Flutter's own edge swipe: the
/// swipe is the browser's ([PhoneHistory]), and a drag of Flutter's own
/// that the browser takes over never ends, leaving the app deaf to taps.
const browserBackTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: _Slide(),
    TargetPlatform.android: _Slide(),
    TargetPlatform.macOS: _Slide(),
  },
);

class _Slide extends PageTransitionsBuilder {
  const new();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => CupertinoPageTransition(
    primaryRouteAnimation: animation,
    secondaryRouteAnimation: secondaryAnimation,
    linearTransition: false,
    child: child,
  );
}

/// The browser's history as the app's screens: one entry per screen pushed
/// over the root (a chat, New chat, Settings, Scan), so the browser's back
/// (iOS's edge swipe, Safari's back button) goes back a screen and, at the
/// root, leaves the page as a browser does.
///
/// Each entry says how many screens are over the root at it (its depth),
/// nothing else: the address stays the page's own. A screen pushed in the
/// app pushes its entry then and there, inside the tap, before it draws:
/// iOS keeps a picture of the page as an entry is pushed, and shows it
/// under the swipe back (two entries made at launch showed "Loading
/// Nushi…" there, as if the page reloaded). A screen gone in the app (its
/// back button, popUntil, Forget) takes the history back with it
/// (`history.go`); a back in the browser takes the screens over that
/// entry's depth away, at once (iOS has already shown the screen under
/// them). Whichever moved first, the other follows by depth, so a move
/// that answers a move is a no-op.
class PhoneHistory extends NavigatorObserver {
  new(this.platform) {
    platform.onEntry = _moved;
  }

  final PhonePlatform platform;

  /// The navigator's routes, root first (dialogs and sheets too).
  final _stack = <Route<Object?>>[];

  /// The screens over the root, each with its entry.
  final _screens = <Route<Object?>>[];

  /// The depth of the entry the browser is at, as far as it has said.
  int _at = 0;

  /// When a `history.go` was asked whose move hasn't come yet: nothing
  /// else is asked of the history meanwhile (it would land on the wrong
  /// entry).
  DateTime? _going;
  bool _scheduled = false;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    _stack.add(route);
    if (route is PageRoute && previousRoute != null) {
      _screens.add(route);
      _sync(); // now, before the screen draws
    }
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) =>
      _gone(route);

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) =>
      _gone(route);

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (newRoute == null || oldRoute == null) return;
    final i = _stack.indexOf(oldRoute);
    if (i >= 0) _stack[i] = newRoute;
    final s = _screens.indexOf(oldRoute);
    if (s >= 0) _screens[s] = newRoute;
  }

  void _gone(Route<Object?> route) {
    _stack.remove(route);
    if (!_screens.remove(route)) return;
    // Once for screens gone together (popUntil): one go back.
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      _sync();
    });
  }

  /// Brings the browser to the screens' depth.
  void _sync() {
    final going = _going;
    if (going != null) {
      // A move that never came (the browser dropped it) doesn't stop the
      // history for good.
      if (DateTime.now().difference(going).inSeconds < 2) return;
      _going = null;
    }
    final want = _screens.length;
    if (want < _at) {
      _going = DateTime.now();
      platform.go(want - _at);
    } else {
      while (_at < want) {
        platform.pushEntry(++_at);
      }
    }
  }

  /// The browser moved to an entry of the app's: back, forward, or the
  /// answer to a `go` of ours.
  void _moved(int depth) {
    _at = depth;
    _going = null;
    if (depth < _screens.length) {
      // Back: the screens over it go, without the animation iOS has
      // already shown.
      final nav = navigator;
      final keep = depth == 0 ? null : _screens[depth - 1];
      if (nav != null) {
        for (final r in _stack.reversed.toList()) {
          if (r == keep || r.isFirst) break;
          nav.removeRoute(r);
        }
      }
    }
    // Forward onto an entry whose screen is gone: back again.
    _sync();
  }
}
