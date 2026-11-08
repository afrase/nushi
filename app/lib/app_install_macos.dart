import 'dart:io';

import 'package:nushi/app_install.dart';
import 'package:nushi/app_log.dart';

/// The daemon's helper app inside [app] (`make package`): a background-only
/// app, so a daemon the app started isn't the app's own process once it
/// quits (ADR 0036).
String helperIn(String app) => '$app/Contents/Helpers/Nushi Daemon.app';

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

/// The Mac app's bundle: the daemon in its helper app, opened with
/// `/usr/bin/open`, the version from its Info.plist, the data folder in
/// Application Support.
class MacAppInstall implements AppInstall {
  static final String? _home = Platform.environment['HOME'];

  /// The app's `Contents` folder, if it runs from a bundle.
  static final Directory _contents = File(Platform.resolvedExecutable)
      .parent
      .parent;

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
  @override
  Future<void> launch(String dataDir) async {
    if (daemon case final helper?) {
      Process.run(
        '/usr/bin/open',
        openHelper(helper, Platform.environment['NUSHI_DATA']),
      ).ignore();
    }
  }

  @override
  Future<void> stop(String dataDir) async => stopByLsof(dataDir);
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
  for (final pid in '${found.stdout}'.split('\n')) {
    if (int.tryParse(pid) case final pid?) Process.killPid(pid);
  }
}
