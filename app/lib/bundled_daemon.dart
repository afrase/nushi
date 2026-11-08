import 'package:nushi/app_log.dart';
import 'package:nushi/native.dart';

/// When a daemon build (`<size>-<mtime in ms>`) was made, if it says.
DateTime? buildTime(String build) => switch (int.tryParse(
  build.split('-').last,
)) {
  final ms? when build.contains('-') => DateTime.fromMillisecondsSinceEpoch(ms),
  _ => null,
};

/// Starts the bundled daemon when none answers.
class Launcher {
  DateTime launched = DateTime(0); // when it last started it
  int launches = 0; // starts since the daemon last answered

  /// Starts the bundled daemon on [dataDir] ([Native.install]), at most
  /// every ten seconds; it outlives the app. Says whether it tried.
  bool launch(String dataDir) {
    final install = native.install;
    if (install.daemon == null ||
        DateTime.now().difference(launched).inSeconds < 10) {
      return false;
    }
    launched = DateTime.now();
    launches++;
    appLog.info('starting the bundled daemon', {'try': '$launches'});
    install.launch(dataDir).ignore();
    return true;
  }
}
