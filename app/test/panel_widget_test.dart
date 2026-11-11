import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/panel_widgets.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);
  _goldens();

  testWidgets('the title row: the open hand, and under the pointer the '
      "grip on the right in the summary's place, left of a button", (
    tester,
  ) async {
    collapsedWidgets.value = {'Context'};
    await tester.pumpWidget(_widgets(Tokens.dark));
    expect(find.text('57%'), findsOneWidget);
    expect(find.byType(DragGrip), findsNothing, reason: 'flat at rest');
    final summary = tester.getRect(find.text('57%'));

    final mouse = await _pointer(tester);
    await mouse.moveTo(tester.getCenter(find.text('Context')));
    await tester.pumpAndSettle();
    expect(_cursor(), SystemMouseCursors.grab);
    expect(find.byType(DragGrip), findsOneWidget);
    expect(find.text('57%'), findsNothing, reason: 'the grip in its place');
    final grip = tester.getRect(find.byType(DragGrip));
    expect(grip.right, moreOrLessEquals(summary.right, epsilon: 1));
    expect(grip.center.dy, moreOrLessEquals(summary.center.dy, epsilon: 2));

    // An open widget's button stays, to be clicked; the grip left of it.
    await mouse.moveTo(tester.getCenter(find.text('npm test')));
    await tester.pumpAndSettle();
    expect(_cursor(), isNot(SystemMouseCursors.grab));
    expect(find.text('57%'), findsOneWidget);
    expect(find.text('Stop all'), findsOneWidget);
    expect(
      tester.getRect(find.byType(DragGrip)).right,
      lessThan(tester.getRect(find.text('Stop all')).left),
    );

    // Off the cards, in the gap under the first.
    await mouse.moveTo(
      tester.getRect(find.byType(PanelWidget).first).bottomLeft +
          const Offset(4, -NushiTheme.paneGap / 2),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DragGrip), findsNothing);
    expect(find.text('57%'), findsOneWidget);
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
    expect(find.byType(DragGrip), findsWidgets, reason: 'dragged');
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

  // The pointer leaving the widget for the menu once rebuilt the action
  // in another place, which closed its menu before a row could be picked.
  testWidgets("a widget's menu stays open as the pointer goes onto it, the "
      'grip with it, and its row picks', (tester) async {
    collapsedWidgets.value = {};
    viewport(tester, const Size(800, 400));
    var picked = false;
    await tester.pumpWidget(
      themed(
        Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: 320,
            child: PanelWidgets([
              PanelWidget(
                title: 'Pull request',
                action: MenuIcon(
                  Icons.more_horiz,
                  tooltip: 'Pull request',
                  entries: [
                    MenuEntry('Open on GitHub', onPick: () {}),
                    MenuEntry('Unlink', onPick: () => picked = true),
                  ],
                ),
                rows: const [(null, 'a row')],
              ),
            ]),
          ),
        ),
      ),
    );
    final mouse = await _pointer(tester);
    final more = tester.getCenter(find.byIcon(Icons.more_horiz));
    await mouse.moveTo(more);
    await tester.pumpAndSettle();
    await mouse.down(more);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Unlink'), findsOneWidget, reason: 'open');
    final grip = tester.getRect(find.byType(DragGrip));

    final row = tester.getCenter(find.text('Unlink'));
    await mouse.moveTo(Offset(more.dx, row.dy)); // off the widget, onto it
    await tester.pumpAndSettle();
    await mouse.moveTo(row);
    await tester.pumpAndSettle();
    expect(find.text('Unlink'), findsOneWidget, reason: 'still open');
    expect(tester.getRect(find.byType(DragGrip)), grip, reason: 'held');

    await mouse.down(row);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(picked, isTrue);
    expect(find.text('Unlink'), findsNothing);
    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byType(DragGrip), findsNothing, reason: 'flat again');
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
