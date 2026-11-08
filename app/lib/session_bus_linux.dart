import 'dart:io';

import 'package:dbus/dbus.dart';

/// The user's D-Bus session bus, which Linux's notifications and badge
/// reach the desktop over (ADR 0102), or null when there's none to find.
/// The client connects on its first call, so a bus it can't reach never
/// holds up the app's start; `LinuxAlertCenter` pings it before anything
/// else, as such a client answers nothing after its first failure.
final DBusClient? sessionBus = sessionBusAt(Platform.environment);

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
