part of 'daemon.dart';

/// The link to nushid: whether it answers, and which daemon that is, how it
/// compares with the bundled one, and restarting it.
extension DaemonLink on Daemon {
  /// Whether the daemon is older than the app: it needs a restart.
  bool get outdated => daemonApi < apiVersion;

  /// Whether the app bundles a newer build of the daemon than the one that
  /// runs (installed since it started): a restart would bring it in. Newer
  /// by its program's time, so a second, older copy of the app open at
  /// once never takes the daemon back.
  bool get replaced =>
      _build.isNotEmpty && _builtAt(bundled ?? '') > _builtAt(_build);

  static int _builtAt(String build) => int.tryParse(build.split('-').last) ?? 0;

  /// Whether the daemon is older than the bundled one and restarts into it
  /// by itself once nothing runs: the pings ask it to (an ask lapses unless
  /// repeated, so an app that quit leaves it running), and the app starts
  /// the new one when it has gone. Meanwhile the app works as usual, the
  /// daemon behind or not (its API only grew), so what runs can be seen
  /// and answered.
  bool get updatesWhenIdle =>
      !remote &&
      bundled != null &&
      daemonApi >= restartWhenIdleApi &&
      (outdated || replaced);

  static bool _sameHolds(List<RestartHold> a, List<RestartHold> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  void _sawUpdate(UpdateCheck u) {
    if (u == update) return;
    update = u;
    _changed();
  }

  /// Asks the daemon to check for a newer release now.
  Future<UpdateCheck> checkForUpdates() async {
    final r = await client.checkForUpdates(CheckForUpdatesRequest());
    _sawUpdate(r.update);
    return r.update;
  }

  /// Whether starting the bundled daemon keeps failing.
  bool get launchFailed => _launcher.launches >= 3 && !connected;

  /// Asks the daemon whether it's there (every few seconds, and when the
  /// phone comes back to the front).
  /// Whether it answered; a phone's link gives a longer [wait] when the
  /// call has to dial the relay first. One at a time: a ping asked while
  /// one is out gets its answer (every 2 s against a 3 s wait, a late
  /// failure would turn the link off after a newer ping turned it on).
  Future<bool> ping({Duration wait = const Duration(seconds: 3)}) =>
      _pinging ??= _ping(wait).whenComplete(() => _pinging = null);

  Future<bool> _ping(Duration wait) async {
    var api = 0;
    var build = '';
    var version = '';
    var found = UpdateCheck();
    try {
      // A daemon that hangs counts as gone, rather than stalling the pings.
      final r = await client.ping(PingRequest()).timeout(wait);
      (api, build, version) = (r.apiVersion, r.build, r.version);
      found = r.update;
      pingError = null;
    } on Object catch (e) {
      pingError = e;
      if (!remote && _launcher.launch() && _launcher.launches == 3) {
        _changed();
      }
    }
    final ok = api > 0;
    if (ok) _launcher.launches = 0;
    if (ok && !remote) _sawUpdate(found);
    if (ok && _events == null) _subscribe();
    if (ok && (!connected || build != _build)) macView.forget();
    if (ok != connected || ok && (api != daemonApi || build != _build)) {
      final was = connected;
      connected = ok;
      if (ok) {
        daemonApi = api; // kept while away: the app stays as it was
        _build = build;
        daemonVersion = version;
        if (updatesWhenIdle && !updating) {
          appLog.info('the daemon restarts into the bundled one when idle', {
            'build': build,
            'bundled': ?bundled,
          });
        }
        updating = updatesWhenIdle;
      }
      _changed();
      if (remote) {
        // The phone has no app log.
      } else if (!ok) {
        appLog.warn('lost the daemon');
      } else if (outdated) {
        appLog.warn('the daemon is older than the app', {
          'daemon_api': '$api',
          'app_api': '$apiVersion',
        });
      } else if (!was) {
        appLog.info('connected to the daemon', {'api': '$api', 'build': build});
      }
    }
    if (ok && !remote) macView.tick(); // said again within the lease
    if (ok && updating) {
      unawaited(
        client.restartWhenIdle(RestartWhenIdleRequest()).then((r) {
          // What it waits for, for the update bar (an older daemon says
          // nothing).
          if (!_sameHolds(r.holds, restartHolds)) {
            restartHolds = r.holds;
            _changed();
          }
        }, onError: (Object _) {}),
      );
    }
    return ok;
  }

  /// The link to the daemon was dropped (the phone's, after a ping went
  /// unanswered): the events subscribe again with the next ping that
  /// answers, and what shows is fetched again.
  void relink() {
    unawaited(_events?.cancel());
    _events = null;
  }

  /// Stops the running daemon (it stops its agents) and starts the bundled
  /// one; chats reopen through session/load as they are opened. One at a
  /// time: asked again while one runs, it waits for that one (a second
  /// stop would stop the new daemon).
  Future<void> restartDaemon() {
    if (_restarting case final run?) return run;
    restartFailed = false;
    final run = _restarting = _restart()
        .catchError((Object e, StackTrace s) {
          restartFailed = true;
          Error.throwWithStackTrace(e, s);
        })
        .whenComplete(() {
          _restarting = null;
          _changed();
        });
    _changed();
    return run;
  }

  /// Whether [restartDaemon] runs.
  bool get restarting => _restarting != null;

  Future<void> _restart() async {
    await appLog.write(
      'info',
      'restarting the daemon',
      attrs: {'build': _build, 'bundled': ?bundledBuild},
    );
    final before = _build;
    stopDaemon(dataDir);
    // The first ping that fails starts the bundled daemon.
    _launcher.launched = DateTime(0);
    for (var i = 0; i < 50 && connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await ping();
    }
    if (connected && _build == before) {
      appLog.warn('the daemon did not stop', {'build': before});
      throw StateError(
        "The running daemon didn't stop: quit nushid in Activity Monitor, "
        'then reopen Nushi',
      );
    }
    // Then wait for the new one: callers reload from it, and a reload
    // while none answers fails quietly and leaves what asked for the
    // restart on screen.
    for (var i = 0; i < 100 && !connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await ping();
    }
    if (!connected) {
      throw StateError("The daemon didn't come back: Settings › Show logs");
    }
  }
}
