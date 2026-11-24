import 'dart:async';

import 'package:flutter/foundation.dart';

/// The months' names, January first; a short date takes each one's first
/// three letters ("Nov").
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// [n] in two digits, as a date or a clock writes it: 7 as "07".
String two(int n) => '$n'.padLeft(2, '0');

/// The time now, for what the app shows counted from it (an age, "Updated
/// 3m ago", a pull request's last look); tests set their own, a fixed one
/// before each (`flutter_test_config.dart`), so a golden's ages never move.
DateTime Function() clock = DateTime.now;

/// The one clock what shows a running time ticks on (`LiveText`, a
/// turn's status): it tells its listeners once a second while any
/// listens, and stops as the last leaves, so no row keeps a timer of its
/// own.
final secondClock = _Ticker(const Duration(seconds: 1));

/// The one clock what shows an age ticks on ("2m ago": the sidebar's rows
/// and Date groups, the artifacts, Settings › Updates): once a minute
/// while any listens, as [secondClock].
final minuteClock = _Ticker(const Duration(minutes: 1));

class _Ticker extends ChangeNotifier {
  new(this.every);

  /// How often it tells its listeners.
  final Duration every;
  Timer? _timer;

  /// Whether it ticks: something listens.
  @visibleForTesting
  bool get ticking => _timer != null;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(every, (_) => notifyListeners());
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (hasListeners) return;
    _timer?.cancel();
    _timer = null;
  }
}
