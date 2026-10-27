import 'dart:typed_data';

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

  /// The chat a notification asked to open.
  void Function(String chat)? onOpenChat;

  Future<Map<String, Object?>?> load() async => saved;
  Future<void> save(Map<String, Object?> record) async => saved = record;
  Future<void> clear() async => saved = null;
  Future<void> registerWorker() async {}
  Future<PushState> pushState() async => push;

  Future<PushSub?> subscribe(Uint8List key) async {
    push = PushState.on;
    return sub;
  }

  Future<void> unsubscribe() async => push = PushState.off;
  void onVisible(void Function({required bool visible}) f) {}

  /// The chat a notification asked to open when the app started, if any.
  String? takeOpenChat() => null;
}
