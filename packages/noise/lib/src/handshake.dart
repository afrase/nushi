part of '../noise.dart';

// The two handshakes Nushi uses (ADR 0034), each its messages' tokens
// (spec section 7): IK, whose responder's static key the initiator knows
// beforehand (its one pre-message), and IKpsk1, the same with the
// pre-shared key mixed at the end of the first message.
const _protocols = <String, List<List<String>>>{
  'IK': [
    ['e', 'es', 's', 'ss'],
    ['e', 'ee', 'se'],
  ],
  'IKpsk1': [
    ['e', 'es', 's', 'ss', 'psk'],
    ['e', 'ee', 'se'],
  ],
};

/// One side of a handshake.
final class HandshakeState {
  new _(
    this._ss,
    this._messages,
    this._initiator,
    this._s,
    this._rs,
    this._psks,
    this._fixedE,
    this._psk,
  );

  final _SymmetricState _ss;
  final List<List<String>> _messages;
  final bool _initiator;
  final KeyPair? _s;
  final List<List<int>> _psks;
  final KeyPair? _fixedE;
  final bool _psk;
  Uint8List? _rs;
  KeyPair? _e;
  Uint8List? _re;
  int _next = 0;
  int _pskNext = 0;
  CipherState? _send;
  late CipherState _receive;

  /// Starts a handshake for [protocol]:
  /// `Noise_IK_25519_ChaChaPoly_BLAKE2s` or
  /// `Noise_IKpsk1_25519_ChaChaPoly_BLAKE2s`. [s] is this side's static
  /// key, [rs] the responder's for the initiator, [psks] IKpsk1's one
  /// pre-shared key (32 bytes). [e] fixes the ephemeral key, for test
  /// vectors only.
  static Future<HandshakeState> start(
    String protocol, {
    required bool initiator,
    List<int> prologue = const [],
    KeyPair? s,
    List<int>? rs,
    List<List<int>> psks = const [],
    KeyPair? e,
  }) async {
    final parts = protocol.split('_');
    if (parts.length != 5 ||
        parts[0] != 'Noise' ||
        parts.sublist(2).join('_') != _suite) {
      throw ArgumentError.value(protocol, 'protocol', 'not Noise_*_$_suite');
    }
    final messages = _protocols[parts[1]];
    if (messages == null) {
      throw ArgumentError.value(protocol, 'protocol', 'not IK or IKpsk1');
    }
    final psk = parts[1].endsWith('psk1');
    if (psks.length != (psk ? 1 : 0) || psks.any((k) => k.length != 32)) {
      throw ArgumentError('the pattern takes ${psk ? 1 : 0} 32-byte keys');
    }
    final ss = await _SymmetricState.start(protocol);
    await ss.mixHash(prologue);
    final hs = HandshakeState._(
      ss,
      messages,
      initiator,
      s,
      rs == null ? null : Uint8List.fromList(rs),
      psks,
      e,
      psk,
    );
    // The pre-message: the responder's static key.
    final pre = initiator ? hs._rs : s?.public;
    if (pre == null) {
      throw ArgumentError('the pattern needs a static key known beforehand');
    }
    await ss.mixHash(pre);
    return hs;
  }

  /// Whether the handshake is done: [send] and [receive] are then set.
  bool get finished => _send != null;

  /// The cipher for what this side sends, once [finished].
  CipherState get send => _send!;

  /// The cipher for what this side receives, once [finished].
  CipherState get receive => _receive;

  /// The handshake hash, the same on both sides once finished.
  Uint8List get hash => _ss.h;

  /// The other side's static key, once known.
  Uint8List? get remoteStatic => _rs;

  bool get _myTurn => _next.isEven == _initiator;

  /// The handshake's next message, this side's, with [payload] (encrypted
  /// once there's a key).
  Future<Uint8List> writeMessage([List<int> payload = const []]) async {
    if (finished || !_myTurn) throw StateError("not this side's message");
    final out = BytesBuilder(copy: false);
    for (final token in _messages[_next]) {
      switch (token) {
        case 'e':
          final e = _e = _fixedE ?? await KeyPair.make();
          out.add(e.public);
          await _ss.mixHash(e.public);
          if (_psk) await _ss.mixKey(e.public);
        case 's':
          out.add(await _ss.encryptAndHash(_s!.public));
        case 'psk':
          await _ss.mixKeyAndHash(_psks[_pskNext++]);
        default:
          await _ss.mixKey(await _dhFor(token));
      }
    }
    out.add(await _ss.encryptAndHash(payload));
    await _advance();
    final msg = out.toBytes();
    if (msg.length > maxMessage) throw NoiseException('message too long');
    return msg;
  }

  /// Reads the other side's next message and returns its payload.
  Future<Uint8List> readMessage(List<int> message) async {
    if (finished || _myTurn) throw StateError("not the other side's message");
    if (message.length > maxMessage) throw NoiseException('message too long');
    var rest = message;
    for (final token in _messages[_next]) {
      switch (token) {
        case 'e':
          if (rest.length < _dhLen) throw NoiseException('message too short');
          final re = _re = Uint8List.fromList(rest.sublist(0, _dhLen));
          rest = rest.sublist(_dhLen);
          await _ss.mixHash(re);
          if (_psk) await _ss.mixKey(re);
        case 's':
          final n = _dhLen + (_ss.cs.hasKey ? _tagLen : 0);
          if (rest.length < n) throw NoiseException('message too short');
          _rs = await _ss.decryptAndHash(rest.sublist(0, n));
          rest = rest.sublist(n);
        case 'psk':
          await _ss.mixKeyAndHash(_psks[_pskNext++]);
        default:
          await _ss.mixKey(await _dhFor(token));
      }
    }
    final payload = await _ss.decryptAndHash(rest);
    await _advance();
    return payload;
  }

  Future<Uint8List> _dhFor(String token) {
    // The first letter is the initiator's key, the second the responder's.
    final (mine, theirs) = _initiator
        ? (token[0], token[1])
        : (token[1], token[0]);
    final k = mine == 'e' ? _e : _s;
    final pub = theirs == 'e' ? _re : _rs;
    if (k == null || pub == null) {
      throw NoiseException('missing key for $token');
    }
    return _dh(k, pub);
  }

  Future<void> _advance() async {
    if (++_next < _messages.length) return;
    final (c1, c2) = await _ss.split();
    _send = _initiator ? c1 : c2;
    _receive = _initiator ? c2 : c1;
  }
}
