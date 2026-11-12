import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A corner written as a number: `Radius.circular(6)` (and so
/// `BorderRadius.circular(6)`) or `radius: 6`. `radius: 0` is a square
/// corner, which is no radius at all.
final _raw = RegExp(
  r'Radius\.circular\(\s*[0-9.]+\s*\)|\bradius:\s*(?!0\s*[,)])[0-9.]+\s*[,)]',
);

/// Whether [line] (or the comment line above it, [before]) is one of the
/// true exceptions: a circle's size, or marked `// not a corner: <why>`.
bool _excepted(String line, String before) =>
    line.contains('fromCircle(') ||
    line.contains('// not a corner: ') ||
    before.trimLeft().startsWith('// not a corner: ');

void main() {
  test('every corner outside the theme is one of its radius tokens '
      '(ADR 0110)', () {
    final found = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !f.path.startsWith('lib/gen/'))
            .where((f) => !f.path.startsWith('lib/theme/'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (!_raw.hasMatch(line)) continue;
        if (_excepted(line, i > 0 ? lines[i - 1] : '')) continue;
        found.add('${f.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(
      found,
      isEmpty,
      reason:
          'Use NushiTheme.tag, control, card, panel or pill, or '
          'NushiTheme.inner of one. A size that is not a corner takes '
          '"// not a corner: <why>" on its line or the line above.',
    );
  });

  test('the check sees a raw corner and passes the exceptions', () {
    for (final line in [
      'borderRadius: BorderRadius.circular(6),',
      'const Radius.circular(2.5)',
      'radius: 14,',
      'box(t.border, radius: 8)',
    ]) {
      expect(_raw.hasMatch(line), isTrue, reason: line);
    }
    for (final line in [
      'radius: 0,',
      'radius: NushiTheme.control,',
      'BorderRadius.circular(NushiTheme.pill)',
      'BoxShadow(color: t.shadow, blurRadius: 12)',
      'Radius.circular(thickness / 2)',
    ]) {
      expect(_raw.hasMatch(line), isFalse, reason: line);
    }
    expect(_excepted('radius: 9, // not a corner: the circle', ''), isTrue);
    expect(_excepted('radius: 9,', '  // not a corner: its splash'), isTrue);
    expect(_excepted('radius: 9,', ''), isFalse);
  });
}
