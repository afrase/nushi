import 'package:flutter/foundation.dart';

import 'package:nushi/phone/subscription.dart';

/// The browser, in memory: for tests and anything not in a browser.
final class PhonePlatform {
  new();

  /// What [save] kept.
  Map<String, Object?>? saved;

  /// The push subscription [subscribe] made, as a test sets it up.
  PushSub? sub;
  PushState push = PushState.off;
  bool installed = true;
  bool iPhone = false;

  /// A pairing link the page was opened with.
  String? openedWith;

  /// A pairing link that came while the app ran.
  void Function(String link)? onPairLink;

  /// The chat a notification asked to open.
  void Function(String chat)? onOpenChat;

  Future<Map<String, Object?>?> load() async => saved;
  Future<void> save(Map<String, Object?> record) async => saved = record;
  Future<void> clear() async => saved = null;
  Future<void> registerWorker() async {}

  /// Whether a newer version waits (a test sets it).
  final updateReady = ValueNotifier<bool>(false);
  bool updated = false;
  Future<void> checkForUpdate() async {}
  void applyUpdate() => updated = true;

  /// The page's origin's host.
  String host = 'nushi.aaronfrase.com';

  /// What [reset] and [closeNotifications] were asked.
  bool wasReset = false;
  final closed = <String>[];

  /// The VAPID key the subscription was made with.
  Uint8List? subscribedKey;

  Future<void> reset() async => wasReset = true;
  Future<void> closeNotifications(String chat) async => closed.add(chat);
  Future<Uint8List?> subscribedWith() async =>
      push == PushState.on ? subscribedKey : null;
  Future<PushState> pushState() async => push;

  Future<PushSub?> subscribe(Uint8List key) async {
    push = PushState.on;
    subscribedKey = key;
    return sub;
  }

  Future<void> unsubscribe() async => push = PushState.off;
  void onVisible(void Function({required bool visible}) f) {}

  /// Calls [f] when the network comes back.
  void onOnline(void Function() f) {}

  /// Calls [f] when the page comes back from the back-forward cache.
  void onResume(void Function() f) {}

  /// The browser's back, as the app's own.
  void Function()? onBack;

  /// The chat a notification asked to open when the app started, if any.
  String? takeOpenChat() => null;
}
