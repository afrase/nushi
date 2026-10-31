import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/plain_tabs.dart';
import 'package:nushi/preview_marks.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _labels = [(0, 'Chat'), (1, 'Changes 12'), (2, 'Pull request')];

Widget _themed(Widget child) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: Scaffold(body: Center(child: child)),
);

PlainTabs<int> _tabs(ValueChanged<int> onChanged, {bool fill = false}) =>
    PlainTabs(value: 0, tabs: _labels, onChanged: onChanged, fill: fill);

/// The focus ring's box on the tab labelled [label], if it's drawn.
Decoration? _ring(WidgetTester tester, String label) => tester
    .widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .last,
    )
    .foregroundDecoration;

void main() {
  setUpAll(loadFonts);

  testWidgets('measures what the pill measures, labels where its were', (
    tester,
  ) async {
    viewport(tester, const Size(800, 300));
    await tester.pumpWidget(
      _themed(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Segmented(value: 0, segments: _labels, onChanged: (_) {}),
            _tabs((_) {}),
          ],
        ),
      ),
    );
    final pill = tester.getRect(find.byType(Segmented<int>));
    final tabs = tester.getRect(find.byType(PlainTabs<int>));
    expect(tabs.size, pill.size);
    for (final (_, label) in _labels) {
      final found = find.text(label);
      expect(
        tester.getTopLeft(found.last).dx - tabs.left,
        tester.getTopLeft(found.first).dx - pill.left,
      );
    }
  });

  testWidgets('fill takes its row, the line on the row’s bottom edge', (
    tester,
  ) async {
    viewport(tester, const Size(800, 300));
    await tester.pumpWidget(
      _themed(
        SizedBox(height: 33, child: Row(children: [_tabs((_) {}, fill: true)])),
      ),
    );
    final tabs = tester.getRect(find.byType(PlainTabs<int>));
    expect(tabs.height, 33);
    final line = find.descendant(
      of: find.byType(TabFace),
      matching: find.byType(Positioned),
    );
    expect(line, findsOneWidget);
    expect(tester.getRect(line).bottom, tabs.bottom);
    expect(tester.getRect(line).height, 2);
    expect(tester.getCenter(find.text('Chat')).dy, tabs.center.dy);
  });

  testWidgets('a click and the keyboard pick; focus wears the ring', (
    tester,
  ) async {
    viewport(tester, const Size(800, 300));
    final picked = <int>[];
    await tester.pumpWidget(_themed(_tabs(picked.add)));
    await tester.tap(find.text('Changes 12'));
    expect(picked, [1]);

    expect(_ring(tester, 'Chat'), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, 'Chat'), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(tester, 'Chat'), isNull);
    expect(_ring(tester, 'Changes 12'), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(picked, [1, 1]);
  });

  testWidgets('says which one shows', (tester) async {
    viewport(tester, const Size(800, 300));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_themed(_tabs((_) {})));
    expect(
      tester.getSemantics(find.text('Chat')),
      isSemantics(label: 'Chat', isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Changes 12')),
      isSemantics(label: 'Changes 12', isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('Preview and Source: tabs on the Mac and the phone', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final source = SourceSwitch(source: false, onChanged: (_) {});
    await tester.pumpWidget(_themed(SizedBox(height: 33, child: source)));
    expect(find.byType(PlainTabs<bool>), findsOneWidget);
    await tester.pumpWidget(
      _themed(TouchTargets(child: SizedBox(height: 56, child: source))),
    );
    expect(find.byType(PlainTabs<bool>), findsOneWidget);
    expect(find.byType(Segmented<bool>), findsNothing);
    expect(
      tester.getSize(find.byType(Pressable).first).height,
      greaterThanOrEqualTo(TouchTargets.size),
    );
  });
}
