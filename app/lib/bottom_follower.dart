import 'package:flutter/widgets.dart';

/// Keeps a list scrolled to its bottom ([following]) until the user
/// scrolls up, however little, and again once it is back at the bottom (by
/// a drag, a fling or a bounce). The list's notifications go to
/// [onNotification]; [stick] after a build.
class BottomFollower extends ChangeNotifier {
  final scroll = ScrollController();
  bool following = true;
  bool _jumping = false; // the scroll moves because of us
  bool _dragged = false; // the scroll going on began with a drag

  /// Follows the bottom again, from wherever the list is.
  void follow() {
    _set(true);
    stick();
  }

  void _set(bool v) {
    if (v == following) return;
    following = v;
    notifyListeners();
  }

  /// Scrolls to the bottom after this frame's layout, if following. Lazily
  /// built items change the list's height as they come into view, so the
  /// list's [ScrollMetricsNotification]s call it again.
  void stick() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!following || !scroll.hasClients) return;
    final p = scroll.position;
    // At the bottom, or bouncing past it.
    if (p.pixels >= p.maxScrollExtent) return;
    _jumping = true;
    p.jumpTo(p.maxScrollExtent);
    _jumping = false;
  });

  /// Takes the list's notifications. Only the user's scrolls of the list
  /// itself count, not those of what's in it (a wide code block). A drag's
  /// fling and the spring back from past the bottom move the list too, but
  /// aren't the user scrolling up.
  bool onNotification(Notification n) {
    if (n is ScrollMetricsNotification && n.depth == 0) {
      // At the bottom (all of it fits, say): following again.
      if (n.metrics.extentAfter == 0) _set(true);
      stick();
    } else if (n is ScrollStartNotification && n.depth == 0) {
      _dragged = n.dragDetails != null;
    } else if (n is ScrollUpdateNotification && n.depth == 0 && !_jumping) {
      final m = n.metrics;
      // A wheel's scroll (no drag), or a drag itself, not its fling.
      final user = n.dragDetails != null || !_dragged;
      if (m.pixels > m.maxScrollExtent) {
        // Past the bottom, bouncing: nothing to decide yet.
      } else if (m.pixels >= m.maxScrollExtent - 1) {
        _set(true);
      } else if ((n.scrollDelta ?? 0) < 0 && user) {
        _set(false);
      }
    }
    return false;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }
}
