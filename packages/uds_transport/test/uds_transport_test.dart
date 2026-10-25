import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:http2/transport.dart' as http2;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';
import 'package:test/test.dart';
import 'package:uds_transport/uds_transport.dart';

const _spec = connect.Spec<Empty, Empty>(
  '/test.v1.TestService/Call',
  connect.StreamType.unary,
  Empty.new,
  Empty.new,
);

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('uds');
    path = '${dir.path}/s.sock';
  });
  tearDown(() => dir.delete(recursive: true));

  connect.Transport client() => protocol.Transport(
    baseUrl: 'http://localhost',
    codec: const ProtoCodec(),
    httpClient: createHttpClient(transport: UdsTransport(path)),
  );

  test('a missing socket is unavailable until the server starts', () async {
    final c = connect.Client(client());
    await expectLater(
      c.unary(_spec, Empty()),
      throwsA(
        isA<connect.ConnectException>().having(
          (e) => e.code,
          'code',
          connect.Code.unavailable,
        ),
      ),
    );
    final server = await _serve(path);
    await c.unary(_spec, Empty());
    await server.close();
    await expectLater(
      c.unary(_spec, Empty()),
      throwsA(isA<connect.ConnectException>()),
    );
  });

  test('calls go through, and a dropped connection is redialed', () async {
    final server = await _serve(path);
    final c = connect.Client(client());
    await c.unary(_spec, Empty());
    await server.dropConnections();
    await c.unary(_spec, Empty());
    expect(server.connections, 2);
    await server.close();
  });
}

class _Server {
  new(this._socket) {
    _socket.listen((s) {
      connections++;
      final conn = http2.ServerTransportConnection.viaSocket(s);
      _open.add(conn);
      conn.incomingStreams.listen((stream) async {
        await stream.incomingMessages.drain<void>();
        stream
          ..sendHeaders([
            http2.Header.ascii(':status', '200'),
            http2.Header.ascii('content-type', 'application/proto'),
          ])
          ..sendData([], endStream: true);
      });
    });
  }

  final ServerSocket _socket;
  final _open = <http2.ServerTransportConnection>[];
  int connections = 0;

  Future<void> dropConnections() async {
    for (final c in _open) {
      await c.finish();
    }
    _open.clear();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  Future<void> close() async {
    await dropConnections();
    await _socket.close();
  }
}

Future<_Server> _serve(String path) async => _Server(
  await ServerSocket.bind(
    InternetAddress(path, type: InternetAddressType.unix),
    0,
  ),
);
