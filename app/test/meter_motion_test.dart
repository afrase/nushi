import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/usage.dart';

Widget _app(double fill, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(
      body: Center(
        child: ContextMeter(
          Usage(
            contextSize: Int64(1000),
            contextUsed: Int64((fill * 1000).round()),
          ),
        ),
      ),
    ),
  ),
);

double _width(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

String _figure(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data!).single;

void main() {
  testWidgets('the fill eases to its new width; the figure says the new one '
      'at once', (tester) async {
    await tester.pumpWidget(_app(0.4));
    await tester.pumpWidget(_app(0.6));
    expect(_figure(tester), '60%');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_width(tester), inExclusiveRange(0.4, 0.6));
    await tester.pumpAndSettle();
    expect(_width(tester), 0.6);
  });

  testWidgets('a compaction drains it, the figure counting down with it; '
      'its color crossfades', (tester) async {
    await tester.pumpWidget(_app(0.92));
    final red = tester.widget<Text>(find.text('92%')).style!.color;
    expect(red, Tokens.dark.crashed);
    await tester.pumpWidget(_app(0.19));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 250));
    final n = int.parse(_figure(tester).replaceAll('%', ''));
    expect(n, inExclusiveRange(19, 92));
    expect(_width(tester), inExclusiveRange(0.19, 0.92));
    await tester.pumpAndSettle();
    expect(_figure(tester), '19%');
    expect(
      tester.widget<Text>(find.text('19%')).style!.color,
      Tokens.dark.textMuted,
    );
  });

  testWidgets('with Reduce Motion it jumps', (tester) async {
    await tester.pumpWidget(_app(0.92, still: true));
    await tester.pumpWidget(_app(0.19, still: true));
    expect(_figure(tester), '19%');
    expect(_width(tester), 8 / 22);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
