import 'package:fixnum/fixnum.dart';

/// The time the app sees in every test (`clock`, set before each by
/// `flutter_test_config.dart`): fixed, so an age a golden shows never moves.
/// Here, not in harness.dart, so what the browser's tests share (the
/// fake daemon) can count from it without the desktop's native edge.
final fixtureNow = DateTime(2026, 10, 29, 12);

/// [fixtureNow] less [d], as the daemon sends a time.
Int64 msAgo(Duration d) => Int64(fixtureNow.subtract(d).millisecondsSinceEpoch);
