import 'dart:io';

import 'daemon.dart';

/// The daemon in the app's bundle (`make package`), if the app runs from one.
final String? bundledDaemon = () {
  final path = '${File(Platform.resolvedExecutable).parent.path}/nushid';
  return File(path).existsSync() ? path : null;
}();

/// The bundled daemon's build, as the daemon tells its own (PingResponse).
final String? bundledBuild = () {
  if (bundledDaemon case final path?) {
    final st = File(path).statSync();
    return '${st.size}-${st.modified.millisecondsSinceEpoch}';
  }
  return null;
}();

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

  /// Starts the bundled daemon, at most every ten seconds. It runs through
  /// the user's login shell, so it and its agents get the user's PATH, and
  /// detached, so it outlives the app. Says whether it tried.
  bool launch() {
    final bin = bundledDaemon;
    if (bin == null || DateTime.now().difference(launched).inSeconds < 10) {
      return false;
    }
    launched = DateTime.now();
    launches++;
    // Moving from Nushi Next: its daemon stops, and the new one starts in
    // the old folder, which it then moves (its log and folder move along).
    var dir = dataDir;
    if (_oldDataDir case final old? when !Directory(dataDir).existsSync()) {
      stopDaemon(old);
      dir = old;
    }
    Directory(dir).createSync(recursive: true);
    // The paths go through the environment: no quoting, and the line reads
    // the same in sh, zsh, bash and fish; another shell gets zsh.
    final shell = Platform.environment['SHELL'] ?? '';
    final known = {'sh', 'zsh', 'bash', 'fish', 'dash', 'ksh'};
    Process.start(
      known.contains(shell.split('/').last) ? shell : '/bin/zsh',
      ['-l', '-c', r'exec "$NUSHID_BIN" >>"$NUSHID_LOG" 2>&1'],
      workingDirectory: dir,
      environment: {'NUSHID_BIN': bin, 'NUSHID_LOG': '$dir/nushid.log'},
      mode: ProcessStartMode.detached,
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
