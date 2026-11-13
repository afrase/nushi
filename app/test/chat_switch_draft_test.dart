import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// What's typed belongs to the chat it was typed in: switching chats shows
// the other chat's box, and a message goes to the chat shown.

void main() {
  testWidgets('typed in A, then B: A keeps its text, B’s box is B’s and '
      'sends to B', (tester) async {
    viewport(tester, const Size(1400, 800));
    final fake = FakeDaemon([
      chat('a', 'claude', 'Fix the login redirect'),
      chat('b', 'claude', 'Write the release notes'),
    ]);
    final d = await fake.connect(tester);
    d.select('a');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Half a thought for A');

    d.select('b');
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Half a thought for A'),
      findsNothing,
    );
    await tester.enterText(find.byType(TextField), 'Notes, please');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final sent = fake.calls.whereType<SendPromptRequest>().single;
    expect((sent.chatId, sent.text), ('b', 'Notes, please'));
    expect(d.chats['a']!.draft.text.text, 'Half a thought for A');
    expect(d.chats['b']!.draft.text.text, isEmpty);

    d.select('a');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Half a thought for A'), findsOne);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
