import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_log.dart';
import 'package:nushi/desktop.dart';
import 'package:nushi/session_bus_linux.dart';
import 'package:url_launcher/url_launcher.dart';

/// The runner's GIO default apps (`linux/runner/gio.cc`).
const _desktop = MethodChannel('nushi/desktop');

/// Linux's file manager and default apps (ADR 0102), never `xdg-open`:
/// a file is shown selected through the file manager's
/// `org.freedesktop.FileManager1` on the session bus (Files, Dolphin,
/// Thunar, Nemo and Caja answer it), else its folder opens; a folder opens
/// with GIO's default app for folders (url_launcher), and a file as text
/// with the default app for plain text (the runner's `nushi/desktop`). As
/// on the Mac, a failure opens nothing and throws nothing: it's logged.
class LinuxDesktop implements Desktop {
  const new({this._bus, this.launch = launchUrl});

  /// The bus the file manager is on: the session bus notifications use too
  /// (`session_bus_linux.dart`), unless a test gives one of its own.
  final DBusClient? _bus;

  /// Opens a URL with its default app: url_launcher's.
  final Future<bool> Function(Uri url) launch;

  @override
  Future<void> reveal(String path) async {
    final bus = _bus ?? sessionBus;
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
      // No file manager answers it (none that has it, or a bus that can't
      // be reached: package:dbus throws strings for a bus it can't reach or
      // sign in to, and leaves a client whose connection failed waiting for
      // good after that): the folder shows, without the file selected.
      await openFolder(File(path).parent.path);
    }
  }

  @override
  Future<void> openFolder(String folder) async {
    try {
      if (!await launch(Uri.directory(folder))) _failed('openFolder');
    } on PlatformException catch (e) {
      _failed('openFolder', e.code);
    }
  }

  @override
  Future<void> openAsText(String path) async {
    try {
      await _desktop.invokeMethod<void>('openAsText', path);
    } on PlatformException catch (e) {
      _failed('openAsText', e.code);
    }
  }

  /// Logs that [call] opened nothing, by its error's [code] alone: never
  /// the path, which may name the user's work.
  static void _failed(String call, [String code = '']) =>
      appLog.warn('the desktop opened nothing', {'call': call, 'code': code});
}
