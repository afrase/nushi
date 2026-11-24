import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The daemon's settings while Settings is open (ADR 0087): asked for as
/// it opens, asked again once the daemon is back if it was gone, and
/// changed one change after another. Settings makes one and disposes it
/// as it closes, and hands it to the pages that show a daemon setting; the
/// next open asks again, so nothing kept here outlives a look at the page
/// (a paired device or a newer daemon may have changed them meanwhile).
/// Its value is null until the daemon said.
class DaemonSettings extends ValueNotifier<Settings?> {
  /// Asks [daemon] for its settings at once.
  new(this.daemon) : super(null) {
    _ask();
  }

  /// Whose settings these are.
  final Daemon daemon;

  Settings? _set; // as the last change set them
  bool _asking = false;
  bool _disposed = false;

  // The settings asked for while the daemon was gone.
  late final _again = LoadAgain(daemon, () {
    if (!_disposed) _ask();
  });

  /// The changes being made, one after another: each sends every setting
  /// (SetSettings), so each starts from what the one before set.
  Future<void> _changes = Future.value();

  void _ask() {
    if (value != null || _asking) return;
    _asking = true;
    unawaited(
      daemon.client
          .getSettings(GetSettingsRequest())
          .then(
            (r) => _disposed ? null : value = r.settings,
            onError: _again.failed, // asked again when the daemon is back
          )
          .whenComplete(() => _asking = false),
    );
  }

  /// Sets the daemon's settings: [f] applied to them, after the changes
  /// asked before it. Only once they came (a row shows only then).
  Future<void> change(void Function(Settings) f) {
    final done = _changes.then((_) async {
      final set = (_set ?? value)!.deepCopy();
      f(set);
      await daemon.client.setSettings(SetSettingsRequest(settings: set));
      _set = set; // the next change's start, closed or not
      if (!_disposed) value = set;
    });
    _changes = done.then((_) {}, onError: (_) {}); // a failure is the asker's
    return done;
  }

  @override
  void dispose() {
    _disposed = true;
    _again.cancel();
    super.dispose();
  }
}
