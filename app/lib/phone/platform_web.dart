import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:nushi/phone/subscription.dart';
import 'package:web/web.dart' as web;

/// The browser: IndexedDB for the device's key and pairing, the service
/// worker, Web Push, and the page's address (a pairing link or a chat to
/// open arrive in its fragment, which never reaches a server).
final class PhonePlatform {
  new() {
    final hash = web.window.location.hash;
    if (hash.startsWith('#pair?')) {
      openedWith = web.window.location.href;
      _clearHash(); // the secret doesn't stay in the address or history
    } else if (hash.startsWith('#chat=')) {
      _openChat = Uri.decodeComponent(hash.substring(6));
      _clearHash();
    }
    web.window.addEventListener(
      'hashchange',
      ((web.Event _) {
        final h = web.window.location.hash;
        if (h.startsWith('#chat=')) {
          _clearHash();
          onOpenChat?.call(Uri.decodeComponent(h.substring(6)));
        }
      }).toJS,
    );
    if (_has(web.window.navigator, 'serviceWorker')) {
      web.window.navigator.serviceWorker.addEventListener(
        'message',
        ((web.MessageEvent e) {
          final data = e.data;
          if (data != null && data.isA<JSObject>()) {
            final chat = (data as JSObject)['chat'];
            if (chat != null && chat.isA<JSString>()) {
              onOpenChat?.call((chat as JSString).toDart);
            }
          }
        }).toJS,
      );
    }
  }

  /// A pairing link the page was opened with (a Mac's "Copy link" opened
  /// in the browser), taken out of the address.
  String? openedWith;
  String? _openChat;

  /// The chat a notification asked to open while the app ran.
  void Function(String chat)? onOpenChat;

  /// The chat a notification asked to open when the app started, if any.
  String? takeOpenChat() {
    final c = _openChat;
    _openChat = null;
    return c;
  }

  static void _clearHash() =>
      web.window.history.replaceState(null, '', web.window.location.pathname);

  static bool _has(JSObject o, String name) => o.has(name);

  /// Whether it runs from the Home Screen (or as an installed app), not in
  /// a browser's tab.
  bool get installed =>
      web.window.matchMedia('(display-mode: standalone)').matches ||
      (web.window.navigator as JSObject)['standalone'].dartify() == true;

  /// Whether it's an iPhone's or iPad's browser.
  bool get iPhone {
    final ua = web.window.navigator.userAgent;
    return ua.contains('iPhone') ||
        ua.contains('iPad') ||
        ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
  }

  // IndexedDB: one record, "phone", in the store "state" of the database
  // "nushi".
  Future<web.IDBDatabase> _db() {
    final done = Completer<web.IDBDatabase>();
    final req = web.window.indexedDB.open('nushi', 1);
    req
      ..onupgradeneeded = ((web.Event _) {
        (req.result! as web.IDBDatabase).createObjectStore('state');
      }).toJS
      ..onsuccess = ((web.Event _) {
        done.complete(req.result! as web.IDBDatabase);
      }).toJS
      ..onerror = ((web.Event _) {
        done.completeError(StateError("can't open this app's storage"));
      }).toJS;
    return done.future;
  }

  Future<JSAny?> _run(
    String mode,
    web.IDBRequest Function(web.IDBObjectStore s) op,
  ) async {
    final db = await _db();
    try {
      final done = Completer<JSAny?>();
      final req = op(db.transaction('state'.toJS, mode).objectStore('state'));
      req
        ..onsuccess = ((web.Event _) => done.complete(req.result)).toJS
        ..onerror = ((web.Event _) {
          done.completeError(StateError("this app's storage failed"));
        }).toJS;
      return await done.future;
    } finally {
      db.close();
    }
  }

  /// The record [save] kept: the device's key, its name and the Mac it's
  /// paired with.
  Future<Map<String, Object?>?> load() async {
    final v = await _run('readonly', (s) => s.get('phone'.toJS));
    if (v == null || !v.isA<JSObject>()) return null;
    final o = v as JSObject;
    Object? field(String k) {
      final f = o[k];
      if (f == null) return null;
      if (f.isA<JSUint8Array>()) return (f as JSUint8Array).toDart;
      if (f.isA<JSString>()) return (f as JSString).toDart;
      return null;
    }

    return {for (final k in _fields) k: field(k)};
  }

  static const _fields = ['key', 'name', 'relay', 'daemon', 'daemonKey'];

  /// Keeps [record]: strings and bytes (a Uint8Array each, so the key is
  /// never text).
  Future<void> save(Map<String, Object?> record) async {
    final o = JSObject();
    for (final k in _fields) {
      switch (record[k]) {
        case final Uint8List b:
          o[k] = b.toJS;
        case final String s:
          o[k] = s.toJS;
      }
    }
    await _run('readwrite', (s) => s.put(o, 'phone'.toJS));
  }

  Future<void> clear() async {
    await _run('readwrite', (s) => s.delete('phone'.toJS));
  }

  /// Registers the service worker: the app's shell offline, and
  /// notifications.
  Future<void> registerWorker() async {
    if (!_has(web.window.navigator, 'serviceWorker')) return;
    try {
      await web.window.navigator.serviceWorker.register('sw.js'.toJS).toDart;
    } on Object {
      // Without it the app still works, without notifications.
    }
  }

  bool get _pushable =>
      _has(web.window, 'Notification') &&
      _has(web.window, 'PushManager') &&
      _has(web.window.navigator, 'serviceWorker');

  Future<PushState> pushState() async {
    if (!_pushable) return PushState.unsupported;
    if (web.Notification.permission == 'denied') return PushState.denied;
    // Not `ready`, which waits for good while no worker is registered.
    final reg = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart;
    final sub = await reg?.pushManager.getSubscription().toDart;
    return sub == null ? PushState.off : PushState.on;
  }

  /// The service worker's registration, once it's active (10 s at most).
  Future<web.ServiceWorkerRegistration> _ready() => web
      .window
      .navigator
      .serviceWorker
      .ready
      .toDart
      .timeout(const Duration(seconds: 10));

  /// Asks for notifications and subscribes with the daemon's VAPID [key].
  /// Call it straight from a tap: iOS asks only then.
  Future<PushSub?> subscribe(Uint8List key) async {
    if (!_pushable) return null;
    // First, before anything else waits: the tap allows the prompt.
    final asked = web.Notification.requestPermission().toDart;
    if ((await asked).toDart != 'granted') return null;
    final reg = await _ready();
    var sub = await reg.pushManager.getSubscription().toDart;
    sub ??= await reg.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: key.toJS,
          ),
        )
        .toDart;
    final p256dh = sub.getKey('p256dh');
    final auth = sub.getKey('auth');
    if (p256dh == null || auth == null) return null;
    return PushSub(
      sub.endpoint,
      p256dh.toDart.asUint8List(),
      auth.toDart.asUint8List(),
    );
  }

  Future<void> unsubscribe() async {
    if (!_pushable) return;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart;
    final sub = await reg?.pushManager.getSubscription().toDart;
    await sub?.unsubscribe().toDart;
  }

  /// Calls [f] when the page shows or hides.
  void onVisible(void Function({required bool visible}) f) =>
      web.document.addEventListener(
        'visibilitychange',
        ((web.Event _) => f(
          visible: web.document.visibilityState == 'visible',
        )).toJS,
      );
}
