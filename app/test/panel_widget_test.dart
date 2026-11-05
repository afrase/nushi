import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);
  _goldens();

  testWidgets('the title row: the open hand, no grip, the summary while '
      'folded', (tester) async {
    collapsedWidgets.value = {'Context'};
    await tester.pumpWidget(_widgets(Tokens.dark));
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(DragGrip), findsNothing);

    final mouse = await _pointer(tester);
    await mouse.moveTo(tester.getCenter(find.text('Context')));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.grab);
    expect(find.byType(DragGrip), findsNothing); // ADR 0092: no grip
    expect(find.text('57%'), findsOneWidget);

    // The body isn't the handle.
    await mouse.moveTo(tester.getCenter(find.text('npm test')));
    await tester.pump();
    expect(_cursor(), isNot(SystemMouseCursors.grab));
  });

  testWidgets('a title folds its widget, remembered', (tester) async {
    collapsedWidgets.value = {};
    await tester.pumpWidget(_widgets(Tokens.light));
    expect(find.text('npm test'), findsOneWidget);
    await tester.tap(find.text('Background tasks'));
    await tester.pumpAndSettle();
    expect(find.text('npm test'), findsNothing);
    expect(find.text('1 running'), findsOneWidget); // its summary instead
    expect(collapsedWidgets.value, {'Background tasks'});
    await tester.pumpAndSettle();
    expect(readSaved()['collapsed'], ['Background tasks']);
    await tester.tap(find.text('Background tasks'));
    await tester.pumpAndSettle();
    expect(find.text('npm test'), findsOneWidget);
  });

  testWidgets('dragged by its title: the closed hand, then its new place, '
      'remembered', (tester) async {
    widgetOrder.value = [];
    await tester.pumpWidget(_widgets(Tokens.light));
    final mouse = await _pointer(tester);
    final from = tester.getCenter(find.text('Context'));
    await mouse.moveTo(from);
    await mouse.down(from);
    await tester.pump(kLongPressTimeout);
    await mouse.moveBy(const Offset(0, 30));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await mouse.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_cursor(), SystemMouseCursors.grabbing);
    expect(find.byType(DragGrip), findsNothing);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(widgetOrder.value, ['Background tasks', 'Context']);
    expect(
      tester.getTopLeft(find.text('Background tasks')).dy,
      lessThan(tester.getTopLeft(find.text('Context')).dy),
    );
  });

  testWidgets("a widget's action sits on its title row while open", (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const SizedBox(
          width: 320,
          child: PanelWidget(
            title: 'Context',
            summary: Text('4%'),
            action: Icon(Icons.refresh),
            rows: [(null, 'a row')],
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text('Context'));
    final action = tester.getRect(find.byIcon(Icons.refresh));
    expect(action.center.dy, closeTo(title.center.dy, 2));
    expect(action.top, lessThan(tester.getRect(find.text('a row')).top));
    expect(find.text('4%'), findsNothing);

    await tester.tap(find.text('Context')); // collapsed: the summary instead
    await tester.pump();
    expect(find.text('4%'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    collapsedWidgets.value = {};
  });
}

Widget _widgets(Tokens tokens) => themed(
  SizedBox(
    width: 320,
    child: PanelWidgets([
      const PanelWidget(
        title: 'Context',
        summary: Text('57%'),
        rows: [(null, 'a row')],
      ),
      PanelWidget(
        title: 'Background tasks',
        summary: const Text('1 running'),
        action: Text('Stop all', style: NushiTheme(tokens).ui(tokens.link)),
        rows: const [(null, 'npm test')],
      ),
    ]),
  ),
  tokens: tokens,
);

Future<TestGesture> _pointer(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);

void _goldens() {
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, a folded widget and an open one, $name', (
      tester,
    ) async {
      viewport(tester, const Size(320, 190), ratio: 2);
      collapsedWidgets.value = {'Context'};
      await tester.pumpWidget(_widgets(tokens));
      final mouse = await _pointer(tester);
      await mouse.moveTo(tester.getCenter(find.text('Context')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PanelWidgets),
        matchesGoldenFile('goldens/panel_widgets_$name.png'),
      );
    });
  }

  // UX review, finding 21: a widget with nothing to offer is one line.
  testWidgets('a widget with a note is one line: its title and the note, '
      'nothing to open', (tester) async {
    await tester.pumpWidget(
      themed(
        const SizedBox(
          width: 300,
          child: PanelWidget(
            title: 'Changes',
            note: 'Not a git repository',
            rows: [(null, 'hidden')],
          ),
        ),
      ),
    );
    expect(find.text('Not a git repository'), findsOne);
    expect(find.byType(Chevron), findsNothing);
    expect(find.text('hidden'), findsNothing);
    final title = tester.getRect(find.text('Changes'));
    final note = tester.getRect(find.text('Not a git repository'));
    expect(note.center.dy, closeTo(title.center.dy, 1)); // one line
  });
}
