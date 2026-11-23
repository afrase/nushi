import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:http2/transport.dart' as http2;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';
import 'package:remote_transport/uds_transport.dart';
import 'package:test/test.dart';

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

// A daemon that answers every call with an empty message, and counts the
// connections it got and those its client still holds open.
class _Server {
  new(this._socket) {
    _socket.listen((s) {
      connections++;
      open++;
      // The test reads the socket itself, so it sees the client close its
      // end after the HTTP/2 server has stopped reading: then the client's
      // connection is over, and its next call dials again.
      final incoming = StreamController<List<int>>();
      s.listen(
        incoming.add,
        onError: incoming.addError,
        onDone: () {
          unawaited(incoming.close());
          final waiting = _allClosed;
          if (--open == 0 && waiting != null && !waiting.isCompleted) {
            waiting.complete();
          }
        },
      );
      final conn = http2.ServerTransportConnection.viaStreams(
        incoming.stream,
        s,
      );
      _conns.add(conn);
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
  final _conns = <http2.ServerTransportConnection>[];
  Completer<void>? _allClosed;

  /// Every connection the server took.
  int connections = 0;

  /// The connections whose client hasn't closed its end yet.
  int open = 0;

  /// Ends every connection, and returns once each client has closed its
  /// end.
  Future<void> dropConnections() async {
    final closed = _allClosed = Completer<void>();
    if (open == 0) closed.complete();
    for (final c in _conns) {
      await c.finish();
    }
    _conns.clear();
    await closed.future;
    _allClosed = null;
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
