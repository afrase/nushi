/// The installed app as the daemon's launcher sees it (ADR 0036, 0102):
/// where the data folder is, the daemon packaged with the app, the app's
/// version, and starting and stopping that daemon. On the Mac, the
/// helper app inside the bundle (`app_install_macos.dart`); on Linux,
/// `lib/nushid` beside the binary (`app_install_linux.dart`). The phone's
/// web app starts no daemon and never asks.
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
  /// outlives the app, through the user's login shell (`nushid -login`).
  /// It doesn't wait for the daemon to answer.
  Future<void> launch(String dataDir);

  /// Stops the daemon listening in [dataDir], if one is; it doesn't wait
  /// for it to go.
  Future<void> stop(String dataDir);
}
