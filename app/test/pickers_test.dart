import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('Ultracode shows beside the pickers while on, and is in ⋯', (
    tester,
  ) async {
    Future<void> pick(String current) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Scaffold(
            body: Pickers(
              options: [
                ConfigOption(
                  id: 'model',
                  category: 'model',
                  current: 'opus',
                  values: [ConfigValue(value: 'opus', name: 'Opus 5.5')],
                ),
                ConfigOption(
                  id: 'nushi:ultracode',
                  name: 'Ultracode',
                  category: 'ultracode',
                  type: 'boolean',
                  current: current,
                  description: 'Standing multi-agent workflows',
                ),
              ],
              onPick: (id, value) async {},
            ),
          ),
        ),
      );
    }

    await pick('false');
    expect(find.text('Ultracode'), findsNothing);
    await pick('true');
    expect(find.text('Ultracode'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    // Its row: the option, and its value dimmed.
    expect(find.text('Ultracode   On', findRichText: true), findsOneWidget);
  });
}
