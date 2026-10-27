import 'dart:typed_data';

/// A browser's push subscription: what the daemon sends to.
final class PushSub {
  const new(this.endpoint, this.p256dh, this.auth);

  final String endpoint;
  final Uint8List p256dh;
  final Uint8List auth;
}

/// Whether notifications can be, and are, on in this browser.
enum PushState {
  /// The browser has no Web Push here: on an iPhone, Safari outside the
  /// Home Screen app.
  unsupported,

  /// The user said no to notifications for this app.
  denied,
  off,
  on,
}
