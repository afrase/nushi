import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart';

import 'harness.dart';

void main() {
  testWidgets('a finished message shows as written', (tester) async {
    await tester.pumpWidget(
      themed(const AgentMarkdown('Try [1, 2, 3] and a*b here')),
    );
    expect(
      find.textContaining('[1, 2, 3] and a*b here', findRichText: true),
      findsOneWidget,
    );
  });
}
