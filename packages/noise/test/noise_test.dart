import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:noise/noise.dart';
import 'package:test/test.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) =>
    [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();

final _deferred = RegExp('^Noise_[NKXI]1|^Noise_[NKXI]{1,2}1');

void main() {
  // cacophony's and snow's vectors, cut to 25519_ChaChaPoly_BLAKE2s: every
  // fundamental pattern and psk modifier in them (deferred ones aren't
  // implemented).
  for (final file in ['cacophony', 'snow']) {
    final vectors =
        (jsonDecode(File('test/vectors/$file.json').readAsStringSync())
                as Map)['vectors']
            as List;
    final run = vectors.cast<Map<String, dynamic>>().where(
      (v) => !_deferred.hasMatch(v['protocol_name'] as String),
    );
    test('$file: ${run.length} vectors', () async {
      expect(run.length, greaterThan(20));
      for (final v in run) {
        await _vector(v);
      }
    });
  }

  test('a changed message fails, and so does a replayed one', () async {
    final mac = await KeyPair.make();
    final phone = await KeyPair.make();
    final i = await HandshakeState.start(
      'Noise_IK_25519_ChaChaPoly_BLAKE2s',
      initiator: true,
      s: phone,
      rs: mac.public,
    );
    final r = await HandshakeState.start(
      'Noise_IK_25519_ChaChaPoly_BLAKE2s',
      initiator: false,
      s: mac,
    );
    await r.readMessage(await i.writeMessage());
    await i.readMessage(await r.writeMessage());
    expect(r.remoteStatic, phone.public);
    final m = await i.send.encryptWithAd(const [], utf8.encode('hello'));
    final changed = Uint8List.fromList(m)..[0] ^= 1;
    expect(
      r.receive.decryptWithAd(const [], changed),
      throwsA(isA<NoiseException>()),
    );
    expect(utf8.decode(await r.receive.decryptWithAd(const [], m)), 'hello');
    expect(
      r.receive.decryptWithAd(const [], m),
      throwsA(isA<NoiseException>()),
    );
  });

  test('a wrong pre-shared key fails the first message', () async {
    final mac = await KeyPair.make();
    final i = await HandshakeState.start(
      'Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s',
      initiator: true,
      s: await KeyPair.make(),
      rs: mac.public,
      psks: [Uint8List(32)],
    );
    final r = await HandshakeState.start(
      'Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s',
      initiator: false,
      s: mac,
      psks: [Uint8List(32)..[0] = 1],
    );
    expect(
      r.readMessage(await i.writeMessage()),
      throwsA(isA<NoiseException>()),
    );
  });

  test('rekey matches on both sides', () async {
    final a = CipherState(Uint8List(32));
    final b = CipherState(Uint8List(32));
    await a.rekey();
    await b.rekey();
    final m = await a.encryptWithAd(const [], [1, 2, 3]);
    expect(await b.decryptWithAd(const [], m), [1, 2, 3]);
    expect(
      CipherState(Uint8List(32)).decryptWithAd(const [], m),
      throwsA(isA<NoiseException>()),
    );
  });
}

Future<void> _vector(Map<String, dynamic> v) async {
  final name = v['protocol_name'] as String;
  List<Uint8List> psks(String k) => [
    for (final p in (v[k] as List?) ?? []) _hex(p as String),
  ];
  Future<KeyPair?> key(String k) async =>
      v[k] == null ? null : KeyPair.make(_hex(v[k] as String));
  final init = await HandshakeState.start(
    name,
    initiator: true,
    prologue: _hex(v['init_prologue'] as String),
    s: await key('init_static'),
    rs: v['init_remote_static'] == null
        ? null
        : _hex(v['init_remote_static'] as String),
    psks: psks('init_psks'),
    e: await key('init_ephemeral'),
  );
  final resp = await HandshakeState.start(
    name,
    initiator: false,
    prologue: _hex(v['resp_prologue'] as String),
    s: await key('resp_static'),
    rs: v['resp_remote_static'] == null
        ? null
        : _hex(v['resp_remote_static'] as String),
    psks: psks('resp_psks'),
    e: await key('resp_ephemeral'),
  );
  final oneWay = RegExp('^Noise_[NKX](psk|_)').hasMatch(name);
  final messages = (v['messages'] as List).cast<Map<String, dynamic>>();
  for (var n = 0; n < messages.length; n++) {
    final payload = _hex(messages[n]['payload'] as String);
    final want = messages[n]['ciphertext'] as String;
    final fromInit = oneWay || n.isEven;
    final (from, to) = fromInit ? (init, resp) : (resp, init);
    Uint8List ct, pt;
    if (!init.finished) {
      ct = await from.writeMessage(payload);
      pt = await to.readMessage(ct);
    } else {
      ct = await from.send.encryptWithAd(const [], payload);
      pt = await to.receive.decryptWithAd(const [], ct);
    }
    expect(_toHex(ct), want, reason: '$name message $n');
    expect(pt, payload, reason: '$name message $n');
  }
  if (v['handshake_hash'] != null) {
    expect(_toHex(init.hash), v['handshake_hash'], reason: name);
    expect(_toHex(resp.hash), v['handshake_hash'], reason: name);
  }
}
