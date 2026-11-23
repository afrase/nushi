// What the relay's transport and the socket's share: the one HTTP/2
// connection a transport's calls ride, and a call's stream on it whose
// transport errors surface as `unavailable`. It names no dart:io, so the
// relay's library still builds for the web.
import 'dart:async';

import 'package:http2/transport.dart' as http2;

/// The connection every call of one transport rides.
final class SharedConnection {
  /// The live connection: null before a dial sets it, and after a drop.
  http2.ClientTransportConnection? current;

  /// Forgets [conn] if it is still [current], and finishes it in the
  /// background: a connection that stopped taking streams. Streams still
  /// open on it run to completion.
  void drop(http2.ClientTransportConnection conn) {
    if (!identical(current, conn)) return;
    current = null;
    unawaited(conn.finish().catchError((_) {}));
  }

  /// A call's stream on the connection [connection] gives. One found
  /// closing (GOAWAY) is dropped and the next one tried, once; after that
  /// the call fails with [closing]. [mapError] turns the stream's transport
  /// errors into what the caller sees.
  Future<http2.ClientTransportStream> request(
    Future<http2.ClientTransportConnection> Function() connection,
    List<http2.Header> headers, {
    required Object Function(Object error) mapError,
    required Exception Function() closing,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final conn = await connection();
      if (conn.isOpen) {
        return MappedStream(conn.makeRequest(headers), mapError);
      }
      drop(conn);
      if (attempt == 1) throw closing();
    }
  }
}

/// A stream whose errors go through a transport's mapping: its transport
/// errors surface as `unavailable` (connectrpc reports them as `unknown`,
/// which nothing reloads on).
final class MappedStream implements http2.ClientTransportStream {
  /// A stream on another, each of its errors passed through a mapping.
  new(this._inner, this._map);

  final http2.ClientTransportStream _inner;
  final Object Function(Object error) _map;

  @override
  int get id => _inner.id;

  @override
  late final Stream<http2.StreamMessage> incomingMessages = _inner
      .incomingMessages
      .handleError(
        (Object e, StackTrace s) => Error.throwWithStackTrace(_map(e), s),
      );

  @override
  StreamSink<http2.StreamMessage> get outgoingMessages =>
      _inner.outgoingMessages;

  @override
  Stream<http2.TransportStreamPush> get peerPushes => _inner.peerPushes;

  @override
  set onTerminated(void Function(int?) value) => _inner.onTerminated = value;

  @override
  void terminate() => _inner.terminate();

  @override
  void sendHeaders(List<http2.Header> headers, {bool endStream = false}) =>
      _inner.sendHeaders(headers, endStream: endStream);

  @override
  void sendData(List<int> bytes, {bool endStream = false}) =>
      _inner.sendData(bytes, endStream: endStream);
}
