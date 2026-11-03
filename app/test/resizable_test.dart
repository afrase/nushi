import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/beside.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  Widget beside(double cap) => MaterialApp(
    theme: const NushiTheme(Tokens.dark).toThemeData(),
    home: Beside(
      main: const SizedBox.expand(),
      least: 360,
      panes: [
        SidePane(
          'preview',
          initial: 560,
          min: 300,
          cap: cap,
          child: const SizedBox.expand(key: Key('pane')),
        ),
      ],
    ),
  );

  Offset edge(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('pane'))) + const Offset(2, 100);

  double width(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('pane'))).width;

  testWidgets('a pane with no cap drags on over the chat, to a strip of it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(beside(double.infinity));
    final drag = await tester.startGesture(edge(tester));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-1300, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(width(tester), 1400 - 48);
    await tester.pump(const Duration(seconds: 2)); // the width's saved
  });

  testWidgets('one with a cap keeps the chat its least width', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(beside(1000));
    final drag = await tester.startGesture(edge(tester));
    await drag.moveBy(const Offset(-20, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-900, 0));
    await tester.pump();
    await drag.up();
    await tester.pump();
    expect(width(tester), 1200 - 360);
    await tester.pump(const Duration(seconds: 2)); // the width's saved
  });
}
