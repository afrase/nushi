import 'package:flutter/services.dart';

import 'package:nushi/alerts.dart';

/// The app's Swift side of notifications and the Dock badge
/// (`macos/Runner/Alerts.swift`).
const alertsChannel = MethodChannel('nushi/alerts');

/// The Mac's Notification Center and Dock badge.
class MacAlertCenter implements AlertCenter {
  const new();

  @override
  Future<void> post({
    required String id,
    required String chat,
    required String title,
    required String body,
    required bool sound,
  }) => alertsChannel.invokeMethod<Object?>('post', {
    'id': id,
    'chat': chat,
    'title': title,
    'body': body,
    'sound': sound,
  });

  @override
  Future<void> withdraw(List<String> ids) =>
      alertsChannel.invokeMethod<Object?>('withdraw', ids);

  @override
  Future<void> clear(String chat) =>
      alertsChannel.invokeMethod<Object?>('clear', chat);

  @override
  Future<void> badge(String label) =>
      alertsChannel.invokeMethod<Object?>('badge', label);

  @override
  Future<String?> allowed() => alertsChannel.invokeMethod<String>('status');

  @override
  Future<void> openSettings() =>
      alertsChannel.invokeMethod<void>('openSettings');

  @override
  void onOpen(void Function(String chat)? open) =>
      alertsChannel.setMethodCallHandler(
        open == null
            ? null
            : (call) async {
                if (call.method == 'open' && call.arguments is String) {
                  open(call.arguments as String);
                }
                return null;
              },
      );
}
