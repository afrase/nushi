import 'dart:io';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart' as connect;
import 'package:remote_transport/remote_transport.dart';
import 'package:test/test.dart';

void main() {
  test('closed for good: no call dials again', () async {
    // A relay that counts the connections it gets.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    var dials = 0;
    server.listen((s) {
      dials++;
      s.destroy();
    });
    addTearDown(server.close);
    final t = RelayTransport(
      PairedDaemon(
        Uri.parse('ws://127.0.0.1:${server.port}'),
        'id',
        Uint8List(32),
      ),
      await KeyPair.make(),
    );
    await t.close();
    await expectLater(
      t.makeRequest(Uri.parse('http://nushid/'), []),
      throwsA(isA<connect.ConnectException>()),
    );
    expect(dials, 0);
  });

  test('a dial the relay refuses says the relay', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) => s.destroy());
    addTearDown(server.close);
    final t = RelayTransport(
      PairedDaemon(
        Uri.parse('ws://127.0.0.1:${server.port}'),
        'id',
        Uint8List(32),
      ),
      await KeyPair.make(),
    );
    await expectLater(
      t.makeRequest(Uri.parse('http://nushid/'), []),
      throwsA(
        isA<connect.ConnectException>().having(
          (e) => e.cause,
          'cause',
          Unreachable.relay,
        ),
      ),
    );
  });
}
