/// The Noise Protocol Framework (revision 34), with 25519, ChaChaPoly and
/// BLAKE2s, on the `cryptography` package: the fundamental handshake
/// patterns and the `psk` modifiers, as the spec writes them.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

part 'src/handshake.dart';

/// The most bytes a Noise message holds.
const maxMessage = 65535;

const _dhLen = 32;
const _hashLen = 32;
const _tagLen = 16;
const _suite = '25519_ChaChaPoly_BLAKE2s';

final _x25519 = X25519();
final _aead = Chacha20.poly1305Aead();
final _blake2s = Blake2s();

/// Thrown when a message doesn't decrypt or a handshake goes wrong.
final class NoiseException implements Exception {
  NoiseException(this.message);
  final String message;
  @override
  String toString() => 'NoiseException: $message';
}

/// A static or ephemeral X25519 key pair.
final class KeyPair {
  KeyPair._(this.private, this.public);
  final Uint8List private;
  final Uint8List public;

  /// A key pair whose private key is [private] (32 bytes), or a new one.
  static Future<KeyPair> make([List<int>? private]) async {
    final kp = private == null
        ? await _x25519.newKeyPair()
        : await _x25519.newKeyPairFromSeed(private);
    final pub = await kp.extractPublicKey();
    return KeyPair._(
      Uint8List.fromList(await kp.extractPrivateKeyBytes()),
      Uint8List.fromList(pub.bytes),
    );
  }
}

Future<Uint8List> _dh(KeyPair k, List<int> public) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: SimpleKeyPairData(
      k.private,
      publicKey: SimplePublicKey(k.public, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    ),
    remotePublicKey: SimplePublicKey(public, type: KeyPairType.x25519),
  );
  final out = Uint8List.fromList(await shared.extractBytes());
  // A low-order public key gives all zeros; refuse it, as Go's X25519 does.
  if (out.every((b) => b == 0)) throw NoiseException('bad public key');
  return out;
}

Future<Uint8List> _hash(List<int> data) async =>
    Uint8List.fromList((await _blake2s.hash(data)).bytes);

/// HMAC-BLAKE2s, by hand: the package's `Hmac(Blake2s())` takes BLAKE2s's
/// block to be 32 bytes, and it is 64.
Future<Uint8List> _hmacOf(List<int> key, List<int> data) async {
  const block = 64;
  final k = Uint8List(block)
    ..setAll(0, key.length > block ? await _hash(key) : key);
  final inner = await _hash([for (final b in k) b ^ 0x36, ...data]);
  return _hash([for (final b in k) b ^ 0x5c, ...inner]);
}

/// Noise's HKDF: two or three outputs of HASHLEN bytes.
Future<List<Uint8List>> _hkdf(List<int> ck, List<int> ikm, int n) async {
  final temp = await _hmacOf(ck, ikm);
  final o1 = await _hmacOf(temp, [1]);
  final o2 = await _hmacOf(temp, [...o1, 2]);
  if (n == 2) return [o1, o2];
  return [
    o1,
    o2,
    await _hmacOf(temp, [...o2, 3]),
  ];
}

/// Encrypts or decrypts with one key and a nonce that counts up.
final class CipherState {
  CipherState([List<int>? k]) : _k = k == null ? null : Uint8List.fromList(k);

  Uint8List? _k;
  int _n = 0;

  /// The largest nonce a message may use: Dart's ints stop at 2^63-1, so
  /// this is below Noise's 2^64-2. No connection gets near it.
  static const maxNonce = 0x7fffffffffffffff - 1;

  bool get hasKey => _k != null;

  static Uint8List _nonce(int n, {bool max = false}) {
    final b = Uint8List(12);
    if (max) {
      b.fillRange(4, 12, 0xff);
    } else {
      ByteData.sublistView(b).setUint64(4, n, Endian.little);
    }
    return b;
  }

  Future<Uint8List> encryptWithAd(List<int> ad, List<int> plaintext) async {
    final k = _k;
    if (k == null) return Uint8List.fromList(plaintext);
    if (_n > maxNonce) throw NoiseException('nonce exhausted');
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(k),
      nonce: _nonce(_n),
      aad: ad,
    );
    _n++;
    return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
  }

  Future<Uint8List> decryptWithAd(List<int> ad, List<int> ciphertext) async {
    final k = _k;
    if (k == null) return Uint8List.fromList(ciphertext);
    if (_n > maxNonce) throw NoiseException('nonce exhausted');
    if (ciphertext.length < _tagLen) throw NoiseException('message too short');
    final cut = ciphertext.length - _tagLen;
    final List<int> clear;
    try {
      clear = await _aead.decrypt(
        SecretBox(
          ciphertext.sublist(0, cut),
          nonce: _nonce(_n),
          mac: Mac(ciphertext.sublist(cut)),
        ),
        secretKey: SecretKey(k),
        aad: ad,
      );
    } on SecretBoxAuthenticationError {
      throw NoiseException('a message failed to decrypt');
    }
    _n++;
    return Uint8List.fromList(clear);
  }

  /// Noise's REKEY: the key becomes the first 32 bytes of encrypting 32
  /// zeros under nonce 2^64-1. The nonce goes on counting.
  Future<void> rekey() async {
    final box = await _aead.encrypt(
      Uint8List(32),
      secretKey: SecretKey(_k!),
      nonce: _nonce(0, max: true),
    );
    _k = Uint8List.fromList(box.cipherText.sublist(0, 32));
  }
}

final class _SymmetricState {
  _SymmetricState(this.h) : ck = h;

  Uint8List ck;
  Uint8List h;
  CipherState cs = CipherState();

  static Future<_SymmetricState> start(String name) async {
    final bytes = Uint8List.fromList(name.codeUnits);
    if (bytes.length <= _hashLen) {
      return _SymmetricState(Uint8List(_hashLen)..setAll(0, bytes));
    }
    return _SymmetricState(await _hash(bytes));
  }

  Future<void> mixKey(List<int> ikm) async {
    final out = await _hkdf(ck, ikm, 2);
    ck = out[0];
    cs = CipherState(out[1]);
  }

  Future<void> mixHash(List<int> data) async =>
      h = await _hash([...h, ...data]);

  Future<void> mixKeyAndHash(List<int> ikm) async {
    final out = await _hkdf(ck, ikm, 3);
    ck = out[0];
    await mixHash(out[1]);
    cs = CipherState(out[2]);
  }

  Future<Uint8List> encryptAndHash(List<int> plaintext) async {
    final ct = await cs.encryptWithAd(h, plaintext);
    await mixHash(ct);
    return ct;
  }

  Future<Uint8List> decryptAndHash(List<int> ciphertext) async {
    final pt = await cs.decryptWithAd(h, ciphertext);
    await mixHash(ciphertext);
    return pt;
  }

  Future<(CipherState, CipherState)> split() async {
    final out = await _hkdf(ck, const [], 2);
    return (CipherState(out[0]), CipherState(out[1]));
  }
}
