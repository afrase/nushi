import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/panel_cards.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_inbox_test.dart' show inboxForTests;
import 'github_view_test.dart' show openView;
import 'harness.dart';

/// The cards' titles, top to bottom.
List<String> _cards(WidgetTester tester) {
  final titles = find.textContaining(RegExp(r'^[A-Za-z ]+  \d+$'));
  return [
    for (final e
        in titles.evaluate().toList()..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a.widget))
              .dy
              .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
        ))
      (e.widget as Text).data!.split('  ').first,
  ];
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });
  tearDown(() {
    githubCardOrder.value = [];
    githubCollapsed.value = {};
  });

  testWidgets('a card is dragged by its title into another place, '
      'remembered; the keys follow', (tester) async {
    var (_, d) = await openView(tester);
    expect(_cards(tester), [
      'Review requested',
      'My pull requests',
      'Assigned issues',
    ]);
    final drag = await tester.startGesture(
      tester.getCenter(find.text('Assigned issues  1')),
    );
    final top = tester.getTopLeft(find.text('Review requested  1')).dy - 30;
    while (true) {
      await drag.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.getCenter(find.text('Assigned issues  1')).dy < top) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    final order = ['Assigned issues', 'Review requested', 'My pull requests'];
    expect(_cards(tester), order);
    expect(githubCardOrder.value, ['assigned', 'review', 'mine']);
    expect(readSaved()['githubCards'], ['assigned', 'review', 'mine']);
    await closeView(tester, d);
    // Opened again: as left; the first row is the issue's, and ↓ goes to
    // Review requested's.
    final FakeDaemon fake;
    (fake, d) = await openView(tester, keep: true);
    expect(_cards(tester), order);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(GitHubPullPane), findsOneWidget);
    expect(fake.calls.whereType<GetGitHubPullRequest>().single.ref.number, 41);
    await closeView(tester, d);
  });

  testWidgets('a collapsed card: its rows hidden, skipped by the keys, '
      'remembered', (tester) async {
    var (_, d) = await openView(tester);
    await tester.tap(find.text('My pull requests  2'));
    await tester.pumpAndSettle();
    expect(find.text('Add Sub and Neg'), findsNothing);
    expect(find.text('My pull requests  2'), findsOneWidget);
    expect(githubCollapsed.value, {'mine'});
    expect(readSaved()['githubCollapsed'], ['mine']);
    // From Review requested's row, ↓ goes past it to the issue.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Shall I take it?'), findsOneWidget);
    await closeView(tester, d);
    (_, d) = await openView(tester, keep: true);
    expect(find.text('Add Sub and Neg'), findsNothing);
    await tester.tap(find.text('My pull requests  2'));
    await tester.pumpAndSettle();
    expect(find.text('Add Sub and Neg'), findsOneWidget);
    expect(githubCollapsed.value, isEmpty);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: three cards, one collapsed, $name', (tester) async {
      githubCollapsed.value = {'mine'};
      final (_, d) = await openView(
        tester,
        tokens: tokens,
        size: const Size(900, 480),
        keep: true,
        inbox: inboxForTests(),
      );
      await expectLater(
        find.byType(GitHubView),
        matchesGoldenFile('goldens/github_cards_$name.png'),
      );
      await closeView(tester, d);
    });

    testWidgets('golden: a row at rest, hovered and selected, $name', (
      tester,
    ) async {
      final (_, d) = await openView(
        tester,
        tokens: tokens,
        size: const Size(760, 480),
        inbox: inboxForTests(),
      );
      // The first row is selected; the second is hovered; the third rests.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Retry flaky uploads')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Start work (⌘⏎)'), findsOneWidget);
      expect(find.byTooltip('Start work'), findsOneWidget); // the hovered
      await expectLater(
        find.byType(CardShell).first,
        matchesGoldenFile('goldens/github_row_states_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
