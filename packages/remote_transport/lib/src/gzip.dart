import 'dart:convert';
import 'dart:typed_data';

import 'package:connectrpc/connect.dart' show Compression;

/// Connect's gzip on every platform: the browser has no synchronous gzip
/// (dart:io's is native), so this inflates in Dart (RFC 1951 and 1952,
/// after zlib's puff.c). It only ever reads what the daemon sent through
/// the Noise channel; output past [max] bytes is refused all the same.
/// Encoding stores without compressing: the phone's requests are small.
final class Gzip extends Codec<Uint8List, Uint8List> implements Compression {
  /// Gzip, inflating to [max] bytes at most.
  const new({this.max = 64 << 20});

  /// The most bytes one message inflates to.
  final int max;

  @override
  String get name => 'gzip';

  @override
  Converter<Uint8List, Uint8List> get decoder => _Gunzip(max);

  @override
  Converter<Uint8List, Uint8List> get encoder => const _Store();
}

final class _Gunzip extends Converter<Uint8List, Uint8List> {
  const new(this.max);
  final int max;
  @override
  Uint8List convert(Uint8List input) => gunzip(input, max: max);
}

final class _Store extends Converter<Uint8List, Uint8List> {
  const new();
  @override
  Uint8List convert(Uint8List input) => gzipStored(input);
}

/// [data] in a gzip member of stored (uncompressed) blocks.
Uint8List gzipStored(Uint8List data) {
  final out = BytesBuilder(copy: false)
    ..add(const [0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 255]);
  var at = 0;
  do {
    final n = data.length - at < 0xffff ? data.length - at : 0xffff;
    final last = at + n == data.length;
    out
      ..addByte(last ? 1 : 0)
      ..add([n & 0xff, n >> 8, ~n & 0xff, (~n >> 8) & 0xff])
      ..add(Uint8List.sublistView(data, at, at + n));
    at += n;
  } while (at < data.length);
  final crc = crc32(data);
  final len = data.length;
  out.add([
    for (final v in [crc, len]) ...[
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ],
  ]);
  return out.takeBytes();
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

/// The CRC-32 gzip checks.
int crc32(List<int> data) {
  var c = 0xffffffff;
  for (final b in data) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

/// Inflates a gzip member (one; what Go's gzip writes), checking its CRC
/// and length. Throws a [FormatException] on anything malformed.
Uint8List gunzip(Uint8List data, {int max = 64 << 20}) {
  final r = _Inflater(data, max);
  if (data.length < 18 || data[0] != 0x1f || data[1] != 0x8b || data[2] != 8) {
    throw const FormatException('not gzip');
  }
  final flags = data[3];
  r.pos = 10;
  if (flags & 4 != 0) r.pos += 2 + (r.byte() | r.byte() << 8); // extra
  if (flags & 8 != 0) r.skipString(); // name
  if (flags & 16 != 0) r.skipString(); // comment
  if (flags & 2 != 0) r.pos += 2; // header CRC
  r.inflate();
  final out = r.output();
  r.pos = data.length - 8;
  final crc = r.word();
  final len = r.word();
  if (crc != crc32(out) || len != out.length & 0xffffffff) {
    throw const FormatException('gzip: bad checksum');
  }
  return out;
}

final class _Huffman {
  new(List<int> lengths) {
    for (final l in lengths) {
      count[l]++;
    }
    final offs = List.filled(16, 0);
    for (var l = 1; l < 15; l++) {
      offs[l + 1] = offs[l] + count[l];
    }
    for (var s = 0; s < lengths.length; s++) {
      if (lengths[s] != 0) symbol[offs[lengths[s]]++] = s;
    }
  }

  final List<int> count = List.filled(16, 0);
  final List<int> symbol = List.filled(320, 0);
}

const _lbase = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, //
  67, 83, 99, 115, 131, 163, 195, 227, 258,
];
const _lext = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, //
  5, 5, 5, 5, 0,
];
const _dbase = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, //
  513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
];
const _dext = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, //
  10, 11, 11, 12, 12, 13, 13,
];
const _order = [
  16,
  17,
  18,
  0,
  8,
  7,
  9,
  6,
  10,
  5,
  11,
  4,
  12,
  3,
  13,
  2,
  14,
  1,
  15,
];

int _fixedLength(int i) => switch (i) {
  < 144 => 8,
  < 256 => 9,
  < 280 => 7,
  _ => 8,
};

