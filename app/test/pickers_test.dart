import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/settings.dart';
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

  testWidgets('the model menu puts the models picked last first', (
    tester,
  ) async {
    var current = 'a';
    final names = {
      for (final v in 'abcdef'.split('')) v: 'Model ${v.toUpperCase()}',
    };
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Pickers(
            options: [
              ConfigOption(
                id: 'model',
                category: 'model',
                current: current,
                values: [
                  for (final MapEntry(:key, :value) in names.entries)
                    ConfigValue(value: key, name: value),
                ],
              ),
            ],
            onPick: (id, value) async => current = value,
          ),
        ),
      ),
    );
    Future<List<String>> top() async {
      await tester.tap(find.text(names[current]!).first);
      await tester.pumpAndSettle();
      // The menu's rows, top to bottom (the field's own label aside).
      double y(String n) => tester.getTopLeft(find.text(n).last).dy;
      return [
        for (final n in names.values)
          if (find.text(n).evaluate().length > (n == names[current] ? 1 : 0)) n,
      ]..sort((a, b) => y(a).compareTo(y(b)));
    }

    await show();
    expect(await top(), ['Model A', 'Model B', 'Model C', 'Model D']);
    // Model F, from More models, then back to A: both lead.
    await tester.tap(find.text('More models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model F'));
    await tester.pumpAndSettle();
    await show();
    expect(recentModels.value, ['f']);
    await tester.tap(find.text('Model F').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Model A').last);
    await tester.pumpAndSettle();
    await show();
    expect(recentModels.value, ['a', 'f']);
    expect(await top(), ['Model A', 'Model F', 'Model B', 'Model C']);
  });
}
