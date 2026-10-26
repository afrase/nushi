import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  Future<ScrollController> list(WidgetTester tester) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const NativeScroll(),
        home: ListView.builder(
          controller: c,
          itemExtent: 40,
          itemCount: 200,
          itemBuilder: (_, i) => Text('row $i'),
        ),
      ),
    );
    return c;
  }

  testWidgets('a flick stops dead at the end: no rubber band', (tester) async {
    final c = await list(tester);
    c.jumpTo(c.position.maxScrollExtent - 100);
    await tester.fling(find.byType(ListView), const Offset(0, -600), 4000);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(c.offset, lessThanOrEqualTo(c.position.maxScrollExtent));
    }
    expect(c.offset, c.position.maxScrollExtent);
  });
}
