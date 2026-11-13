import 'package:flutter/foundation.dart';

// What the app holds in memory while it runs, outside any widget and the
// Daemon: caches, what's half written in a box no longer shown, which
// groups were opened. Each is made by one of these, so a test starts
// without what another left ([forgetRunState], in every test's setUp):
// a new one is forgotten too without anyone listing it. Each registers
// when first read (Dart makes top-level and static values then), so one
// never read has nothing to forget.

final _forgets = <void Function()>[];

/// A map kept while the app runs.
Map<K, V> runMap<K, V>() {
  final m = <K, V>{};
  _forgets.add(m.clear);
  return m;
}

/// A set kept while the app runs.
Set<T> runSet<T>() {
  final s = <T>{};
  _forgets.add(s.clear);
  return s;
}

/// A list kept while the app runs.
List<T> runList<T>() {
  final l = <T>[];
  _forgets.add(l.clear);
  return l;
}

/// A value kept while the app runs, [initial] at first.
ValueNotifier<T> runValue<T>(T initial) {
  final v = ValueNotifier<T>(initial);
  _forgets.add(() => v.value = initial);
  return v;
}

/// Everything made above as it was at first (tests: each starts afresh).
@visibleForTesting
void forgetRunState() {
  for (final forget in _forgets) {
    forget();
  }
}