final _fixed = (
  _Huffman([for (var i = 0; i < 288; i++) _fixedLength(i)]),
  _Huffman(List.filled(30, 5)),
);

final class _Inflater {
  new(this.data, this.max);

  final Uint8List data;
  final int max;
  int pos = 0;
  int _buf = 0;
  int _cnt = 0;
  late Uint8List _out = Uint8List(max < 1 << 16 ? max : 1 << 16);
  int _len = 0;

  static Never _bad(String why) => throw FormatException('gzip: $why');

  int byte() => pos < data.length ? data[pos++] : _bad('cut short');

  int word() => byte() | byte() << 8 | byte() << 16 | byte() << 24;

  void skipString() {
    while (byte() != 0) {}
  }

  int bits(int n) {
    while (_cnt < n) {
      _buf |= byte() << _cnt;
      _cnt += 8;
    }
    final v = _buf & ((1 << n) - 1);
    _buf >>>= n;
    _cnt -= n;
    return v;
  }

  void _put(int b) {
    if (_len == _out.length) _grow();
    _out[_len++] = b;
  }

  void _grow() {
    if (_out.length >= max) _bad('over ${max >> 20} MB');
    final bigger = Uint8List(_out.length * 2 > max ? max : _out.length * 2)
      ..setRange(0, _len, _out);
    _out = bigger;
  }

  Uint8List output() => Uint8List.sublistView(_out, 0, _len);

  int _decode(_Huffman h) {
    var code = 0;
    var first = 0;
    var index = 0;
    for (var len = 1; len < 16; len++) {
      code |= bits(1);
      final count = h.count[len];
      if (code - count < first) return h.symbol[index + (code - first)];
      index += count;
      first = (first + count) << 1;
      code <<= 1;
    }
    _bad('bad code');
  }

  void inflate() {
    for (var last = 0; last == 0;) {
      last = bits(1);
      switch (bits(2)) {
        case 0:
          _buf = _cnt = 0;
          final n = byte() | byte() << 8;
          if ((byte() | byte() << 8) != (~n & 0xffff)) _bad('bad block');
          if (pos + n > data.length) _bad('cut short');
          for (var i = 0; i < n; i++) {
            _put(data[pos++]);
          }
        case 1:
          _codes(_fixed.$1, _fixed.$2);
        case 2:
          _dynamic();
        default:
          _bad('bad block');
      }
    }
  }

  void _dynamic() {
    final nlen = bits(5) + 257;
    final ndist = bits(5) + 1;
    final ncode = bits(4) + 4;
    if (nlen > 286 || ndist > 30) _bad('bad counts');
    final lengths = List.filled(19, 0);
    for (var i = 0; i < ncode; i++) {
      lengths[_order[i]] = bits(3);
    }
    final lencode = _Huffman(lengths);
    final all = List.filled(nlen + ndist, 0);
    for (var i = 0; i < nlen + ndist;) {
      var sym = _decode(lencode);
      if (sym < 16) {
        all[i++] = sym;
        continue;
      }
      var len = 0;
      if (sym == 16) {
        if (i == 0) _bad('repeat with nothing before');
        len = all[i - 1];
        sym = 3 + bits(2);
      } else if (sym == 17) {
        sym = 3 + bits(3);
      } else {
        sym = 11 + bits(7);
      }
      if (i + sym > nlen + ndist) _bad('too many lengths');
      while (sym-- > 0) {
        all[i++] = len;
      }
    }
    if (all[256] == 0) _bad('no end of block');
    _codes(_Huffman(all.sublist(0, nlen)), _Huffman(all.sublist(nlen)));
  }

  void _codes(_Huffman lencode, _Huffman distcode) {
    for (;;) {
      var sym = _decode(lencode);
      if (sym < 256) {
        _put(sym);
      } else if (sym == 256) {
        return;
      } else {
        sym -= 257;
        if (sym >= 29) _bad('bad length');
        final len = _lbase[sym] + bits(_lext[sym]);
        final d = _decode(distcode);
        if (d >= 30) _bad('bad distance');
        final dist = _dbase[d] + bits(_dext[d]);
        if (dist > _len) _bad('distance too far');
        for (var i = 0; i < len; i++) {
          _put(_out[_len - dist]);
        }
      }
    }
  }
}
