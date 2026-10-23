import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a long menu filters as you type; arrows and Enter pick', (
    tester,
  ) async {
    String? picked;
    final names = ['apple', 'banana', 'cherry', 'date', 'elderberry', 'fig'];
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Menu(
            entries: [
              for (final n in names)
                for (final c in ['red', 'green'])
                  MenuEntry('$c $n', onPick: () => picked = '$c $n'),
            ],
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget); // 12 rows: filtered

    await tester.enterText(find.byType(TextField), 'erry');
    await tester.pump();
    expect(find.textContaining('cherry'), findsNWidgets(2));
    expect(find.textContaining('apple'), findsNothing);

    // red cherry, green cherry, red elderberry, ...: the second one down.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, 'green cherry');
    expect(find.text('Filter'), findsNothing); // closed

    // Escape clears the field first, then closes.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'fig');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining('apple'), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsNothing);
  });
}
