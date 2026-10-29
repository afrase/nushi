// The Mac's side of web_e2e_test.dart, in the VM (a hybrid isolate): the
// real nushid and nushi-relay (serving a web app, so it takes the test
// page's origin), the fake agent as Claude, and the Mac's calls on the
// daemon's socket.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../e2e_rig.dart';

// The channel is used untyped: see below.
// ignore_for_file: avoid_dynamic_calls

// A hybrid isolate under flutter test resolves no packages: dart:io only
// (the rig too, imported by its path), the channel untyped, and the Mac's
// calls as Connect's JSON through curl (the socket speaks HTTP/2 only).

/// The Mac's side, for the test at [origin]; channel is a StreamChannel.
Future<void> hybridMain(dynamic channel, Object? origin) async {
  Rig? built;
  try {
    final rig = built = await Rig.build('nwe');
    await Directory('${rig.path}/web').create();
    await File('${rig.path}/web/index.html').writeAsString('<!doctype html>');
    await rig.startRelay(
      args: ['-web', '${rig.path}/web', '-origin', origin! as String],
    );
    await rig.startDaemon();
    Future<Map<String, Object?>> mac(String method, [Object? body]) async {
      final r = await Process.run('curl', [
        '-sS',
        '--unix-socket',
        rig.socket,
        '--http2-prior-knowledge',
        '-H',
        'Authorization: Bearer ${rig.token}',
        '-H',
        'Content-Type: application/json',
        '-d',
        jsonEncode(body ?? {}),
        'http://nushid/nushi.v1.NushiService/$method',
      ]);
      final out = (jsonDecode(r.stdout as String) as Map)
          .cast<String, Object?>();
      if (out['code'] != null) throw StateError('$method: ${out['message']}');
      return out;
    }

    Future<Map<String, Object?>> remote() async =>
        ((await mac('GetRemote'))['remote']! as Map).cast<String, Object?>();

    await mac('SetRemote', {'on': true, 'relay': rig.relayUrl});
    await until(() async => (await remote())['state'] == 'connected');

    // The link the Mac's Copy link gives: the QR code's text, in the
    // fragment of the relay's own address.
    final qr = (await mac('StartPairing'))['qr']! as String;
    final http = 'http://${rig.relayAddress}';
    channel.sink.add({
      'link': '$http/#${qr.substring('nushi://'.length)}',
      'folder': rig.work,
    });

    await for (final Object? m in channel.stream as Stream<Object?>) {
      final ask = (m! as Map).cast<String, Object?>();
      switch (ask['do']) {
        case 'confirm':
          // Allow only the phone whose code the Mac shows.
          var code = '';
          await until(() async {
            final p = (await remote())['pairing'] as Map? ?? {};
            code = p['code'] as String? ?? '';
            return code.isNotEmpty;
          });
          final allow = code == ask['code'];
          await mac('ConfirmPairing', {'code': code, 'allow': allow});
          channel.sink.add({'allowed': allow});
        case 'devices':
          channel.sink.add({
            'file': await File('${rig.path}/data/devices.json').readAsString(),
            'remote': jsonEncode(await remote()),
          });
        case 'done':
          await rig.close();
          channel.sink.add({'done': true});
          return;
      }
    }
  } on Object catch (e) {
    channel.sink.add({'error': '$e'});
    await built?.close();
  }
}
