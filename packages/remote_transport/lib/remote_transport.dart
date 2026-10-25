/// Connect RPC to a Nushi daemon through a relay, end to end encrypted
/// with Noise (ADR 0034): pairing from the Mac's QR code, then an
/// [Http2ClientTransport] the generated client runs on.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:http2/transport.dart' as http2;
import 'package:noise/noise.dart';

import 'src/channel.dart';
import 'src/websocket.dart';

export 'package:noise/noise.dart' show KeyPair;

export 'src/channel.dart' show Channel;
export 'src/websocket.dart' show RelaySocket, maxMessage;

/// What the Mac's QR code holds: the relay, a one-time rendezvous id, the
/// daemon's public key and the one-time secret.
final class PairingOffer {
  PairingOffer(this.relay, this.id, this.key, this.secret);

  final Uri relay;
  final String id;
  final Uint8List key;
  final Uint8List secret;

  /// Reads `nushi://pair?r=…&i=…&k=…&s=…`.
  factory PairingOffer.parse(String qr) {
    final u = Uri.parse(qr);
    final q = u.queryParameters;
    if (u.scheme != 'nushi' ||
        u.host != 'pair' ||
        [q['r'], q['i'], q['k'], q['s']].contains(null)) {
      throw const FormatException('not a Nushi pairing code');
    }
    final key = _unb64(q['k']!), secret = _unb64(q['s']!);
    if (key.length != 32 || secret.length != 32) {
      throw const FormatException('not a Nushi pairing code');
    }
    return PairingOffer(Uri.parse(q['r']!), q['i']!, key, secret);
  }
}

Uint8List _unb64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// A daemon a phone has paired with: what the phone keeps, beside its own
/// key.
final class PairedDaemon {
  PairedDaemon(this.relay, this.id, this.key);
  final Uri relay;
  final String id;
  final Uint8List key;
}

/// The Mac refused the phone (Deny, or no answer in time).
final class PairingRefused implements Exception {
  @override
  String toString() => 'The Mac refused the phone';
}

Uri _at(Uri relay, String side, String id) => relay.replace(
  pathSegments: [
    ...relay.pathSegments.where((s) => s.isNotEmpty),
    'v1',
    side,
    id,
  ],
);

/// Pairs [device] from [offer]: the handshake, then the phone's [name].
/// [onCode] gets the code to show while the Mac's user compares it and
/// allows the phone; with no answer within [wait] (the Mac gives up after
/// 2 minutes) the code is stale and it fails. Returns the daemon, and a
/// transport already connected on the pairing's channel.
Future<(PairedDaemon, RelayTransport)> pair(
  PairingOffer offer, {
  required KeyPair device,
  required String name,
  required void Function(String code) onCode,
  Duration wait = const Duration(seconds: 150),
}) async {
  final ws = await RelaySocket.connect(_at(offer.relay, 'dial', offer.id));
  final ch = await Channel.open(
    ws,
    id: offer.id,
    device: device,
    daemonKey: offer.key,
    secret: offer.secret,
  );
  ch.outgoing.add(utf8.encode(jsonEncode({'name': name})));
  onCode(ch.code);
  final reply = await ch.read().timeout(wait, onTimeout: () => null);
  final daemon = reply == null
      ? null
      : (jsonDecode(utf8.decode(reply)) as Map)['daemon'];
  if (daemon is! String) {
    await ch.close();
    throw PairingRefused();
  }
  final paired = PairedDaemon(offer.relay, daemon, offer.key);
  return (paired, RelayTransport(paired, device).._use(ch));
}

/// An [Http2ClientTransport] to a paired daemon through its relay.
///
/// One channel carries every call. A channel that stops taking streams is
/// dropped, and the next call dials the relay again (IK). A failed dial
/// reaches the caller as a [connect.ConnectException] `unavailable`.
final class RelayTransport implements Http2ClientTransport {
  RelayTransport(this.daemon, this.device);

  /// The daemon to dial. Its id changes when another device is revoked:
  /// when `Remote.rendezvous` names another, keep that one, and set it
  /// here for the next channel.
  PairedDaemon daemon;
  final KeyPair device;

  http2.ClientTransportConnection? _live;
  Future<http2.ClientTransportConnection>? _dialing;

  @override
  Future<http2.ClientTransportStream> makeRequest(
    Uri uri,
    List<http2.Header> headers,
  ) async {
    for (var attempt = 0; ; attempt++) {
      final conn =
          _live ??
          await (_dialing ??= _dial().whenComplete(() => _dialing = null));
      if (conn.isOpen) return conn.makeRequest(headers);
      _drop(conn);
      if (attempt == 1) throw _unavailable('connection closing', null);
    }
  }

  /// Closes the channel; calls still open on it fail.
  Future<void> close() async {
    final conn = _live;
    _live = null;
    await conn?.terminate();
  }

  Future<http2.ClientTransportConnection> _dial() async {
    final Channel ch;
    try {
      final ws = await RelaySocket.connect(
        _at(daemon.relay, 'dial', daemon.id),
      );
      ch = await Channel.open(
        ws,
        id: daemon.id,
        device: device,
        daemonKey: daemon.key,
      );
    } on Object catch (e) {
      throw _unavailable("couldn't reach the Mac", e);
    }
    return _use(ch);
  }

  http2.ClientTransportConnection _use(Channel ch) {
    final conn = http2.ClientTransportConnection.viaStreams(
      ch.incoming,
      ch.outgoing,
    );
    _live = conn;
    conn.onActiveStateChanged = (_) {
      if (!conn.isOpen) _drop(conn);
    };
    return conn;
  }

  void _drop(http2.ClientTransportConnection conn) {
    if (!identical(_live, conn)) return;
    _live = null;
    unawaited(conn.finish().catchError((_) {}));
  }
}

connect.ConnectException _unavailable(String what, Object? cause) =>
    connect.ConnectException(
      connect.Code.unavailable,
      'daemon unavailable: $what',
      cause: cause,
    );
