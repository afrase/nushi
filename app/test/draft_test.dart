import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('what is written outlives the box, and a take-back lands in it', (
    tester,
  ) async {
    final daemon = Daemon();
    final chat = ChatState('c', '/tmp');
    Future<void> show(bool box) => tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: box
              ? Composer(chat: chat, daemon: daemon)
              : const Text('Changes'),
        ),
      ),
    );
    await show(true);
    await tester.enterText(find.byType(TextField), 'half a thought');
    await show(false); // a peek at Changes, or another chat
    chat.takeBack.value = QueuedMessage(text: 'taken back');
    await show(true);
    expect(chat.draft.text.text, 'half a thought\n\ntaken back');
    expect(find.text('half a thought\n\ntaken back'), findsOneWidget);
    await show(false);
    daemon.dispose(); // its ping timer
  });
}
