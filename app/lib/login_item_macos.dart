import 'package:flutter/services.dart';

import 'package:nushi/login_item.dart';

const _channel = MethodChannel('nushi/login');

/// The app's launch agent, which opens the daemon's helper app at login,
/// through SMAppService (`macos/Runner/MainFlutterWindow.swift`).
class MacLoginItem implements LoginItem {
  const new();

  @override
  Future<String?> status() => _channel.invokeMethod<String>('status');

  @override
  Future<String?> set({required bool on}) =>
      _channel.invokeMethod<String>('set', on);

  @override
  Future<String?> openSettings() =>
      _channel.invokeMethod<String>('openSettings');
}
