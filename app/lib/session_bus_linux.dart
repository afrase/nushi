import 'dart:io';

import 'package:dbus/dbus.dart';

/// The user's D-Bus session bus, which Linux's notifications, badge and
/// Show in Folder reach the desktop over (ADR 0104), or null when there's
/// none to find.
/// The client connects on its first call, so a bus it can't reach never
/// holds up the app's start; what uses it asks [reachedSessionBus].
final DBusClient? sessionBus = sessionBusAt(Platform.environment);

/// [sessionBus] once it has answered a ping, or null: pinged once, when
/// first asked for, for the notifications and Show in Folder alike.
final Future<DBusClient?> reachedSessionBus = reachable(sessionBus);

/// [bus] once it has answered a ping (5 s at most), else null, closed:
/// package:dbus (0.7.15) leaves a client whose first connection failed
/// waiting for good on every later call, and throws that failure where a
/// signal stream subscribes, so nothing else is asked of it before it
/// answers.
Future<DBusClient?> reachable(DBusClient? bus) async {
  if (bus == null) return null;
  try {
    await bus.ping().timeout(const Duration(seconds: 5));
    return bus;
  } on Object {
    bus.close().ignore();
    return null;
  }
}

/// A client of the session bus [environment] names: its
/// `DBUS_SESSION_BUS_ADDRESS` (the first address of a list), else the
/// socket in `XDG_RUNTIME_DIR`, as the daemon's keychain finds it (ADR
/// 0101); null with neither. Never a bus of Nushi's own.
DBusClient? sessionBusAt(Map<String, String> environment) {
  final runtime = environment['XDG_RUNTIME_DIR'] ?? '';
  final address = switch (environment['DBUS_SESSION_BUS_ADDRESS']) {
    final a? when a.isNotEmpty => a.split(';').first,
    _ when runtime.startsWith('/') => 'unix:path=$runtime/bus',
    _ => null,
  };
  if (address == null) return null;
  try {
    return DBusClient(DBusAddress(address));
  } on FormatException {
    return null;
  }
}
