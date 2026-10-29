import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);
  _goldens();

  testWidgets('the title row: the open hand, and the grip while hovered, '
      "in a collapsed card in its summary's place", (tester) async {
    collapsedCards.value = {'Context'};
    await tester.pumpWidget(_cards(Tokens.dark));
    expect(find.byType(DragGrip), findsNothing);
    expect(find.text('57%'), findsOneWidget);

    final mouse = await _pointer(tester);
    await mouse.moveTo(tester.getCenter(find.text('Context')));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.grab);
    expect(find.byType(DragGrip), findsOneWidget);
    expect(find.text('57%'), findsNothing); // the grip in its place

    // An open card keeps its action; the grip goes beside it.
    await mouse.moveTo(tester.getCenter(find.text('Background tasks')));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.grab);
    expect(find.text('57%'), findsOneWidget);
    expect(find.text('Stop all'), findsOneWidget);
    expect(find.byType(DragGrip), findsOneWidget);
    expect(
      tester.getCenter(find.byType(DragGrip)).dx,
      greaterThan(tester.getCenter(find.text('Stop all')).dx),
    );

    // The body isn't the handle.
    await mouse.moveTo(tester.getCenter(find.text('npm test')));
    await tester.pump();
    expect(find.byType(DragGrip), findsNothing);
    expect(_cursor(), isNot(SystemMouseCursors.grab));
  });

  testWidgets('dragged: the closed hand and the grip', (tester) async {
    await tester.pumpWidget(_cards(Tokens.light));
    final mouse = await _pointer(tester);
    await mouse.moveTo(tester.getCenter(find.text('Context')));
    await mouse.down(tester.getCenter(find.text('Context')));
    await tester.pump(kLongPressTimeout);
    await mouse.moveBy(const Offset(0, 30));
    await tester.pump();
    await mouse.moveBy(const Offset(0, 10));
    await tester.pump();
    expect(_cursor(), SystemMouseCursors.grabbing);
    expect(find.byType(DragGrip), findsOneWidget);
    await mouse.up();
    await tester.pumpAndSettle();
  });

  testWidgets("a card's action sits on its title row while open", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: PanelCard(
              title: 'Context',
              summary: Text('4%'),
              action: Icon(Icons.refresh),
              rows: [(null, 'a row')],
            ),
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
    collapsedCards.value = {};
  });
}

Widget _cards(Tokens tokens) => MaterialApp(
  theme: NushiTheme(tokens).toThemeData(),
  home: Scaffold(
    body: SizedBox(
      width: 300,
      child: PanelCards([
        const PanelCard(
          title: 'Context',
          summary: Text('57%'),
          rows: [(null, 'a row')],
        ),
        PanelCard(
          title: 'Background tasks',
          summary: const Text('1 running'),
          action: Text('Stop all', style: NushiTheme(tokens).ui(tokens.link)),
          rows: const [(null, 'npm test')],
        ),
      ]),
    ),
  ),
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
    testWidgets('golden, a card with its grip on hover, $name', (tester) async {
      viewport(tester, const Size(300, 190), ratio: 2);
      collapsedCards.value = {'Context'};
      await tester.pumpWidget(_cards(tokens));
      final mouse = await _pointer(tester);
      await mouse.moveTo(tester.getCenter(find.text('Context')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PanelCards),
        matchesGoldenFile('goldens/card_grip_$name.png'),
      );
    });
  }

  // UX review, finding 21: a card with nothing to offer is one line.
  testWidgets('a card with a note is one line: its title and the note, '
      'nothing to open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: PanelCard(
              title: 'Changes',
              note: 'Not a git repository',
              rows: [(null, 'hidden')],
            ),
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
