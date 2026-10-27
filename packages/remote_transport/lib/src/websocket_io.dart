import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:remote_transport/src/limits.dart';

final _random = Random.secure();

/// A WebSocket client (RFC 6455) for a relay: binary messages only, at
/// most [maxMessage] bytes each.
final class RelaySocket {
  new _(this._socket) {
    unawaited(_socket.done.catchError(_fail));
    _ping = Timer.periodic(keepAlive, (_) {
      if (DateTime.now().difference(_heard) > keepAlive * 3) {
        _fail(const SocketException('the relay went quiet'));
      } else {
        _frame(0x9, const []);
      }
    });
  }

  final Socket _socket;
  final _messages = StreamController<Uint8List>();
  late final Timer _ping;
  DateTime _heard = DateTime.now();
  final _buf = BytesBuilder(copy: false);
  final _message = BytesBuilder(copy: false);
  bool _closed = false;

  /// The relay's binary messages; the stream ends (or fails) with the
  /// connection.
  Stream<Uint8List> get messages => _messages.stream;

  /// Opens [url] (`ws://` or `wss://`).
  static Future<RelaySocket> connect(
    Uri url, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final secure = url.scheme == 'wss';
    if (!secure && url.scheme != 'ws') {
      throw ArgumentError.value(url, 'url', 'not ws:// or wss://');
    }
    final port = url.hasPort ? url.port : (secure ? 443 : 80);
    // Handed to the RelaySocket, which destroys it when it fails or closes.
    // ignore: close_sinks
    final socket =
        await (secure
              ? SecureSocket.connect(url.host, port, timeout: timeout)
              : Socket.connect(url.host, port, timeout: timeout))
          ..setOption(SocketOption.tcpNoDelay, true);
    final key = base64.encode(List.generate(16, (_) => _random.nextInt(256)));
    final want = base64.encode(
      (await Sha1().hash(
        utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'),
      )).bytes,
    );
    final host = url.hasPort ? '${url.host}:$port' : url.host;
    socket.add(
      utf8.encode(
        'GET ${url.path.isEmpty ? '/' : url.path} HTTP/1.1\r\n'
        'Host: $host\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\nSec-WebSocket-Version: 13\r\n\r\n',
      ),
    );
    final ws = RelaySocket._(socket);
    final upgraded = Completer<void>();
    final head = BytesBuilder();
    late StreamSubscription<Uint8List> sub;
    sub = socket.listen(
      (data) {
        if (upgraded.isCompleted) return ws._take(data);
        head.add(data);
        final bytes = head.toBytes();
        final end = _find(bytes, const [13, 10, 13, 10]);
        if (end < 0) {
          if (bytes.length > 8192) {
            upgraded.completeError(
              const SocketException("the relay's answer is too long"),
            );
          }
          return;
        }
        final lines = latin1.decode(bytes.sublist(0, end)).split('\r\n');
        final headers = {
          for (final l in lines.skip(1))
            if (l.contains(':'))
              l.substring(0, l.indexOf(':')).trim().toLowerCase(): l
                  .substring(l.indexOf(':') + 1)
                  .trim(),
        };
        if (!lines.first.startsWith('HTTP/1.1 101') ||
            headers['sec-websocket-accept'] != want) {
          final status = lines.first.substring(min(9, lines.first.length));
          upgraded.completeError(SocketException('the relay answered $status'));
          return;
        }
        upgraded.complete();
        ws._take(bytes.sublist(end + 4));
      },
      onError: (Object e) {
        if (!upgraded.isCompleted) upgraded.completeError(e);
        ws._fail(e);
      },
      onDone: () {
        if (!upgraded.isCompleted) {
          upgraded.completeError(const SocketException('the relay closed'));
        }
        ws._fail(null);
      },
    );
    try {
      await upgraded.future.timeout(timeout);
    } on Object {
      await sub.cancel();
      ws._fail(null);
      rethrow;
    }
    return ws;
  }

  static int _find(Uint8List b, List<int> pat) {
    for (var i = 0; i + pat.length <= b.length; i++) {
      var ok = true;
      for (var j = 0; j < pat.length && ok; j++) {
        ok = b[i + j] == pat[j];
      }
      if (ok) return i;
    }
    return -1;
  }

  /// Sends one binary message.
  void send(List<int> data) {
    if (data.length > maxMessage) throw ArgumentError('message too long');
    _frame(0x2, data);
  }

  /// Sends a close frame and closes the socket.
  Future<void> close() async {
    if (_closed) return;
    _frame(0x8, const [0x03, 0xe8]); // 1000, normal
    _fail(null);
  }

  void _frame(int opcode, List<int> payload) {
    if (_closed) return;
    final n = payload.length;
    final head = BytesBuilder()..addByte(0x80 | opcode);
    if (n < 126) {
      head.addByte(0x80 | n);
    } else {
      head
        ..addByte(0x80 | 126)
        ..add([n >> 8, n & 0xff]);
    }
    final mask = List.generate(4, (_) => _random.nextInt(256));
    head.add(mask);
    final masked = Uint8List(n);
    for (var i = 0; i < n; i++) {
      masked[i] = payload[i] ^ mask[i & 3];
    }
    head.add(masked);
    try {
      _socket.add(head.toBytes());
    } on Object catch (e) {
      _fail(e);
    }
  }

  // Frames from the relay: unmasked, a message (fragments included) at
  // most maxMessage bytes.
  void _take(Uint8List data) {
    _heard = DateTime.now();
    _buf.add(data);
    final b = _buf.takeBytes();
    var at = 0;
    while (!_closed) {
      if (b.length - at < 2) break;
      final fin = b[at] & 0x80 != 0;
      final opcode = b[at] & 0x0f;
      if (b[at + 1] & 0x80 != 0) {
        return _fail(const SocketException('a masked frame from the relay'));
      }
      var len = b[at + 1] & 0x7f;
      var head = 2;
      if (len == 126) {
        if (b.length - at < 4) break;
        len = b[at + 2] << 8 | b[at + 3];
        head = 4;
      } else if (len == 127) {
        return _fail(const SocketException('a message over the limit'));
      }
      if (_message.length + len > maxMessage) {
        return _fail(const SocketException('a message over the limit'));
      }
      if (b.length - at < head + len) break;
      final payload = Uint8List.sublistView(b, at + head, at + head + len);
      at += head + len;
      switch (opcode) {
        case 0x0 || 0x2:
          if (opcode == 0x2 && _message.isNotEmpty) {
            return _fail(const SocketException('a broken message'));
          }
          _message.add(Uint8List.fromList(payload));
          if (fin) _messages.add(_message.takeBytes());
        case 0x8:
          return _fail(null);
        case 0x9:
          _frame(0xA, payload);
        case 0xA:
          break;
        default:
          return _fail(const SocketException("a message that isn't binary"));
      }
    }
    if (at < b.length) _buf.add(Uint8List.sublistView(b, at));
  }

  void _fail(Object? error) {
    if (_closed) return;
    _closed = true;
    _ping.cancel();
    _socket.destroy();
    if (error != null) _messages.addError(error);
    unawaited(_messages.close());
  }
}
