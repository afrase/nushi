import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_log.dart';
import 'package:nushi/desktop.dart';
import 'package:nushi/session_bus_linux.dart';

/// The runner's GIO default apps (`linux/runner/gio.cc`).
const _desktop = MethodChannel('nushi/desktop');

/// Linux's file manager and default apps (ADR 0104), never `xdg-open`:
/// a file is shown selected through the file manager's
/// `org.freedesktop.FileManager1` on the session bus (Files, Dolphin,
/// Thunar, Nemo and Caja answer it), else its folder opens; a folder opens
/// with the default app for folders, and a file as text with the default
/// app for plain text (both the runner's `nushi/desktop`, which gives the
/// app none of Nushi's variables). As on the Mac, a failure opens nothing
/// and throws nothing: it's logged.
class LinuxDesktop implements Desktop {
  const new({this._bus});

  /// The bus the file manager is on, once it has answered
  /// ([reachable]): the session bus notifications use too
  /// (`session_bus_linux.dart`), unless a test gives one of its own.
  final Future<DBusClient?>? _bus;

  @override
  Future<void> reveal(String path) async {
    // A bus that can't be reached opens the folder at once.
    final bus = await (_bus ?? reachedSessionBus);
    if (bus == null) {
      await openFolder(File(path).parent.path);
      return;
    }
    try {
      await bus
          .callMethod(
            destination: 'org.freedesktop.FileManager1',
            path: DBusObjectPath('/org/freedesktop/FileManager1'),
            interface: 'org.freedesktop.FileManager1',
            name: 'ShowItems',
            values: [
              DBusArray.string(['${Uri.file(path)}']),
              // No startup id: the file manager raises its window as it can.
              const DBusString(''),
            ],
            replySignature: DBusSignature.empty,
          )
          .timeout(const Duration(seconds: 10));
    } on Object {
      // No file manager answers it in 10 s (none that has it, or one slow
      // to start): the folder shows, without the file selected.
      await openFolder(File(path).parent.path);
    }
  }

  @override
  Future<void> openFolder(String folder) => _open('openFolder', folder);

  @override
  Future<void> openAsText(String path) => _open('openAsText', path);

  /// Asks the runner to [call] on [path]; a refusal is logged by its code
  /// alone, never the path, which may name the user's work.
  static Future<void> _open(String call, String path) async {
    try {
      await _desktop.invokeMethod<void>(call, path);
    } on PlatformException catch (e) {
      appLog.warn('the desktop opened nothing', {'call': call, 'code': e.code});
    }
  }
}
