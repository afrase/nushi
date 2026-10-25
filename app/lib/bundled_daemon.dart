import 'dart:io';

import 'app_log.dart';
import 'daemon.dart';

/// The daemon's helper app inside [app] (`make package`): a background-only
/// app, so a daemon the app started isn't the app's own process once it
/// quits (ADR 0036).
String helperIn(String app) => '$app/Contents/Helpers/Nushi Daemon.app';

/// The bundled daemon's helper app, if the app runs from a bundle.
final String? bundledDaemon = () {
  final macOS = File(Platform.resolvedExecutable).parent; // Contents/MacOS
  final helper = helperIn(macOS.parent.parent.path);
  return Directory(helper).existsSync() ? helper : null;
}();

/// The bundled daemon's build, as the daemon tells its own (PingResponse).
final String? bundledBuild = () {
  if (bundledDaemon case final helper?) {
    final st = File('$helper/Contents/MacOS/nushid').statSync();
    return '${st.size}-${st.modified.millisecondsSinceEpoch}';
  }
  return null;
}();

/// What opens [helper] as a new instance through Launch Services, in the
/// background, with [nushiData] (development) passed on. The daemon then
/// goes through the user's login shell (`nushid -login`), so it and its
/// agents get the user's PATH.
List<String> openHelper(String helper, String? nushiData) => [
  '-n',
  '-g',
  if (nushiData != null) ...['--env', 'NUSHI_DATA=$nushiData'],
  helper,
  '--args',
  '-login',
];

/// The data folder from when the app was "Nushi Next". The daemon moves it
/// to [dataDir] when it starts, once its own daemon has stopped.
final String? _oldDataDir =
    Platform.environment['NUSHI_DATA'] == null &&
        !Directory(dataDir).existsSync() &&
        Directory('$support/Nushi Next').existsSync()
    ? '$support/Nushi Next'
    : null;

/// Starts the bundled daemon when none answers.
class Launcher {
  DateTime launched = DateTime(0); // when it last started it
  int launches = 0; // starts since the daemon last answered

  /// Starts the bundled daemon, at most every ten seconds; it outlives
  /// the app. Says whether it tried.
  bool launch() {
    final helper = bundledDaemon;
    if (helper == null || DateTime.now().difference(launched).inSeconds < 10) {
      return false;
    }
    launched = DateTime.now();
    launches++;
    appLog.info('starting the bundled daemon', {'try': '$launches'});
    // Moving from Nushi Next: its daemon stops, and the new one starts in
    // the old folder, which it then moves (its log and folder move along).
    if (_oldDataDir case final old? when !Directory(dataDir).existsSync()) {
      stopDaemon(old);
    }
    Process.run(
      '/usr/bin/open',
      openHelper(helper, Platform.environment['NUSHI_DATA']),
    ).ignore();
    return true;
  }
}

/// Stops the daemon listening in [dir], if one is.
void stopDaemon(String dir) {
  final lsof = Process.runSync('lsof', [
    '-a',
    '-c',
    'nushid',
    '-t',
    '$dir/nushid.sock',
  ]);
  for (final pid in '${lsof.stdout}'.split('\n')) {
    if (int.tryParse(pid) case final pid?) Process.killPid(pid);
  }
}
