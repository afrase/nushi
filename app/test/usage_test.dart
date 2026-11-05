import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/usage.dart';

import 'harness.dart';

void main() {
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
    Future<void> show(ContextMeter m) =>
        tester.pumpWidget(themed(Center(child: m)));
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
