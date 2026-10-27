import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:remote_transport/src/limits.dart';
import 'package:web/web.dart' as web;

/// A relay's WebSocket in a browser: binary messages only, at most
/// [maxMessage] bytes each. The browser sends the page's origin, which the
/// relay takes only from the web app it serves itself (ADR 0054).
final class RelaySocket {
  new _(this._ws) {
    _ws
      ..binaryType = 'arraybuffer'
      ..onmessage = _onMessage.toJS
      ..onerror = ((web.Event _) => _fail(
        const _SocketError('the relay connection failed'),
      )).toJS
      ..onclose = ((web.CloseEvent e) {
        closeCode = e.code;
        _fail(null);
      }).toJS;
  }

  final web.WebSocket _ws;

  /// The close code the relay ended the connection with, if it sent one
  /// (4404: no daemon waits at the id).
  int? closeCode;
  final _messages = StreamController<Uint8List>();
  bool _closed = false;

  /// The relay's binary messages; the stream ends (or fails) with the
  /// connection.
  Stream<Uint8List> get messages => _messages.stream;

  /// Opens [url] (`ws://` or `wss://`).
  static Future<RelaySocket> connect(
    Uri url, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (url.scheme != 'wss' && url.scheme != 'ws') {
      throw ArgumentError.value(url, 'url', 'not ws:// or wss://');
    }
    final ws = web.WebSocket(url.toString());
    final s = RelaySocket._(ws);
    final open = Completer<void>();
    ws.onopen = ((web.Event _) {
      if (!open.isCompleted) open.complete();
    }).toJS;
    unawaited(
      s._messages.done.then(
        (_) {
          if (!open.isCompleted) {
            open.completeError(const _SocketError("couldn't reach the relay"));
          }
        },
        onError: (Object e) {
          if (!open.isCompleted) open.completeError(e);
        },
      ),
    );
    try {
      await open.future.timeout(timeout);
    } on Object {
      await s.close();
      rethrow;
    }
    return s;
  }

  void _onMessage(web.MessageEvent e) {
    final data = e.data;
    if (data == null || !data.isA<JSArrayBuffer>()) {
      return _fail(const _SocketError("a message that isn't binary"));
    }
    final bytes = (data as JSArrayBuffer).toDart.asUint8List();
    if (bytes.length > maxMessage) {
      return _fail(const _SocketError('a message over the limit'));
    }
    if (!_closed) _messages.add(bytes);
  }

  /// Sends one binary message.
  void send(List<int> data) {
    if (data.length > maxMessage) throw ArgumentError('message too long');
    if (_closed) return;
    _ws.send(Uint8List.fromList(data).toJS);
  }

  /// Closes the socket.
  Future<void> close() async {
    if (!_closed) _ws.close(1000);
    _fail(null);
  }

  void _fail(Object? error) {
    if (_closed) return;
    _closed = true;
    if (_ws.readyState <= web.WebSocket.OPEN) _ws.close();
    if (error != null) _messages.addError(error);
    unawaited(_messages.close());
  }
}

final class _SocketError implements Exception {
  const new(this.message);
  final String message;
  @override
  String toString() => message;
}
