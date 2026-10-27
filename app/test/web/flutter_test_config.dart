import 'dart:async';

/// The browser's tests have no goldens: the VM's config (one folder up)
/// doesn't compile for the web, and this one, nearer, takes its place.
Future<void> testExecutable(FutureOr<void> Function() testMain) async =>
    await testMain();
