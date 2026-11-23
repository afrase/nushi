/// Connect RPC over HTTP/2 on a Unix domain socket: the app's way to its
/// own Mac's daemon. The package's one library with dart:io, so the
/// phone's web build never takes it through `remote_transport.dart`.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:daemon_transport/src/connection.dart';
import 'package:http2/transport.dart' as http2;

/// An [Http2ClientTransport] that dials [socketPath].
///
/// One HTTP/2 connection carries every call. A connection that stops taking
/// streams (GOAWAY, or the socket closed) is dropped, and the next call dials
/// a fresh one; streams still open on the old connection run to completion.
/// A failed dial or a lost connection reaches the caller as a
/// [connect.ConnectException] with code `unavailable`.
final class UdsTransport implements Http2ClientTransport {
  /// A transport to the daemon listening on [socketPath].
  new(this.socketPath);

  /// The daemon's Unix socket.
  final String socketPath;

  final _conn = SharedConnection();
  Future<http2.ClientTransportConnection>? _dialing;

  @override
  Future<http2.ClientTransportStream> makeRequest(
    Uri uri,
    List<http2.Header> headers,
  ) => _conn.request(
    _connection,
    headers,
    mapError: _map,
    closing: () => _unavailable('connection closing', null),
  );

  /// Closes the connection, letting open streams finish.
  Future<void> close() async {
    final conn = _conn.current;
    _conn.current = null;
    _dialing = null;
    await conn?.finish();
  }

  Future<http2.ClientTransportConnection> _connection() {
    final live = _conn.current;
    if (live != null) return Future.value(live);
    return _dialing ??= _dial().whenComplete(() => _dialing = null);
  }

  Future<http2.ClientTransportConnection> _dial() async {
    // The connection owns it: closing the connection closes it.
    // ignore: close_sinks
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
    _conn.current = conn;
    void gone([_]) => _conn.drop(conn);
    conn.onActiveStateChanged = (_) {
      if (!conn.isOpen) gone();
    };
    unawaited(socket.done.then(gone, onError: gone));
    return conn;
  }
}

connect.ConnectException _unavailable(String what, Object? cause) =>
    connect.ConnectException(
      connect.Code.unavailable,
      'daemon unavailable: $what',
      cause: cause,
    );

/// A lost connection's errors, the socket's own among them, as
/// `unavailable`.
Object _map(Object e) => switch (e) {
  connect.ConnectException() => e,
  http2.TransportException() ||
  http2.StreamTransportException() ||
  SocketException() => _unavailable('connection lost', e),
  _ => e,
};
