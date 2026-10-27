import 'dart:async';
import 'dart:math';

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/foundation.dart';
import 'package:nushi/daemon.dart';
import 'package:remote_transport/remote_transport.dart' show Unreachable;

/// Keeps the phone's link to the Mac up (ADR 0054). While it answers, a
/// ping every 15 s (which also keeps the relay's connection alive: a
/// browser can't send WebSocket pings, and the relay ends a link silent
/// 90 s). When a ping goes unanswered the channel is dropped (a phone that
/// slept may hold a socket the network already dropped) and tried again
/// after 1 s, then twice as long each time up to 30 s; at once when the
/// page shows again, the network comes back, or on Try again. What the
/// screen shows is fetched again once it's back (Daemon.relink).
class Link extends ChangeNotifier {
  new(
    this.daemon, {
    required this.reset,
    required this.live,
    this.seen,
    this.onSeen,
  });

  final Daemon daemon;

  /// Whether a channel is up (else a call dials first).
  final bool Function() live;

  /// Drops the channel: calls on it fail, and the next one dials again.
  final Future<void> Function() reset;

  /// When the Mac last answered (kept across launches by the phone).
  DateTime? seen;
  final void Function(DateTime seen)? onSeen;

  /// How often it pings while connected.
  static const every = Duration(seconds: 15);

  /// How long a ping on a live channel may take before the channel counts
  /// as dead; one that has to dial first gets the dial's own limits.
  static const answer = Duration(seconds: 8);
  static const dial = Duration(seconds: 50);

  /// Hidden longer than this, the channel is dropped on coming back.
  @visibleForTesting
  static Duration away = const Duration(seconds: 30);

  /// Whether a try is under way.
  bool trying = false;

  /// Whether the Mac has answered since the app started.
  bool answered = false;

  /// Tries that failed in a row since the Mac last answered.
  int failures = 0;

  /// Why the last try failed, when the relay said (null: it didn't).
  Unreachable? why;

  /// The last failure as it came, for the details.
  Object? error;

  /// Whether the last try was the user's (Try again): its result shows.
  bool asked = false;

  /// When the next automatic try is, while one waits.
  DateTime? next;

  Timer? _timer;
  Future<bool>? _try;
  bool _visible = true;
  DateTime? _hidden;
  bool _disposed = false;

  /// Starts: the first try at once.
  void start() => unawaited(check());

  /// Tries now (Try again, or the page showed): says whether the Mac
  /// answered.
  Future<bool> check({bool user = false}) {
    if (user) asked = true;
    return _try ??= _run().whenComplete(() => _try = null);
  }

  Future<bool> _run() async {
    _timer?.cancel();
    next = null;
    trying = true;
    _notify();
    final ok = await daemon.ping(wait: live() ? answer : dial);
    trying = false;
    if (_disposed) return ok;
    if (ok) {
      answered = true;
      failures = 0;
      why = null;
      error = null;
      asked = false;
      seen = DateTime.now();
      onSeen?.call(seen!);
      _schedule(every);
    } else {
      failures++;
      error = daemon.pingError;
      why = switch (error) {
        connect.ConnectException(cause: final Unreachable u) => u,
        _ => null,
      };
      // Whatever the channel was, it's no use: drop it, and with it the
      // event stream, which subscribes again once the Mac answers.
      daemon.relink();
      await reset();
      _schedule(Duration(seconds: min(30, 1 << min(failures - 1, 5))));
    }
    _notify();
    return ok;
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    if (_disposed) return;
    next = DateTime.now().add(d);
    // Not while hidden: iOS freezes a hidden app (a timer may still fire
    // first, on a network that's gone), and coming back tries at once.
    _timer = Timer(d, () {
      if (_visible) unawaited(check());
    });
  }

  /// The page showed or hid. Coming back, it reconnects at once and
  /// quietly: what failed while hidden doesn't count (at most
  /// "Reconnecting…" shows until a try after coming back fails twice).
  /// Back after a while, the channel is dropped first (iOS freezes a
  /// hidden app, and its socket rarely survives), then dialled again.
  void visible({required bool shown}) {
    if (!shown) {
      _visible = false;
      _hidden = DateTime.now();
      _timer?.cancel();
      return;
    }
    if (_visible) return;
    _visible = true;
    failures = 0;
    asked = false;
    final gone = DateTime.now().difference(_hidden ?? DateTime.now());
    if (gone >= away || !daemon.connected) {
      unawaited(_fresh());
    } else {
      unawaited(check());
    }
  }

  /// The page came back some other way (restored from the back-forward
  /// cache, or focused): as coming back to the front, or a quiet try if
  /// the link is down.
  void resume() {
    if (!_visible) return visible(shown: true);
    if (!daemon.connected && !trying) {
      failures = 0;
      unawaited(_fresh());
    }
  }

  /// The network came back: try at once.
  void online() => unawaited(daemon.connected ? check() : _fresh());

  Future<void> _fresh() async {
    if (_try != null || _freshening) return;
    _freshening = true;
    try {
      daemon.relink();
      await reset();
      await check();
    } finally {
      _freshening = false;
    }
  }

  bool _freshening = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
