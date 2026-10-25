import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:remote_transport/remote_transport.dart';
import 'package:test/test.dart';

late String _peerBin;

/// Starts the Go side (internal/e2e/noisepeer) with [args]; returns what
/// it printed: the relay, the id, its key and the secret.
Future<Map<String, String>> _peer(List<String> args) async {
  final p = await Process.start(_peerBin, args);
  addTearDown(p.kill);
  unawaited(p.stderr.drain<void>());
  final line = await p.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  return (jsonDecode(line) as Map).cast<String, String>();
}

Uint8List _b64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

Future<Channel> _open(
  Map<String, String> peer, {
  List<int>? secret,
  List<int>? key,
}) async {
  final ws = await RelaySocket.connect(
    Uri.parse('${peer['relay']}/v1/dial/${peer['id']}'),
  );
  return Channel.open(
    ws,
    id: peer['id']!,
    device: await KeyPair.make(),
    daemonKey: key ?? _b64(peer['key']!),
    secret: secret,
  );
}

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('noisepeer');
    _peerBin = '${dir.path}/noisepeer';
    final r = await Process.run('go', [
      'build',
      '-o',
      _peerBin,
      './internal/e2e/noisepeer',
    ], workingDirectory: '../..');
    if (r.exitCode != 0) throw StateError('building noisepeer: ${r.stderr}');
  });
  tearDownAll(() => dir.delete(recursive: true));

  test(
    'Dart and Go agree through enough messages to rekey twice each way',
    () async {
      final ch = await _open(await _peer([]));
      const n = 2 * 4096 + 10;
      for (var i = 0; i < n; i++) {
        ch.outgoing.add([i & 0xff, i >> 8]);
      }
      for (var i = 0; i < n; i++) {
        expect(await ch.read(), [i & 0xff, i >> 8]);
      }
      final big = Uint8List(200000);
      for (var i = 0; i < big.length; i++) {
        big[i] = i * 31;
      }
      ch.outgoing.add(big);
      final back = BytesBuilder();
      while (back.length < big.length) {
        back.add((await ch.read())!);
      }
      expect(back.toBytes(), big);
      await ch.close();
    },
  );

  test('pairing with the secret', () async {
    final peer = await _peer(['-psk']);
    final ch = await _open(peer, secret: _b64(peer['psk']!));
    ch.outgoing.add([1]);
    expect(await ch.read(), [1]);
    await ch.close();
  });

  test("pairing gives up on a Mac that doesn't answer", () async {
    final peer = await _peer(['-psk', '-mute']);
    final offer = PairingOffer(
      Uri.parse(peer['relay']!),
      peer['id']!,
      _b64(peer['key']!),
      _b64(peer['psk']!),
    );
    String? code;
    await expectLater(
      pair(
        offer,
        device: await KeyPair.make(),
        name: 'p',
        onCode: (c) => code = c,
        wait: const Duration(milliseconds: 300),
      ),
      throwsA(isA<PairingRefused>()),
    );
    expect(code, isNotNull);
  });

  test('a wrong secret fails', () async {
    final peer = await _peer(['-psk']);
    await expectLater(_open(peer, secret: Uint8List(32)), throwsA(anything));
  });

  test("a daemon that isn't the pinned key fails", () async {
    final peer = await _peer([]);
    await expectLater(
      _open(peer, key: (await KeyPair.make()).public),
      throwsA(anything),
    );
  });

  for (final mode in ['-tamper', '-replay']) {
    test('a ${mode.substring(1)}ed message from the daemon fails', () async {
      final ch = await _open(await _peer([mode, '3']));
      for (var i = 0; i < 5; i++) {
        ch.outgoing.add([i]);
      }
      expect(await ch.read(), [0]);
      expect(await ch.read(), [1]);
      await expectLater(() async {
        for (var i = 2; i < 5; i++) {
          expect(await ch.read(), [i]);
        }
      }(), throwsA(isA<Exception>()));
    });
  }
}
