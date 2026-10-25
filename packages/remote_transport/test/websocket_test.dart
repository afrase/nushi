import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:remote_transport/remote_transport.dart';
import 'package:test/test.dart';

/// A relay stand-in: dart:io's WebSocket server, sending [script]'s
/// messages, then echoing.
Future<Uri> _server(List<Object> script, {Duration? ping}) async {
  final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => srv.close(force: true));
  srv.listen((req) async {
    final ws = await WebSocketTransformer.upgrade(req);
    ws.pingInterval = ping;
    for (final m in script) {
      ws.add(m);
    }
    ws.listen(ws.add);
  });
  return Uri.parse('ws://127.0.0.1:${srv.port}/v1/dial/x');
}

void main() {
  test('messages both ways, the largest one included', () async {
    final big = Uint8List(maxMessage)..[maxMessage - 1] = 7;
    final ws = await RelaySocket.connect(await _server([big]));
    final it = StreamIterator(ws.messages);
    expect(await it.moveNext(), isTrue);
    expect(it.current.length, maxMessage);
    ws.send([1, 2, 3]);
    expect(await it.moveNext(), isTrue);
    expect(it.current, [1, 2, 3]);
    await ws.close();
  });

  test('a message over the limit ends the connection', () async {
    final ws = await RelaySocket.connect(
      await _server([Uint8List(maxMessage + 1)]),
    );
    await expectLater(ws.messages.toList(), throwsA(isA<SocketException>()));
  });

  test('a text message ends the connection', () async {
    final ws = await RelaySocket.connect(await _server(['hello']));
    await expectLater(ws.messages.toList(), throwsA(isA<SocketException>()));
  });

  test('pings from the relay are answered', () async {
    final ws = await RelaySocket.connect(
      await _server([], ping: const Duration(milliseconds: 50)),
    );
    final it = StreamIterator(ws.messages);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    ws.send([9]);
    expect(await it.moveNext(), isTrue);
    expect(it.current, [9]);
    await ws.close();
  });

  test('a plain HTTP answer is refused', () async {
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => srv.close(force: true));
    srv.listen(
      (req) => req.response
        ..statusCode = 503
        ..close(),
    );
    await expectLater(
      RelaySocket.connect(Uri.parse('ws://127.0.0.1:${srv.port}/v1/dial/x')),
      throwsA(isA<SocketException>()),
    );
  });
}
