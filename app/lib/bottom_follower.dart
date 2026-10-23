import 'package:flutter/widgets.dart';

/// Keeps a list scrolled to its bottom ([following]) until the user
/// scrolls up, however little, and again once they scroll back down to it.
/// The list's notifications go to [onNotification]; [stick] after a build.
class BottomFollower extends ChangeNotifier {
  final scroll = ScrollController();
  bool following = true;
  bool _jumping = false; // the scroll moves because of us

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
    if (p.pixels == p.maxScrollExtent) return;
    _jumping = true;
    p.jumpTo(p.maxScrollExtent);
    _jumping = false;
  });

  /// Takes the list's notifications. Only the user's scrolls of the list
  /// itself count, not those of what's in it (a wide code block).
  bool onNotification(Notification n) {
    if (n is ScrollMetricsNotification && n.depth == 0) {
      stick();
    } else if (n is ScrollUpdateNotification && n.depth == 0 && !_jumping) {
      final delta = n.scrollDelta ?? 0;
      final m = n.metrics;
      if (delta < 0) {
        _set(false);
      } else if (delta > 0 && m.pixels >= m.maxScrollExtent - 2) {
        _set(true);
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
