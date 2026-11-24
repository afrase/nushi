import 'dart:io';

import 'package:nushi/app_install.dart';
import 'package:nushi/app_log.dart';

/// The daemon's helper app inside [app] (`make package`): a background-only
/// app, so a daemon the app started isn't the app's own process once it
/// quits (ADR 0036).
String helperIn(String app) => '$app/Contents/Helpers/Nushi Daemon.app';

/// What opens [helper] as a new instance through Launch Services, in the
/// background, with [nushiData] (development) passed on, as `nushid
/// -login`: it then reads the user's login shell's environment itself.
List<String> openHelper(String helper, String? nushiData) => [
  '-n',
  '-g',
  if (nushiData != null) ...['--env', 'NUSHI_DATA=$nushiData'],
  helper,
  '--args',
  '-login',
];

/// The Mac app's bundle: the daemon in its helper app, opened with
/// `/usr/bin/open`, the version from its Info.plist, the data folder in
/// Application Support.
class MacAppInstall implements AppInstall {
  /// A test passes the [executable] the app runs as, [home], and what
  /// [run]s `/usr/bin/open`.
  new({String? executable, String? home, this.run = Process.run})
    : _contents = File(executable ?? Platform.resolvedExecutable).parent.parent,
      _home = home ?? Platform.environment['HOME'];

  final String? _home;

  /// The app's `Contents` folder, if it runs from a bundle.
  final Directory _contents;

  /// What runs `open`, and says how it ended.
  final Future<ProcessResult> Function(String program, List<String> args) run;

  @override
  String get dataFolder => '$_home/Library/Application Support/Nushi';

  @override
  late final String? daemon = () {
    final helper = helperIn(_contents.parent.path);
    return Directory(helper).existsSync() ? helper : null;
  }();

  @override
  late final String? daemonBuild = () {
    if (daemon case final helper?) {
      final st = File('$helper/Contents/MacOS/nushid').statSync();
      return '${st.size}-${st.modified.millisecondsSinceEpoch}';
    }
    return null;
  }();

  @override
  late final String version = () {
    try {
      final plist = File('${_contents.path}/Info.plist').readAsStringSync();
      String key(String k) =>
          RegExp('<key>$k</key>\\s*<string>([^<]*)</string>')
              .firstMatch(plist)
              ?.group(1) ??
          '';
      return '${key('CFBundleShortVersionString')}+${key('CFBundleVersion')}';
    } on Object {
      return '';
    }
  }();

  @override
  String get stopByHand => 'quit nushid in Activity Monitor';

  /// Launch Services opens the helper; the helper's daemon keeps the
  /// default data folder unless the app has `NUSHI_DATA`, which it passes.
  /// An `open` that fails (Launch Services refused, the helper damaged or
  /// quarantined) is logged with its exit code and stderr: the daemon
  /// never ran, so its own log has nothing.
  @override
  Future<void> launch(String dataDir) async {
    final helper = daemon;
    if (helper == null) return;
    final ProcessResult opened;
    try {
      opened = await run(
        '/usr/bin/open',
        openHelper(helper, Platform.environment['NUSHI_DATA']),
      );
    } on ProcessException catch (e) {
      appLog.warn("the bundled daemon didn't start", {'error': e.message});
      return;
    }
    if (opened.exitCode != 0) {
      appLog.warn("the bundled daemon didn't start", {
        'exit': '${opened.exitCode}',
        'stderr': '${opened.stderr}'.trim(),
      });
    }
  }

  @override
  Future<void> stop(String dataDir, {int pid = 0}) async => stopByLsof(dataDir);
}

/// Stops the daemon listening in [dir], if one is, through [lsof]. A
/// machine without lsof stops nothing and logs it, and the restart that
/// asked says the daemon didn't stop.
void stopByLsof(String dir, {String lsof = 'lsof'}) {
  final ProcessResult found;
  try {
    found = Process.runSync(lsof, [
      '-a',
      '-c',
      'nushid',
      '-t',
      '$dir/nushid.sock',
    ]);
  } on ProcessException catch (e) {
    appLog.warn('no lsof to find the daemon by, so none stopped', {
      'error': e.message,
    });
    return;
  }
  // lsof exits 1, saying nothing, when nothing listens there.
  final said = '${found.stderr}'.trim();
  if (found.exitCode != 0 && said.isNotEmpty) {
    appLog.warn("lsof didn't find the daemon, so none stopped", {
      'exit': '${found.exitCode}',
      'stderr': said,
    });
  }
  for (final pid in '${found.stdout}'.split('\n')) {
    if (int.tryParse(pid) case final pid? when !Process.killPid(pid)) {
      appLog.warn("the daemon couldn't be stopped", {'pid': '$pid'});
    }
  }
}
