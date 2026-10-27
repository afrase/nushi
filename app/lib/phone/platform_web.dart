import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:web/web.dart' as web;

/// The browser: IndexedDB for the device's key and pairing, the service
/// worker, Web Push, and the page's address (a pairing link or a chat to
/// open arrive in its fragment, which never reaches a server).
final class PhonePlatform {
  new() {
    _fromAddress(starting: true);
    web.window.addEventListener(
      'hashchange',
      ((web.Event _) => _fromAddress(starting: false)).toJS,
    );
    if (_has(web.window.navigator, 'serviceWorker')) {
      web.window.navigator.serviceWorker.addEventListener(
        'message',
        ((web.MessageEvent e) {
          final data = e.data;
          if (data != null && data.isA<JSObject>()) {
            final chat = (data as JSObject)['chat'];
            if (chat != null && chat.isA<JSString>()) {
              final id = (chat as JSString).toDart;
              if (_chatId.hasMatch(id)) onOpenChat?.call(id);
            }
          }
        }).toJS,
      );
    }
  }

  /// A chat's id, as the daemon makes them.
  static final _chatId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Takes a pairing link or a chat to open out of the address, so the
  /// secret doesn't stay in it or in the history.
  void _fromAddress({required bool starting}) {
    final hash = web.window.location.hash;
    if (hash.startsWith('#pair?')) {
      openedWith = web.window.location.href;
      _clearHash();
      if (!starting) onPairLink?.call(openedWith!);
    } else if (hash.startsWith('#chat=')) {
      _clearHash();
      final id = hash.substring(6); // an id needs no decoding
      if (!_chatId.hasMatch(id)) return;
      if (starting) {
        _openChat = id;
      } else {
        onOpenChat?.call(id);
      }
    }
  }

  /// A pairing link the page was opened with (a Mac's "Copy link" opened
  /// in the browser), taken out of the address.
  String? openedWith;

  /// A pairing link that came while the app ran.
  void Function(String link)? onPairLink;
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

  static const _fields = [
    'key',
    'name',
    'relay',
    'daemon',
    'daemonKey',
    'seen',
  ];

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

  /// The page's origin's host, to tell a pairing link for another relay.
  String get host => web.window.location.host;

  /// Registers the service worker: the app's shell offline, and
  /// notifications. A newer version it finds installs beside the running
  /// one and waits: [updateReady] says so, and [applyUpdate] reloads into
  /// it (never a page half on one version, half on the next).
  Future<void> registerWorker() async {
    if (!_has(web.window.navigator, 'serviceWorker')) return;
    final sw = web.window.navigator.serviceWorker;
    try {
      final reg = _reg = await sw.register(_workerUrl()).toDart;
      void watch(web.ServiceWorker? w) => w?.addEventListener(
        'statechange',
        ((web.Event _) {
          if (w.state == 'installed' && sw.controller != null) {
            updateReady.value = true;
          }
        }).toJS,
      );
      if (reg.waiting != null && sw.controller != null) {
        updateReady.value = true;
      }
      watch(reg.installing);
      reg.addEventListener(
        'updatefound',
        ((web.Event _) => watch(reg.installing)).toJS,
      );
      sw.addEventListener(
        'controllerchange',
        ((web.Event _) {
          if (_reloading) web.window.location.reload();
        }).toJS,
      );
    } on Object {
      // Without it the app still works, without notifications.
    }
  }

  web.ServiceWorkerRegistration? _reg;
  bool _reloading = false;
  DateTime _checked = DateTime(0);

  /// Whether a newer version is installed and waits for a reload.
  final updateReady = ValueNotifier<bool>(false);

  /// Asks the server for a newer version (a Home Screen app that comes back
  /// to the front isn't a navigation, which is when browsers look), at
  /// most every ten minutes.
  Future<void> checkForUpdate() async {
    if (DateTime.now().difference(_checked).inMinutes < 10) return;
    _checked = DateTime.now();
    try {
      await _reg?.update().toDart;
    } on Object {
      // Offline: looked for next time.
    }
  }

  /// Reloads into the version that waits.
  void applyUpdate() {
    final waiting = _reg?.waiting;
    if (waiting == null) return web.window.location.reload();
    _reloading = true;
    waiting.postMessage('skipWaiting'.toJS);
  }

  static JSObject? _policy;

  /// The service worker's address, as a Trusted Types script URL where the
  /// browser asks for one (the relay's CSP): the policy "nushi" passes
  /// sw.js and nothing else.
  static JSAny _workerUrl() {
    final tt = web.window.getProperty<JSObject?>('trustedTypes'.toJS);
    if (tt == null) return 'sw.js'.toJS;
    final rules = JSObject()
      ..['createScriptURL'] = ((
        JSString u,
      ) => u.toDart == 'sw.js' ? u : throw ArgumentError(u.toDart)).toJS;
    _policy ??= tt.callMethod<JSObject>(
      'createPolicy'.toJS,
      'nushi'.toJS,
      rules,
    );
    return _policy!.callMethod<JSAny>('createScriptURL'.toJS, 'sw.js'.toJS);
  }

  /// Unregisters the service worker and empties its caches: Forget leaves
  /// nothing that a script once run here could have changed.
  Future<void> reset() async {
    try {
      final keys = await web.window.caches.keys().toDart;
      for (final k in keys.toDart) {
        await web.window.caches.delete(k.toDart).toDart;
      }
      if (_has(web.window.navigator, 'serviceWorker')) {
        final reg = await web.window.navigator.serviceWorker
            .getRegistration()
            .toDart;
        await reg?.unregister().toDart;
      }
    } on Object {
      // Best effort: the next build's worker replaces its caches anyway.
    }
  }

  /// Closes the notifications about [chat]: it's open.
  Future<void> closeNotifications(String chat) async {
    try {
      final reg = await web.window.navigator.serviceWorker
          .getRegistration()
          .toDart;
      final ns = await reg?.getNotifications().toDart;
      for (final n in ns?.toDart ?? <web.Notification>[]) {
        final data = n.data;
        if (data != null &&
            data.isA<JSObject>() &&
            (data as JSObject)['chat'].dartify() == chat) {
          n.close();
        }
      }
    } on Object {
      // Nothing to close.
    }
  }

  /// The VAPID key the push subscription was made with, if there's one.
  Future<Uint8List?> subscribedWith() async {
    if (!_pushable) return null;
    final reg = await web.window.navigator.serviceWorker
        .getRegistration()
        .toDart;
    final sub = await reg?.pushManager.getSubscription().toDart;
    return sub?.options.applicationServerKey?.toDart.asUint8List();
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

  /// Calls [f] when the network comes back.
  void onOnline(void Function() f) =>
      web.window.addEventListener('online', ((web.Event _) => f()).toJS);
}
