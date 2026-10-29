import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/thought_line.dart';

import 'fake_daemon.dart';

Widget _app(String text, {required bool live, bool still = false}) =>
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: SizedBox(
            width: 360,
            child: ThoughtView(
              Item(id: 't', kind: ItemKind.ITEM_KIND_THOUGHT, text: text),
              live: live,
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadFonts);

  test("a thought's newest sentence, finished or not, plain", () {
    expect(
      latestSentence('The CI job is slow. Splitting by').text,
      'Splitting by',
    );
    expect(latestSentence('One.\nTwo, **bold**.').text, 'Two, bold.');
    expect(latestSentence('Only one so far').text, 'Only one so far');
    final a = latestSentence('First. Second');
    final b = latestSentence('First. Second grows');
    expect(a.start, b.start, reason: 'the same sentence growing');
    expect(latestSentence('First. Second. Third').start, isNot(a.start));
  });

  testWidgets('folded, the newest sentence streams under "Thinking…"; a '
      'new one slides the old up; done, it folds into "Thought for 9s"', (
    tester,
  ) async {
    await tester.pumpWidget(_app('The CI job takes 13 minutes.', live: true));
    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text('The CI job takes 13 minutes.'), findsOneWidget);

    // Its words come paced (a word whole, once the space after it came).
    await tester.pumpWidget(
      _app('The CI job takes 13 minutes. Splitting by file ', live: true),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    // Both, as one slides out and the other in.
    expect(find.text('The CI job takes 13 minutes.'), findsOneWidget);
    expect(find.textContaining(RegExp('^Splitting')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('The CI job takes 13 minutes.'), findsNothing);
    expect(find.text('Splitting by file'), findsOneWidget);

    await tester.pumpWidget(
      _app('The CI job takes 13 minutes. Splitting by file.', live: false),
    );
    // Timed by the wall clock, which a test's pumps don't move.
    expect(find.textContaining(RegExp(r'^Thought for \d+s$')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Splitting by file'), findsOneWidget); // folding
    await tester.pumpAndSettle();
    expect(find.text('Splitting by file'), findsNothing);
  });

  testWidgets('a long sentence shows its end after "…"', (tester) async {
    final long =
        'Every second file should balance the shards ${'roughly ' * 12}'
        'at the very end';
    await tester.pumpWidget(_app(long, live: true));
    final shown = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.startsWith('…'));
    expect(shown, endsWith('at the very end'));
  });

  testWidgets('one the chat loaded with says "Thought", with no line; '
      'Reduce Motion swaps and folds at once', (tester) async {
    await tester.pumpWidget(_app('Done thinking. Really.', live: false));
    expect(find.text('Thought'), findsOneWidget);
    expect(find.text('Really.'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app('One.', live: true, still: true));
    await tester.pumpWidget(_app('One. Two', live: true, still: true));
    expect(find.text('One.'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    await tester.pumpWidget(_app('One. Two.', live: false, still: true));
    expect(find.text('Two.'), findsNothing);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a thought streaming, folded, $name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(tokens).toThemeData(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: enlarged(
                const Size(320, 60),
                2,
                ColoredBox(
                  color: tokens.base,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: ThoughtView(
                      Item(
                        id: 't',
                        kind: ItemKind.ITEM_KIND_THOUGHT,
                        text:
                            'The CI job takes about 13 minutes. Splitting by '
                            'file keeps each golden with its test, and every '
                            'second file should balance the shards',
                      ),
                      live: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(FittedBox),
        matchesGoldenFile('goldens/thought_line_$name.png'),
      );
    });
  }
}
