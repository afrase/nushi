import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';

void main() {
  test('deferred rows stay out of the bar, and the shares add up', () {
    ContextCategory c(String name, int tokens, {String kind = ''}) =>
        ContextCategory(name: name, tokens: Int64(tokens), kind: kind);
    final all = [
      c('System prompt', 2000),
      c('Tools', 14500),
      c('Tools', 327000, kind: 'deferred'),
      c('Messages', 193000),
      c('Free space', 739000, kind: 'free'),
    ];
    final shares = contextShares(all);
    expect([for (final s in shares) s.$1.kind], isNot(contains('deferred')));
    expect(shares.length, 4);
    expect(shares.fold(0.0, (n, s) => n + s.$2), closeTo(1, 1e-9));
    final messages = shares.firstWhere((s) => s.$1.name == 'Messages').$2;
    expect(messages, closeTo(193000 / 948500, 1e-9));
    expect(contextShares([c('Tools', 5, kind: 'deferred')]), isEmpty);
  });
  test('what /context lists says how full it is, without the free space, '
      'the buffer or the deferred', () {
    ContextCategory c(String name, int tokens, {String kind = ''}) =>
        ContextCategory(name: name, tokens: Int64(tokens), kind: kind);
    expect(
      breakdownFill([
        c('System prompt', 5000),
        c('Messages', 100000),
        c('Tools', 327000, kind: 'deferred'),
        c('Autocompact buffer', 45000),
        c('Free space', 850000, kind: 'free'),
      ]),
      closeTo(105000 / 1000000, 1e-9),
    );
    expect(breakdownFill([]), isNull);
  });

  testWidgets('the meter: a percentage from the usage, else from /context, '
      'else nothing', (tester) async {
    Future<void> show(ContextMeter m) => tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(body: Center(child: m)),
      ),
    );
    await show(
      ContextMeter(
        Usage(contextUsed: Int64(105100), contextSize: Int64(1000000)),
      ),
    );
    expect(find.text('11%'), findsOneWidget);
    await show(
      ContextMeter(
        Usage(),
        breakdown: GetContextUsageResponse(
          categories: [
            ContextCategory(name: 'Messages', tokens: Int64(30000)),
            ContextCategory(
              name: 'Free space',
              tokens: Int64(70000),
              kind: 'free',
            ),
          ],
        ),
      ),
    );
    expect(find.text('30%'), findsOneWidget);
    await show(ContextMeter(Usage()));
    expect(find.byType(Text), findsNothing);
  });
}
