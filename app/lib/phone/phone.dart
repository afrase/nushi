import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/link.dart';
import 'package:nushi/phone/phone_drafts.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/widgets.dart' show errorText;
import 'package:remote_transport/remote_transport.dart' as rt;

/// Where pairing stands while it runs: the code to compare with the Mac's.
final class PairingCode {
  new(this.code);

  final String code;
}

/// The phone (ADR 0054): its key and the Mac it's paired with, kept in the
/// browser's storage, and while paired, the [Daemon] it reaches through
/// the relay.
class Phone extends ChangeNotifier {
  new(this.platform, {this.connectTo, this.sameRelay = true});

  final PhonePlatform platform;

  /// Makes the Daemon for a paired Mac; tests give their own.
  final Daemon Function(connect.Transport transport)? connectTo;

  /// Whether a pairing link must name the relay that serves this page (a
  /// test's page comes from elsewhere): a link for another relay can't
  /// work here (the CSP) and would pair in the wrong place.
  final bool sameRelay;

  /// Whether the page shows, and the timer that keeps telling the daemon
  /// which chat does (its word lapses, ViewLease in the daemon).
  bool _visible = true;
  Timer? _viewing;

  /// Whether the stored pairing has been read.
  bool loaded = false;

  /// This device's key: made once, kept in the browser's storage.
  rt.KeyPair? _key;

  /// The name the Mac knows this device by.
  String name = '';

  /// The Mac it's paired with; null until paired.
  rt.PairedDaemon? paired;

  /// The link to the paired Mac's daemon.
  Daemon? daemon;

  /// The chats' drafts, kept in the browser's storage across reloads.
  late final drafts = Drafts(PhoneDrafts(platform));
  rt.RelayTransport? _transport;

  /// What keeps it up, and says how it stands.
  Link? link;

  /// When the Mac last answered, kept across launches.
  DateTime? _seen;

  /// A pairing under way, once it has its code.
  PairingCode? pairing;

  /// The daemon's VAPID key, asked for once connected, so a tap on
  /// Notifications can subscribe at once (iOS asks only from a tap).
  Uint8List? _pushKey;

  /// Whether notifications are on here, as the browser says.
  PushState push = PushState.off;

  /// Reads the stored pairing and, if there's one, connects.
  Future<void> start() async {
    platform
      ..onVisible(({required visible}) {
        _visible = visible;
        link?.visible(shown: visible);
        if (!visible) unawaited(drafts.flush());
        if (visible) unawaited(platform.checkForUpdate());
        unawaited(view(visible ? daemon?.selectedId : null));
      })
      ..onOnline(() => link?.online())
      ..onResume(() => link?.resume());
    try {
      final r = await platform.load();
      if (r != null) {
        if (r['key'] case final Uint8List k when k.length == 32) {
          _key = await rt.KeyPair.make(k);
        }
        name = r['name'] as String? ?? '';
        _seen = DateTime.tryParse(r['seen'] as String? ?? '');
        final relay = Uri.tryParse(r['relay'] as String? ?? '');
        final id = r['daemon'] as String? ?? '';
        if (r['daemonKey'] case final Uint8List dk
            when dk.length == 32 &&
                relay != null &&
                id.isNotEmpty &&
                _key != null) {
          paired = rt.PairedDaemon(relay, id, dk);
        }
      }
    } on Object {
      // Nothing usable kept: pair again.
    }
    loaded = true;
    if (paired != null) _connect(rt.RelayTransport(paired!, _key!));
    notifyListeners();
    try {
      push = await platform.pushState();
    } on Object {
      push = PushState.unsupported;
    }
    notifyListeners();
  }

