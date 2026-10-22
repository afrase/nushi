/// Connect RPC over HTTP/2 on a Unix domain socket.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:http2/transport.dart' as http2;

/// An [Http2ClientTransport] that dials [socketPath].
///
/// One HTTP/2 connection carries every call. A connection that stops taking
/// streams (GOAWAY, or the socket closed) is dropped, and the next call dials
/// a fresh one; streams still open on the old connection run to completion.
/// A failed dial or a lost connection reaches the caller as a
/// [connect.ConnectException] with code `unavailable`.
final class UdsTransport implements Http2ClientTransport {
  UdsTransport(this.socketPath);

  final String socketPath;

  http2.ClientTransportConnection? _live;
  Future<http2.ClientTransportConnection>? _dialing;

  @override
  Future<http2.ClientTransportStream> makeRequest(
    Uri uri,
    List<http2.Header> headers,
  ) async {
    for (var attempt = 0; ; attempt++) {
      final conn = await _conn();
      if (conn.isOpen) return _MappedStream(conn.makeRequest(headers));
      _drop(conn);
      if (attempt == 1) throw _unavailable('connection closing', null);
    }
  }

  /// Closes the connection, letting open streams finish.
  Future<void> close() async {
    final conn = _live;
    _live = null;
    _dialing = null;
    await conn?.finish();
  }

  Future<http2.ClientTransportConnection> _conn() {
    final live = _live;
    if (live != null) return Future.value(live);
    return _dialing ??= _dial().whenComplete(() => _dialing = null);
  }

  Future<http2.ClientTransportConnection> _dial() async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
    } on Object catch (e) {
      throw _unavailable('dial failed', e);
    }
    final conn = http2.ClientTransportConnection.viaSocket(socket);
    _live = conn;
    void gone([_]) => _drop(conn);
    conn.onActiveStateChanged = (_) {
      if (!conn.isOpen) gone();
    };
    socket.done.then(gone, onError: gone);
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

Object _map(Object e) => switch (e) {
  connect.ConnectException() => e,
  http2.TransportException() ||
  http2.StreamTransportException() ||
  SocketException() => _unavailable('connection lost', e),
  _ => e,
};

/// A stream whose transport errors surface as `unavailable`.
final class _MappedStream implements http2.ClientTransportStream {
  _MappedStream(this._inner);

  final http2.ClientTransportStream _inner;

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
