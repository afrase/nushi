import 'package:flutter/widgets.dart';

/// Keeps a list scrolled to its bottom ([following]) until the user
/// scrolls up, however little, and again once it is back at the bottom (by
/// a drag or a fling). The list's notifications go to
/// [onNotification]; [stick] after a build.
class BottomFollower extends ChangeNotifier {
  late final ScrollController scroll = _Controller(this);
  bool following = true;
  bool _jumping = false; // the scroll moves because of us
  bool _dragged = false; // the scroll going on began with a drag

  /// Follows the bottom again, from wherever the list is.
  void follow() {
    _set(true);
    stick();
  }

  /// Stops following: the list was taken somewhere else.
  void stop() => _set(false);

  void _set(bool v) {
    if (v == following) return;
    following = v;
    notifyListeners();
  }

  /// Scrolls to the bottom after this frame's layout, if following. Lazily
  /// built items change the list's height as they come into view, so the
  /// list's [ScrollMetricsNotification]s call it again. The list's height
  /// changing in a frame is met in that frame ([_Position]); this is for
  /// [follow], which starts between frames.
  void stick() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!following || !scroll.hasClients) return;
    final p = scroll.position;
    if (p.pixels >= p.maxScrollExtent) return;
    _jumping = true;
    p.jumpTo(p.maxScrollExtent);
    _jumping = false;
  });

  /// Takes the list's notifications. Only the user's scrolls of the list
  /// itself count, not those of what's in it (a wide code block). A drag's
  /// fling moves the list too, but isn't the user scrolling up.
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
      if (m.pixels >= m.maxScrollExtent - 1) {
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

class _Controller extends ScrollController {
  new(this.follower);

  final BottomFollower follower;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _Position(
    follower: follower,
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );
}

/// Stays at the bottom in the layout that moved it. A jump after the frame
/// comes after its paint: a transcript filling in from the bottom
/// (ADR 0026) would show each frame what its new entries pushed into view,
/// and seem to scroll through the whole chat.
class _Position extends ScrollPositionWithSingleContext {
  new({
    required this.follower,
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final BottomFollower follower;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (follower.following && hasPixels && pixels < maxScrollExtent) {
      correctPixels(maxScrollExtent);
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
