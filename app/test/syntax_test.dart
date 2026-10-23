import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/syntax.dart';

void main() {
  test('languages by extension or name', () {
    expect(languageOf('app/lib/main.dart'), 'dart');
    expect(languageOf('x/colors.js'), 'js');
    expect(languageOf('Makefile'), 'makefile');
    expect(languageOf('notes.unknownext'), isNull);
  });

  test('a whole side is highlighted, then split by line', () async {
    const text = 'int a = 1;\n/* one\n   two */\nvar s = "x";\n';
    final [old, neu] = await highlightSides('dart', '', text);
    expect(old, [null]); // an empty side: one empty line
    // The comment's second line is a comment, though it has no /* itself.
    expect(neu![2]!.toList(), [0, 9, 3]);
    expect(neu[0]!.toList().sublist(0, 3), [0, 3, 0]); // int: a keyword
    expect(neu[3]!.toList().last, 2); // the string
  });
}
