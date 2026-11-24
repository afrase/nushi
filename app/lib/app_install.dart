/// The installed app as the daemon's launcher sees it (ADR 0036, 0104):
/// where the data folder is, the daemon packaged with the app, the app's
/// version, and starting and stopping that daemon. On the Mac, the
/// helper app inside the bundle (`app_install_macos.dart`); on Linux,
/// `lib/nushid` beside the binary (`app_install_linux.dart`); on Windows,
/// `nushid.exe` beside `nushi.exe` (`app_install_windows.dart`). The
/// phone's web app starts no daemon and never asks.
abstract interface class AppInstall {
  /// The data folder when `NUSHI_DATA` names none: the daemon's own
  /// default, so the app meets the daemon it starts.
  String get dataFolder;

  /// The packaged daemon, null when the app doesn't run from a package
  /// (`flutter run`, tests): then nothing is started or restarted.
  String? get daemon;

  /// The packaged daemon's build, as the daemon tells its own
  /// (PingResponse.build: `<size>-<mtime in ms>` of its program), null
  /// without one.
  String? get daemonBuild;

  /// The app's version, `<version>+<build number>`, "" when it can't say.
  String get version;

  /// How the user stops a daemon that didn't stop when asked, as a
  /// sentence's clause.
  String get stopByHand;

  /// Starts the packaged [daemon] on [dataDir] in the background, where it
  /// outlives the app, as `nushid -login` (Windows starts it without).
  /// It doesn't wait for the daemon to answer.
  Future<void> launch(String dataDir);

  /// Stops the daemon listening in [dataDir], if one is; it doesn't wait
  /// for it to go. [pid] is the daemon's own, as its Ping said (API 122; 0
  /// before, above the floor until it reaches 122: the Mac's and Linux's
  /// stop by the socket goes with the floor then): Windows stops it by the
  /// stop event that pid names (ADR 0134), where the Mac and Linux find it
  /// by its socket.
  Future<void> stop(String dataDir, {int pid = 0});
}

/// Restart daemon, where the app offers it.
extension RestartsDaemon on AppInstall {
  /// Whether the app can restart its daemon: it has one packaged.
  bool get restartsDaemon => daemon != null;
}

/// The daemon's environment: the app's, without Nushi's own variables (a
/// `NUSHID_DATA` or token the app inherited), the data folder for the
/// daemon to keep (`NUSHID_DATA`), and the app's `NUSHI_DATA` when it has
/// one (development), which the daemon's dev mode follows, as the Mac's
/// `openHelper` passes it.
Map<String, String> launchEnvironment(Map<String, String> env, String dir) => {
  ...withoutNushi(env),
  'NUSHID_DATA': dir,
  'NUSHI_DATA': ?env['NUSHI_DATA'],
};

/// [env] without Nushi's own variables, every `NUSHI_*` and `NUSHID_*`:
/// what a program the app starts gets, so a development run's data folder
/// or token never reaches it.
Map<String, String> withoutNushi(Map<String, String> env) => {
  for (final MapEntry(:key, :value) in env.entries)
    if (!key.startsWith('NUSHI_') && !key.startsWith('NUSHID_')) key: value,
};
