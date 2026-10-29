import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:nushi/phone/keyboard_web.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/phone/update_ready.dart';
import 'package:web/web.dart' as web;

/// The browser: IndexedDB for the device's key and pairing and the chats'
/// drafts, the service worker, Web Push, and the page's address (a pairing
/// link or a chat to open arrive in its fragment, which never reaches a
/// server).
final class PhonePlatform {
  new() {
    _fromAddress(starting: true);
    _ownHistory();
    watchKeyboard(keyboard);
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

  /// The on-screen keyboard's height over the app (keyboard_web.dart).
  final keyboard = ValueNotifier<double>(0);

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

  /// Takes the fragment out of the address: in place, never an entry (a
  /// back from the root mustn't reach a pairing link again).
  void _clearHash() => web.window.history.replaceState(
    _entry(_depth),
    '',
    web.window.location.pathname + web.window.location.search,
  );

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
    await saveDrafts(null);
  }

  /// The chats' drafts (phone_drafts.dart), as JSON: the record "drafts".
  Future<String?> loadDrafts() async {
    final v = await _run('readonly', (s) => s.get('drafts'.toJS));
    return v != null && v.isA<JSString>() ? (v as JSString).toDart : null;
  }

  /// Keeps [json] as the drafts; null removes them.
  Future<void> saveDrafts(String? json) async {
    await _run(
      'readwrite',
      (s) => json == null
          ? s.delete('drafts'.toJS)
          : s.put(json.toJS, 'drafts'.toJS),
    );
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
      watchUpdates(
        _reg = await sw.register(trustedScriptUrl('sw.js')).toDart,
        updateReady,
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

  /// Calls [f] when the page comes back other than by showing: restored
  /// from the back-forward cache, or focused.
  void onResume(void Function() f) {
    web.window
      ..addEventListener(
        'pageshow',
        ((web.PageTransitionEvent e) {
          if (e.persisted) f();
        }).toJS,
      )
      ..addEventListener('focus', ((web.Event _) => f()).toJS);
  }

  /// The browser's history as the app's screens (history.dart): the page's
  /// entry is the root (depth 0), and each screen over it has an entry of
  /// its own saying how many screens are over the root there. The address
  /// is the page's own in every one.
  void Function(int depth)? onEntry;

  /// The depth of the entry the browser is at.
  int _depth = 0;

  static JSAny? _entry(int depth) => {'nushi': depth}.jsify();

  /// A screen's entry, over the current one.
  void pushEntry(int depth) {
    _depth = depth;
    web.window.history.pushState(_entry(depth), '');
  }

  /// Back (negative) or forward [delta] entries; [onEntry] says where it
  /// landed.
  void go(int delta) => web.window.history.go(delta);

  void _ownHistory() {
    web.window.history.replaceState(_entry(0), '');
    web.window.addEventListener(
      'popstate',
      ((web.PopStateEvent e) {
        // Only the app's entries: a fragment's navigation (a pairing link
        // coming in) has no state yet, and its fragment is then taken out
        // in place, its entry given the depth it came at.
        final state = e.state;
        if (state == null || !state.isA<JSObject>()) return;
        final depth = (state as JSObject)['nushi'].dartify();
        if (depth is! num) return;
        _depth = depth.toInt();
        onEntry?.call(_depth);
      }).toJS,
    );
  }
}

JSObject? _policy;

/// The app's own scripts a page may start as workers.
const _workers = {'sw.js', 'qr_worker.js'};

/// [name], one of the app's worker scripts, as a Trusted Types script URL
/// where the browser asks for one (the relay's CSP): the policy "nushi"
/// passes those and nothing else.
JSAny trustedScriptUrl(String name) {
  final tt = web.window.getProperty<JSObject?>('trustedTypes'.toJS);
  if (tt == null) return name.toJS;
  final rules = JSObject()
    ..['createScriptURL'] = ((
      JSString u,
    ) => _workers.contains(u.toDart) ? u : throw ArgumentError(u.toDart)).toJS;
  _policy ??= tt.callMethod<JSObject>('createPolicy'.toJS, 'nushi'.toJS, rules);
  return _policy!.callMethod<JSAny>('createScriptURL'.toJS, name.toJS);
}

/// Sets [ready] once a newer version of the app waits in [reg] to replace
/// the running one ([updateWaits]): now, or when one of its workers is
/// installed.
void watchUpdates(
  web.ServiceWorkerRegistration reg,
  ValueNotifier<bool> ready,
) {
  void check() {
    if (updateWaits(waiting: reg.waiting != null, active: reg.active != null)) {
      ready.value = true;
    }
  }

  void watch(web.ServiceWorker? w) => w?.addEventListener(
    'statechange',
    ((web.Event _) {
      if (w.state == 'installed') check();
    }).toJS,
  );
  check();
  watch(reg.installing);
  reg.addEventListener(
    'updatefound',
    ((web.Event _) => watch(reg.installing)).toJS,
  );
}
