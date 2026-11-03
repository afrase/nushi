import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/thinking.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: child),
      ),
    ),
  ),
);

/// A box that opens and closes [_Body] with its chevron, as every
/// disclosure in the app does.
class _Box extends StatefulWidget {
  const new();

  @override
  State<_Box> createState() => _BoxState();
}

class _BoxState extends State<_Box> {
  bool open = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Tap(
        onTap: () => setState(() => open = !open),
        child: Row(
          children: [
            TurnChevron(open: open),
            const Text('Head'),
          ],
        ),
      ),
      Disclosure(open: open, child: const _Body()),
      const Text('Below'),
    ],
  );
}

class _Body extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF336699), child: SizedBox(height: 100));
}

final Finder _turning = find.descendant(
  of: find.byType(TurnChevron),
  matching: find.byType(RotationTransition),
);

double _height(WidgetTester tester) =>
    tester.getSize(find.byType(Disclosure)).height;

void main() {
  setUpAll(loadFonts);

  testWidgets('a disclosure grows open as its chevron turns, folds back, and '
      'isn’t built folded', (tester) async {
    await tester.pumpWidget(_app(const _Box()));
    expect(find.byType(_Body), findsNothing);
    final below = tester.getTopLeft(find.text('Below')).dy;

    await tester.tap(find.text('Head'));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 2);
    final mid = _height(tester);
    expect(mid, inExclusiveRange(10, 95));
    expect(tester.getTopLeft(find.text('Below')).dy, below + mid);
    // The chevron is turning, part way.
    final turn = tester.widget<RotationTransition>(_turning);
    expect(turn.turns.value, inExclusiveRange(0.02, 0.24));
    // Stretched as without it, not shrunk to its child.
    expect(tester.getSize(find.byType(_Body)).width, 300);

    await tester.pumpAndSettle();
    expect(_height(tester), 100);
    expect(_turning, findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.text('Head'));
    await tester.pumpAndSettle();
    expect(find.byType(_Body), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(tester.getTopLeft(find.text('Below')).dy, below);
  });

  testWidgets('a second click mid-way folds back from where it is, and the '
      'head takes clicks throughout', (tester) async {
    await tester.pumpWidget(_app(const _Box()));
    await tester.tap(find.text('Head'));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 2);
    final mid = _height(tester);
    await tester.tap(find.text('Head'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    // Folding from the middle: a little less, not the whole height.
    expect(_height(tester), inExclusiveRange(mid - 30, mid));
    await tester.pumpAndSettle();
    expect(find.byType(_Body), findsNothing);
  });

  testWidgets('with Reduce Motion it opens and folds at once', (tester) async {
    await tester.pumpWidget(_app(const _Box(), still: true));
    await tester.tap(find.text('Head'));
    await tester.pump();
    expect(_height(tester), 100);
    expect(_turning, findsNothing);
    await tester.tap(find.text('Head'));
    await tester.pump();
    expect(find.byType(_Body), findsNothing);
  });

  testWidgets('a details card opens through a disclosure', (tester) async {
    var open = false;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, set) => CardShell(
            title: const Text('Card'),
            open: open,
            onToggle: () => set(() => open = !open),
            body: const _Body(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Card'));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 2);
    expect(_height(tester), inExclusiveRange(10, 95));
    await tester.pumpAndSettle();
    expect(_height(tester), 100);
  });

  testWidgets('Thinking opens through a disclosure, its newest line folding '
      'as the thoughts open', (tester) async {
    final item = Item(
      id: 't',
      kind: ItemKind.ITEM_KIND_THOUGHT,
      text: 'First I look at the tests. Then I fix the clock.',
    );
    await tester.pumpWidget(_app(ThoughtView(item, live: false)));
    expect(find.text(item.text), findsNothing);
    await tester.tap(find.text('Thought'));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 2);
    expect(find.text(item.text), findsOneWidget);
    final opening = tester.getSize(find.byType(Disclosure).last).height;
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(Disclosure).last).height,
      greaterThan(opening),
    );
  });
}
