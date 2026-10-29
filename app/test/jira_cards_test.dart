import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_view.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'jira_view_test.dart' show openView, shown;

const _site = 'acme.atlassian.net';

/// The status cards' titles, top to bottom.
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

  testWidgets('a card is dragged by its title into another place, '
      'remembered for the site', (tester) async {
    final (_, d) = await openView(tester);
    expect(_cards(tester), ['To Do', 'In Progress', 'Done']);
    final drag = await tester.startGesture(
      tester.getCenter(find.text('Done  1')),
    );
    final top = tester.getTopLeft(find.text('To Do  1')).dy - 30;
    while (true) {
      await drag.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.getCenter(find.text('Done  1')).dy < top) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(_cards(tester), ['Done', 'To Do', 'In Progress']);
    expect(jiraGroupOrder.value, {
      _site: ['Done', 'To Do', 'In Progress'],
    });
    expect((readSaved()['jiraGroups']! as Map)[_site], [
      'Done',
      'To Do',
      'In Progress',
    ]);
    // The keys follow the cards' order: ↑ from To Do's row is Done's.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-3');
    await closeView(tester, d);
  });

  testWidgets('a collapsed card: its rows hidden, skipped by the keys, '
      'remembered', (tester) async {
    final (_, d) = await openView(tester);
    await tester.tap(find.text('In Progress  1'));
    await tester.pumpAndSettle();
    expect(find.text('ACME-12'), findsNothing);
    expect(find.text('In Progress  1'), findsOneWidget); // the card stays
    expect(jiraCollapsed.value, {
      _site: ['In Progress'],
    });
    expect((readSaved()['jiraCollapsed']! as Map)[_site], ['In Progress']);
    // From To Do's row, ↓ goes past In Progress to Done.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-3');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Collapsing the selected row's card moves the selection on.
    await tester.tap(find.text('Done  1'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-9');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Opened again: shown again.
    await tester.tap(find.text('In Progress  1'));
    await tester.pumpAndSettle();
    expect(find.text('ACME-12'), findsOneWidget);
    expect(jiraCollapsed.value[_site], ['Done']);
    await closeView(tester, d);
  });

  testWidgets('as remembered at launch; a status Jira added since goes last; '
      "another site's choices aren't this one's", (tester) async {
    final (_, d) = await openView(
      tester,
      groups: {
        _site: ['Done', 'To Do'], // In Progress is new
        'other.atlassian.net': ['In Progress', 'To Do', 'Done'],
      },
      collapsed: {
        _site: ['To Do'],
        'other.atlassian.net': ['Done'],
      },
    );
    expect(_cards(tester), ['Done', 'To Do', 'In Progress']);
    expect(find.text('ACME-9'), findsNothing); // To Do, collapsed
    expect(find.text('ACME-3'), findsOneWidget);
    expect(find.text('ACME-12'), findsOneWidget);
    // The first row shown is picked.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-3');
    expect(find.byType(JiraIssuePane), findsOneWidget);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden, $name', (tester) async {
      final (_, d) = await openView(
        tester,
        tokens: tokens,
        size: const Size(1000, 420),
        groups: {
          _site: ['In Progress', 'To Do', 'Done'],
        },
        collapsed: {
          _site: ['Done'],
        },
      );
      await expectLater(
        find.byType(JiraView),
        matchesGoldenFile('goldens/jira_cards_$name.png'),
      );
      await closeView(tester, d);
    });
  }
}
