import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:remote_transport/src/limits.dart';

/// A relay's WebSocket on dart:io (the tests that run the phone's code):
/// binary messages only, at most [maxMessage] bytes each. Its failures are
/// [SocketException]s.
final class RelaySocket {
  new _(this._ws) {
    _ws.listen(
      (m) {
        if (m is! List<int>) {
          return _fail(const SocketException("a message that isn't binary"));
        }
        if (m.length > maxMessage) {
          return _fail(const SocketException('a message over the limit'));
        }
        if (!_closed) _messages.add(m is Uint8List ? m : Uint8List.fromList(m));
      },
      onError: (Object e) => _fail(SocketException('the relay failed: $e')),
      onDone: () => _fail(null),
    );
  }

  final WebSocket _ws;
  final _messages = StreamController<Uint8List>();
  bool _closed = false;

  /// The relay's binary messages; the stream ends (or fails) with the
  /// connection.
  Stream<Uint8List> get messages => _messages.stream;

  /// The close code the relay ended the connection with, if it sent one
  /// (4404: no daemon waits at the id).
  int? get closeCode => _ws.closeCode;

  /// Opens [url] (`ws://` or `wss://`).
  static Future<RelaySocket> connect(
    Uri url, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (url.scheme != 'wss' && url.scheme != 'ws') {
      throw ArgumentError.value(url, 'url', 'not ws:// or wss://');
    }
    final dial = WebSocket.connect(
      url.toString(),
      compression: CompressionOptions.compressionOff,
    );
    try {
      return RelaySocket._(
        await dial.timeout(timeout)
          ..pingInterval = keepAlive,
      );
    } on SocketException {
      rethrow;
    } on Object catch (e) {
      // A dial that timed out may still open: close it then.
      unawaited(dial.then((ws) => ws.close(), onError: (_) {}));
      throw SocketException("couldn't reach the relay: $e");
    }
  }

  /// The bytes sent but not yet handed to the network: dart:io doesn't
  /// say, so always 0.
  int get buffered => 0;

  /// Sends one binary message.
  void send(List<int> data) {
    if (data.length > maxMessage) throw ArgumentError('message too long');
    if (_closed) return;
    try {
      _ws.add(data);
    } on Object catch (e) {
      _fail(SocketException('the relay failed: $e'));
    }
  }

  /// Sends a close frame and closes the socket.
  Future<void> close() async => _fail(null);

  void _fail(Object? error) {
    if (_closed) return;
    _closed = true;
    unawaited(_ws.close(WebSocketStatus.normalClosure).catchError((_) {}));
    if (error != null) _messages.addError(error);
    unawaited(_messages.close());
  }
}
