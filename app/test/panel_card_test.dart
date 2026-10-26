import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets("a card's action sits on its title row while open", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: PanelCard(
              title: 'Context',
              summary: Text('4%'),
              action: Icon(Icons.refresh),
              rows: [(null, 'a row')],
            ),
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text('Context'));
    final action = tester.getRect(find.byIcon(Icons.refresh));
    expect(action.center.dy, closeTo(title.center.dy, 2));
    expect(action.top, lessThan(tester.getRect(find.text('a row')).top));
    expect(find.text('4%'), findsNothing);

    await tester.tap(find.text('Context')); // collapsed: the summary instead
    await tester.pump();
    expect(find.text('4%'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    collapsedCards.value = {};
  });
}
