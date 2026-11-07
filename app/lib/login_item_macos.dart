import 'package:flutter/services.dart';

import 'package:nushi/login_item.dart';

const _channel = MethodChannel('nushi/login');

/// The app's launch agent, which opens the daemon's helper app at login,
/// through SMAppService (`macos/Runner/MainFlutterWindow.swift`).
/// Each call answers SMAppService's status: "enabled", "requiresApproval"
/// (on, until the user allows it in Login Items), "notRegistered", or
/// "notFound" (what macOS says of a job it hasn't seen, before the first
/// register too).
class MacLoginItem implements LoginItem {
  const new();

  @override
  Future<LoginItemState?> status() => _call('status');

  @override
  Future<LoginItemState?> set({required bool on}) => _call('set', on);

  @override
  Future<LoginItemState?> openSettings() => _call('openSettings');

  static Future<LoginItemState?> _call(String method, [Object? arg]) async =>
      switch (await _channel.invokeMethod<String>(method, arg)) {
        null => null,
        'enabled' => LoginItemState.on,
        'requiresApproval' => LoginItemState.needsApproval,
        _ => LoginItemState.off,
      };
}
