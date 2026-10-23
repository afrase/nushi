import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a finished message shows as written', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(body: AgentMarkdown('Try [1, 2, 3] and a*b here')),
      ),
    );
    expect(
      find.textContaining('[1, 2, 3] and a*b here', findRichText: true),
      findsOneWidget,
    );
  });
}
