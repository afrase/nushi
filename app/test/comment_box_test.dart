import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/comment_box.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('the box: its button waits for text; ⌘⏎ posts it; a refused '
      'post keeps the text and says why; Esc cancels', (tester) async {
    final posted = <String>[];
    var cancelled = 0;
    var refuse = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.light).toThemeData(),
        home: Scaffold(
          body: CommentBox(
            label: 'Reply',
            autofocus: true,
            onCancel: () => cancelled++,
            onPost: (md) async {
              if (refuse) throw StateError('no');
              posted.add(md);
            },
          ),
        ),
      ),
    );
    Button reply() =>
        tester.widget<Button>(find.widgetWithText(Button, 'Reply'));
    Future<void> commandEnter() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
    }

    expect(reply().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Done.  ');
    await tester.pump();
    expect(reply().onPressed, isNotNull);

    await commandEnter();
    expect(posted, isEmpty);
    expect(find.text('Bad state: no'), findsOneWidget);
    expect(find.text('  Done.  '), findsOneWidget); // kept

    refuse = false;
    await commandEnter();
    expect(posted, ['Done.']);
    expect(find.text('Bad state: no'), findsNothing);
    expect(find.text('  Done.  '), findsNothing); // cleared

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancelled, 1);
  });
}