  /// Keeps the key and pairing, unless another tab (or an older run) has
  /// since kept another key: this one's then stale, and writing it would
  /// bring back a key that was forgotten or replaced.
  Future<void> _save() async {
    if (_forgetting) return;
    final kept = (await platform.load())?['key'];
    if (_forgetting) return;
    final mine = _key?.private;
    if (kept is Uint8List && (mine == null || !_same(kept, mine))) return;
    await platform.save({
      'key': mine,
      'name': name,
      if (_seen case final seen?) 'seen': seen.toIso8601String(),
      if (paired case final p?) ...{
        'relay': p.relay.toString(),
        'daemon': p.id,
        'daemonKey': p.key,
      },
    });
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  /// Pairs with the Mac whose link (or QR code's text) is [link], as
  /// [deviceName]. [pairing] shows the code meanwhile; it throws when the
  /// Mac refuses or doesn't answer.
  Future<void> pair(String link, String deviceName) async {
    final offer = rt.PairingOffer.parse(link);
    if (sameRelay && offer.relay.authority != platform.host) {
      throw FormatException(
        'This link is for the relay at ${offer.relay.authority}: open Nushi '
        'from there',
      );
    }
    _key ??= await rt.KeyPair.make();
    name = deviceName.trim().isEmpty ? 'Phone' : deviceName.trim();
    await _save(); // the key, before any Mac knows it
    try {
      final (daemon, transport) = await rt.pair(
        offer,
        device: _key!,
        name: name,
        kind: 'web',
        onCode: (code) {
          pairing = PairingCode(code);
          notifyListeners();
        },
      );
      paired = daemon;
      await _save();
      _connect(transport);
    } finally {
      pairing = null;
      notifyListeners();
    }
  }

  void _connect(rt.RelayTransport transport) {
    _transport = transport;
    final t = protocol.Transport(
      baseUrl: 'http://nushid',
      codec: const ProtoCodec(),
      httpClient: createHttpClient(transport: transport),
      // The daemon gzips what's over 1 KiB for a client that asks: a long
      // chat's transcript comes in about a third of the bytes.
      acceptCompressions: const [rt.Gzip()],
    );
    final d = daemon =
        (connectTo?.call(t) ??
              Daemon(transport: t, remote: true, drafts: drafts))
          ..addListener(_daemonChanged);
    link = Link(
      d,
      reset: transport.reset,
      live: () => transport.live,
      seen: _seen,
      onSeen: (seen) {
        // Kept once a minute at most: it's for "last seen" after a relaunch.
        final was = _seen;
        _seen = seen;
        if (was == null || seen.difference(was).inMinutes >= 1) {
          unawaited(_save().catchError((Object _) {}));
        }
      },
    )..start();
    remoteState.addListener(_remoteChanged);
    platform.onOpenChat = (chat) => opening.value = chat;
    _viewing?.cancel();
    _viewing = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_visible && d.selectedId != null) unawaited(view(d.selectedId));
    });
    if (platform.takeOpenChat() case final chat?) opening.value = chat;
  }

  var _wasConnected = false;

  void _daemonChanged() {
    final d = daemon;
    if (d == null || d.connected == _wasConnected) return;
    _wasConnected = d.connected;
    if (d.connected) {
      unawaited(_askPushKey(d));
      unawaited(view(d.selectedId)); // a new connection knows no view
    }
  }

  Future<void> _askPushKey(Daemon d) async {
    try {
      final key = (await d.client.getPushKey(GetPushKeyRequest())).key;
      final k = _pushKey = key.isEmpty
          ? null
          : base64Url.decode(key.padRight((key.length + 3) ~/ 4 * 4, '='));
      // A subscription made with another key (the daemon's was made anew)
      // gets nothing: it's off until turned on again.
      final made = await platform.subscribedWith();
      if (k != null && made != null && !_same(made, k)) {
        await platform.unsubscribe();
        push = await platform.pushState();
      }
      notifyListeners();
    } on Object {
      // Asked again on the next connection.
    }
  }

  /// The daemon moved to another id (another device was revoked): dial
  /// that one from now on (ADR 0034).
  void _remoteChanged() {
    final r = remoteState.value;
    final p = paired;
    final id = r?.rendezvous ?? '';
    if (p == null || id.isEmpty || id == p.id) return;
    paired = rt.PairedDaemon(p.relay, id, p.key);
    _transport?.daemon = paired!;
    unawaited(_save());
  }

  /// The chat a notification asked to open, until the app opens it.
  final opening = ValueNotifier<String?>(null);

  /// Opens [chatId] (shown on its screen): the daemon knows it shows.
  void open(String chatId) {
    daemon?.select(chatId);
    unawaited(view(chatId));
    unawaited(platform.closeNotifications(chatId));
    notifyListeners();
  }

  /// Tells the daemon which chat shows ("" none): no push for it while it
  /// does.
  Future<void> view(String? chatId) async {
    final d = daemon;
    if (d == null || !d.connected) return;
    try {
      await d.client.setDeviceView(SetDeviceViewRequest(chatId: chatId ?? ''));
    } on Object {
      // Not connected: no view to keep.
    }
  }

  /// Whether a tap can turn notifications on now.
  bool get canPush => _pushKey != null && push != PushState.unsupported;

  /// Turns notifications on or off; call it straight from a tap. Says why
  /// not, if it couldn't.
  Future<String?> setPush({required bool on}) async {
    final d = daemon;
    if (d == null) return 'Not paired';
    try {
      if (on) {
        final key = _pushKey;
        if (key == null) return 'Not connected to the Mac';
        final sub = await platform.subscribe(key);
        push = await platform.pushState();
        notifyListeners();
        if (sub == null) {
          return push == PushState.denied
              ? 'Notifications are off for Nushi in Settings › Notifications'
              : 'Notifications were not allowed';
        }
        await d.client.setPushSubscription(
          SetPushSubscriptionRequest(
            endpoint: sub.endpoint,
            p256dh: sub.p256dh,
            auth: sub.auth,
          ),
        );
      } else {
        await platform.unsubscribe();
        await d.client.setPushSubscription(SetPushSubscriptionRequest());
        push = await platform.pushState();
        notifyListeners();
      }
      return null;
    } on Object catch (e) {
      return errorText(e);
    }
  }

  /// Ends the link to the Mac (the page goes), keeping the pairing.
  Future<void> close() async {
    _viewing?.cancel();
    _viewing = null;
    link?.dispose();
    link = null;
    remoteState.removeListener(_remoteChanged);
    daemon
      ?..removeListener(_daemonChanged)
      ..dispose();
    daemon = null;
    final t = _transport;
    _transport = null;
    await t?.close();
  }

  /// Forgets the Mac: notifications off, the pairing and the key gone. The
  /// Mac still lists this device until it's revoked there. Once at a time:
  /// asked again meanwhile, it's the same forget.
  Future<void> forget() {
    if (_forgetRun case final run?) return run;
    final run = _forgetRun = _forget().whenComplete(() {
      _forgetRun = null;
      notifyListeners();
    });
    notifyListeners();
    return run;
  }

  Future<void>? _forgetRun;

  /// Whether [forget] runs.
  bool get forgetting => _forgetRun != null;

  Future<void> _forget() async {
    // Nothing may write the pairing back meanwhile (a ping answering would
    // keep the last-seen time, and with it the key).
    // A failure on the way (the storage) leaves it as it was: kept again.
    _forgetting = true;
    try {
      link?.dispose();
      link = null;
      // The link is gone: a Mac that doesn't answer doesn't hold it up
      // (unpairing drops the subscription too).
      if (push == PushState.on) {
        await setPush(on: false)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      }
      // The Mac forgets this device too, if it can be reached (else it
      // still lists it until it's revoked there).
      try {
        await daemon?.client
            .unpairThisDevice(UnpairThisDeviceRequest())
            .timeout(const Duration(seconds: 5));
      } on Object {
        // Not connected: Revoke on the Mac.
      }
      // The drafts too.
      drafts.ids.toList().forEach(drafts.forget);
      await drafts.flush();
      // The storage first: if it fails, nothing here looks forgotten.
      await platform.clear();
      await platform.reset();
      await close();
      paired = _key = _pushKey = null;
      remoteState.value = null;
      push = await platform.pushState();
    } finally {
      _forgetting = false;
    }
    notifyListeners();
  }

  bool _forgetting = false;
}
