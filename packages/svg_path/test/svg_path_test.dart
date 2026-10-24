import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:svg_path/svg_path.dart';

void main() {
  test('absolute and relative commands draw the same square', () {
    for (final d in [
      'M1 1 L9 1 L9 9 L1 9 Z',
      'm1,1 8,0 0,8 -8,0z',
      'M1 1H9V9H1z',
      'M1 1h8v8h-8Z',
    ]) {
      final p = parseSvgPath(d);
      expect(p.getBounds(), const Rect.fromLTRB(1, 1, 9, 9), reason: d);
      expect(p.contains(const Offset(5, 5)), isTrue, reason: d);
      expect(p.contains(const Offset(9.5, 5)), isFalse, reason: d);
    }
  });

  test('curves, reflected control points and arcs', () {
    // A circle of radius 4 around (5, 5), from two arcs, flags packed.
    final circle = parseSvgPath('M1 5a4 4 0 108 0a4 4 0 1 0-8 0');
    expect(circle.getBounds().left, closeTo(1, 0.01));
    expect(circle.getBounds().right, closeTo(9, 0.01));
    expect(circle.contains(const Offset(5, 5)), isTrue);
    expect(circle.contains(const Offset(1.5, 1.5)), isFalse);

    // S mirrors C's second control point; T mirrors Q's.
    final s = parseSvgPath('M0 0C0 4 4 4 4 0S8 -4 8 0Z');
    expect(s.getBounds().top, lessThan(-2));
    expect(s.getBounds().bottom, greaterThan(2));
    final t = parseSvgPath('M0 0Q2 4 4 0T8 0');
    expect(t.getBounds().top, lessThan(-1));

    // Numbers that touch: ".5.5" is two, "-1e1" one.
    expect(
      parseSvgPath('M.5.5L-1e1-1E1').getBounds(),
      const Rect.fromLTRB(-10, -10, .5, .5),
    );
  });

  test('bad data is refused', () {
    for (final d in ['M1', 'M0 0 X1 1', 'M0 0A1 1 0 2 0 1 1', 'M0 0Z 1 1']) {
      expect(() => parseSvgPath(d), throwsFormatException, reason: d);
    }
  });
}
