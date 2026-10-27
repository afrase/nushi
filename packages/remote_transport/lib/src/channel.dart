import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:noise/noise.dart';

import 'package:remote_transport/src/websocket.dart' show RelaySocket;

/// The most bytes one transport message carries.
const int maxPlaintext = maxMessage - 16;

/// Each direction rekeys after this many messages (as `noiseconn` does).
const rekeyEvery = 4096;

/// The prologue that binds a handshake to its rendezvous id.
List<int> prologue(String id) => [
  ...utf8.encode('nushi-remote/1'),
  0,
  ...utf8.encode(id),
];

/// A Noise channel to the daemon over a relay socket: the phone is the
/// initiator, with the daemon's key pinned (IK), and the pairing secret
/// when pairing (IKpsk1).
final class Channel {
  new _(this._ws, this._messages, this._hs) {
    unawaited(_pump());
  }

  final RelaySocket _ws;
  final StreamIterator<Uint8List> _messages;
  final HandshakeState _hs;
  final _out = StreamController<List<int>>();
  int _sent = 0;
  int _got = 0;

  /// Runs the handshake on [ws], which is closed if it fails; the daemon
  /// has [wait] to answer (the relay alone waits 10 s for it to be there).
  static Future<Channel> open(
    RelaySocket ws, {
    required String id,
    required KeyPair device,
    required List<int> daemonKey,
    List<int>? secret,
    Duration wait = const Duration(seconds: 30),
  }) async {
    final messages = StreamIterator(ws.messages);
    try {
      final hs = await HandshakeState.start(
        secret == null
            ? 'Noise_IK_25519_ChaChaPoly_BLAKE2s'
            : 'Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s',
        initiator: true,
        prologue: prologue(id),
        s: device,
        rs: daemonKey,
        psks: [?secret],
      );
      ws.send(await hs.writeMessage());
      if (!await messages.moveNext().timeout(wait, onTimeout: () => false)) {
        throw NoiseException('no answer');
      }
      await hs.readMessage(messages.current);
      return Channel._(ws, messages, hs);
    } on Object {
      await ws.close();
      rethrow;
    }
  }

  /// The handshake hash, the same on the daemon's side.
  Uint8List get hash => _hs.hash;

  /// The pairing code both screens show: six digits from [hash].
  String get code {
    var n = BigInt.zero;
    for (final b in hash.sublist(0, 8)) {
      n = (n << 8) | BigInt.from(b);
    }
    final c = (n % BigInt.from(1000000)).toInt().toString().padLeft(6, '0');
    return '${c.substring(0, 3)} ${c.substring(3)}';
  }

  /// The next message, decrypted, or null once the channel ends. A message
  /// that fails to decrypt ends it with an error.
  Future<Uint8List?> read() async {
    try {
      if (!await _messages.moveNext()) return null;
      final m = await _hs.receive.decryptWithAd(const [], _messages.current);
      if (++_got % rekeyEvery == 0) await _hs.receive.rekey();
      return m;
    } on Object {
      await close();
      rethrow;
    }
  }

  /// Every message from here on, as bytes.
  Stream<List<int>> get incoming async* {
    for (Uint8List? m; (m = await read()) != null;) {
      yield m!;
    }
  }

  /// Bytes for the daemon; each add of up to [maxPlaintext] bytes goes as
  /// one message. Closing it closes the channel.
  StreamSink<List<int>> get outgoing => _out.sink;

  Future<void> _pump() async {
    try {
      await for (final data in _out.stream) {
        for (var at = 0; at < data.length; at += maxPlaintext) {
          final chunk = data.sublist(at, min(at + maxPlaintext, data.length));
          _ws.send(await _hs.send.encryptWithAd(const [], chunk));
          if (++_sent % rekeyEvery == 0) await _hs.send.rekey();
        }
      }
    } finally {
      await _ws.close();
    }
  }

  /// Closes the channel and its socket.
  Future<void> close() async {
    await _ws.close();
    unawaited(_out.close());
  }
}
