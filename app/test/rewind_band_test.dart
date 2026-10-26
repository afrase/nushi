import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/rewind.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a message that can be rewound keeps its row width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ListView(
            children: [
              RewindTarget(
                onRewind: () {},
                child: const ColoredBox(
                  key: ValueKey('band'),
                  color: Colors.blue,
                  child: Text('short'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The band spans the transcript, not just its text.
    expect(tester.getSize(find.byKey(const ValueKey('band'))).width, 800);
  });
}
