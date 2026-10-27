import 'dart:async';
import 'dart:convert';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/subscription.dart';
import 'package:nushi/remote.dart';
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
  new(this.platform, {this.connectTo});

  final PhonePlatform platform;

  /// Makes the Daemon for a paired Mac; tests give their own.
  final Daemon Function(connect.Transport transport)? connectTo;

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
  rt.RelayTransport? _transport;

  /// A pairing under way, once it has its code.
  PairingCode? pairing;

  /// The daemon's VAPID key, asked for once connected, so a tap on
  /// Notifications can subscribe at once (iOS asks only from a tap).
  Uint8List? _pushKey;

  /// Whether notifications are on here, as the browser says.
  PushState push = PushState.off;

  /// Reads the stored pairing and, if there's one, connects.
  Future<void> start() async {
    try {
      final r = await platform.load();
      if (r != null) {
        if (r['key'] case final Uint8List k when k.length == 32) {
          _key = await rt.KeyPair.make(k);
        }
        name = r['name'] as String? ?? '';
        final relay = Uri.tryParse(r['relay'] as String? ?? '');
        final id = r['daemon'] as String? ?? '';
        if (r['daemonKey'] case final Uint8List dk
            when relay != null && id.isNotEmpty && _key != null) {
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

  Future<void> _save() => platform.save({
    'key': _key?.private,
    'name': name,
    if (paired case final p?) ...{
      'relay': p.relay.toString(),
      'daemon': p.id,
      'daemonKey': p.key,
    },
  });

  /// Pairs with the Mac whose link (or QR code's text) is [link], as
  /// [deviceName]. [pairing] shows the code meanwhile; it throws when the
  /// Mac refuses or doesn't answer.
  Future<void> pair(String link, String deviceName) async {
    final offer = rt.PairingOffer.parse(link);
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
    );
    final d = daemon =
        (connectTo?.call(t) ?? Daemon(transport: t, remote: true))
          ..addListener(_daemonChanged);
    remoteState.addListener(_remoteChanged);
    platform
      ..onVisible(({required visible}) {
        if (visible) unawaited(d.ping());
        unawaited(view(visible ? d.selectedId : null));
      })
      ..onOpenChat = ((chat) => opening.value = chat);
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
      _pushKey = key.isEmpty
          ? null
          : base64Url.decode(key.padRight((key.length + 3) ~/ 4 * 4, '='));
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
    } on connect.ConnectException catch (e) {
      return e.message;
    } on Object catch (e) {
      return '$e';
    }
  }

  /// Ends the link to the Mac (the page goes), keeping the pairing.
  Future<void> close() async {
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
  /// Mac still lists this device until it's revoked there.
  Future<void> forget() async {
    if (push == PushState.on) await setPush(on: false);
    await close();
    paired = _key = _pushKey = null;
    remoteState.value = null;
    await platform.clear();
    push = await platform.pushState();
    notifyListeners();
  }
}
