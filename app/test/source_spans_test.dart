import 'dart:collection';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/source_spans.dart';

// onHits, overSelected and onFills: a line's runs split at the edges of
// a find's hits and the fills under them.

const _plain = Color(0xFF111111);
const _red = Color(0xFFAA0000);
const _blue = Color(0xFF0000AA);
const _inked = Color(0xFFFFFFFF);

/// A list of hits that counts how often an element is read.
final class _Counted extends ListBase<Hit> {
  new(this._hits);

  final List<Hit> _hits;
  int reads = 0;

  @override
  int get length => _hits.length;

  @override
  set length(int n) => throw UnsupportedError('read only');

  @override
  Hit operator [](int i) {
    reads++;
    return _hits[i];
  }

  @override
  void operator []=(int i, Hit h) => throw UnsupportedError('read only');
}

/// [spans]' text and colour, piece by piece.
List<(String, Color?)> _shape(List<TextSpan> spans) => [
  for (final s in spans) (s.text!, s.style?.color),
];

void main() {
  Color ink(Color c, {required bool now}) => now ? _blue : _inked;

  test('a hit across two runs and a run across two hits split right', () {
    const runs = [
      TextSpan(
        text: 'grapes',
        style: TextStyle(color: _red),
      ),
      TextSpan(text: ' and pears'),
    ];
    final out = onHits(
      runs,
      const [
        (start: 4, end: 8, now: false), // "es a"
        (start: 9, end: 10, now: true), // "d"
        (start: 12, end: 14, now: false), // "ea"
      ],
      plain: _plain,
      ink: ink,
    );
    expect(_shape(out), [
      ('grap', _red),
      ('es', _inked),
      (' a', _inked),
      ('n', null),
      ('d', _blue),
      (' p', null),
      ('ea', _inked),
      ('rs', null),
    ]);
  });

  test('splitting a long line at many hits is one walk over them', () {
    final line = 'abc' * 3334; // 10,002 characters
    final hits = _Counted([
      for (var i = 0; i < line.length; i += 3)
        (start: i, end: i + 1, now: false),
    ]);
    final runs = [
      for (var i = 0; i < line.length; i += 50)
        TextSpan(
          text: line.substring(i, (i + 50).clamp(0, line.length)),
          style: const TextStyle(color: _red),
        ),
    ];
    final out = onHits(runs, hits, plain: _plain, ink: ink);
    expect(out.map((s) => s.text).join(), line);
    expect(out.where((s) => s.style?.color == _inked), hasLength(hits.length));
    // A walk that only moves forward reads each hit a few times; looking
    // each piece's hit up among all of them reads millions.
    expect(hits.reads, lessThan(hits.length * 8));
    hits.reads = 0;
    overSelected(runs, hits, plain: _plain, ink: (c, h) => _inked);
    expect(hits.reads, lessThan(hits.length * 8));
  });

  const fill = Color(0xFF777777);
  const other = Color(0xFF888888);
  // Red is drawn anew on [fill]; blue and the plain text read as they are.
  Color onFill(Color c, Color f) => c == _red && f == fill ? _inked : c;

  test('a run on a fill is split where its ink changes, and only there', () {
    const runs = [
      TextSpan(
        text: 'apples',
        style: TextStyle(color: _red),
      ),
      TextSpan(text: ' and '),
      TextSpan(
        text: 'pears',
        style: TextStyle(color: _blue),
      ),
    ];
    final out = onFills(
      runs,
      const [(start: 2, end: 9, fill: fill), (start: 12, end: 16, fill: other)],
      plain: _plain,
      ink: onFill,
    );
    expect(_shape(out), [
      ('ap', _red),
      ('ples', _inked),
      (' and ', null),
      ('pears', _blue),
    ]);
  });

  test('a line whose code reads on its fills keeps its very runs', () {
    const runs = [
      TextSpan(
        text: 'pears',
        style: TextStyle(color: _blue),
      ),
      TextSpan(text: ' and '),
    ];
    final out = onFills(
      runs,
      const [(start: 0, end: 9, fill: fill)],
      plain: _plain,
      ink: onFill,
    );
    expect(identical(out, runs), isTrue);
  });
}
