import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/source_view.dart';

import 'harness.dart';

/// The spans the source shows: more once it is highlighted.
int _spans(WidgetTester tester) {
  var n = 0;
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((_) {
      n++;
      return true;
    });
  }
  return n;
}

Widget _host(String text) => themed(SourceView(text, path: 'a.dart'));

void main() {
  const code = 'void main() {\n  final x = 1;\n  print("hi \$x");\n}\n';

  testWidgets('a rebuild with the same text while it highlights keeps the '
      'highlighting', (tester) async {
    await tester.pumpWidget(_host(code));
    final plain = _spans(tester);
    // PreviewBody decodes the file again on each build: an equal string,
    // not the same one.
    await tester.pumpWidget(_host(String.fromCharCodes(code.codeUnits)));
    await untilReal(
      tester,
      () => _spans(tester) > plain,
      limit: const Duration(seconds: 5),
    );
  });
}
