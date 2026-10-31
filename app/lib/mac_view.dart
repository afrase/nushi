import 'dart:async';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The daemon API that keeps each chat's unseen turn's end (Chat.done)
/// and takes the Mac's view (SetDeviceView on the socket).
const doneApi = 76;

/// Tells the daemon which chat the Mac's window shows, as the phone does
/// (the daemon's ViewLease): the selected chat while the window is focused
/// or visible and nothing (the trust card, Settings, Jira, GitHub) is in
/// its place ([DaemonPlaces.chatShows]). Said
/// when it changes and again every [again] while it shows, so a turn
/// ending there is seen.
class MacView {
  new(this.daemon);

  final Daemon daemon;

  /// Within the daemon's 40 s lease.
  static const again = Duration(seconds: 15);

  bool _window = true;
  String? _told; // what the daemon was last told; null: tell it again
  DateTime _at = DateTime(0);

  /// Whether the window is focused or visible (not hidden or minimised).
  bool get window => _window;
  set window(bool shows) {
    _window = shows;
    tick();
  }

  /// The chat the window shows, or ''.
  String get showing =>
      _window && daemon.chatShows ? daemon.selectedId ?? '' : '';

  /// The daemon (re)started: it knows nothing yet.
  void forget() => _told = null;

  /// Tells the daemon what shows if that changed, or it's time to say it
  /// again.
  void tick() {
    if (!daemon.connected || daemon.daemonApi < doneApi) return;
    final id = showing;
    final now = DateTime.now();
    // Nothing shown is what a daemon that was told nothing knows.
    if (id == (_told ?? '') && (id.isEmpty || now.difference(_at) < again)) {
      return;
    }
    _told = id;
    _at = now;
    unawaited(
      daemon.client
          .setDeviceView(SetDeviceViewRequest(chatId: id))
          .then((_) {}, onError: (Object _) => _told = null),
    );
  }
}
