import 'dart:convert';

import 'package:flutter/foundation.dart';

// A file's bytes as the editor's text and back (ADR 0096): the text has
// `\n` line ends only, and what made the bytes (a BOM, LF or CRLF) is kept
// apart, so a save writes the file as it was but for the edits.

/// How a file's text is written: with a UTF-8 byte order mark or not, its
/// lines ended by CRLF or LF.
@immutable
class FileCodec {
  const new({this.bom = false, this.crlf = false});

  final bool bom;
  final bool crlf;

  /// [text] (`\n` line ends) as this file's bytes.
  Uint8List encode(String text) {
    final body = utf8.encode(crlf ? text.replaceAll('\n', '\r\n') : text);
    if (!bom) return body;
    return Uint8List(body.length + 3)
      ..setRange(0, 3, _bom)
      ..setRange(3, body.length + 3, body);
  }

  @override
  bool operator ==(Object other) =>
      other is FileCodec && other.bom == bom && other.crlf == crlf;

  @override
  int get hashCode => Object.hash(bom, crlf);
}

const _bom = [0xEF, 0xBB, 0xBF];

/// A file's text for the editor, or why it can't be edited.
typedef FileText = ({String text, FileCodec codec});

/// [bytes] as text the editor can edit and give back byte for byte, or the
/// reason it can't (a sentence ending "…", for "Read-only: …"): not strict
/// UTF-8, a NUL (not text), a CR alone, or lines ended both ways.
(FileText?, String?) decodeFile(List<int> bytes) {
  final bom =
      bytes.length >= 3 &&
      bytes[0] == _bom[0] &&
      bytes[1] == _bom[1] &&
      bytes[2] == _bom[2];
  final String raw;
  try {
    raw = utf8.decode(bom ? bytes.sublist(3) : bytes);
  } on FormatException {
    return (null, 'it isn’t UTF-8 text.');
  }
  if (raw.contains('\u0000')) return (null, 'it isn’t text.');
  var crlf = 0;
  var lf = 0;
  for (var i = 0; i < raw.length; i++) {
    switch (raw.codeUnitAt(i)) {
      case 0x0D:
        if (i + 1 >= raw.length || raw.codeUnitAt(i + 1) != 0x0A) {
          return (null, 'it has a carriage return (CR) on its own.');
        }
        crlf++;
        i++;
      case 0x0A:
        lf++;
    }
  }
  if (crlf > 0 && lf > 0) {
    return (null, 'its lines end both in CRLF and LF.');
  }
  final codec = FileCodec(bom: bom, crlf: crlf > 0);
  final text = crlf > 0 ? raw.replaceAll('\r\n', '\n') : raw;
  // What can't come back the same isn't edited (a BOM after the first).
  if (!_same(codec.encode(text), bytes)) {
    return (null, 'it wouldn’t be saved as it is.');
  }
  return ((text: text, codec: codec), null);
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
