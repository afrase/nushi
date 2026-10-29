import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/card_list.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/jira_work.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'jira_view_test.dart' show openView, shown;

final _site = JiraSite(
  id: 'acme.atlassian.net',
  url: 'https://acme.atlassian.net',
  name: 'Test User',
  accountId: 'me-1',
  board: Int64(1),
  boardName: 'ACME board',
  searches: [JiraSearch(name: 'Bugs', jql: 'type = Bug')],
);

JiraIssue _is(
  String key,
  String summary,
  String status,
  String cat, {
  String who = '',
  String id = '',
  String priority = 'Medium',
}) => JiraIssue(
  key: key,
  summary: summary,
  status: status,
  statusCategory: cat,
  assignee: who,
  assigneeId: id,
  priority: priority,
);

final List<JiraIssue> _sprint = [
  _is(
    'ABCD-12345',
    'Log in with a passkey on every device the account has, including '
        'those registered before the move to WebAuthn level 3',
    'In Progress',
    'indeterminate',
    who: 'Test User',
    id: 'me-1',
    priority: 'High',
  ),
  _is(
    'ACME-9',
    'The sidebar flickers when a chat starts',
    'To Do',
    'new',
    who: 'Ann Lee',
    id: 'ann',
  ),
  _is('ACME-31', 'Write the release notes', 'To Do', 'new', priority: 'Low'),
  _is(
    'ACME-7',
    'Move the build to the new runners',
    'Waiting for review by the platform team',
    'indeterminate',
    who: 'Bob Ng',
    id: 'bob',
    priority: 'Highest',
  ),
  _is(
    'ACME-3',
    'Rename the settings section',
    'Done',
    'done',
    who: 'Ann Lee',
    id: 'ann',
    priority: '',
  ),
  _is(
    'ACME-44',
    'Show who has each issue',
    'To Do',
    'new',
    // Names are anyone's text: a bidi override is dropped.
    who: 'Zoë \u202eQuinn',
    id: 'zoe',
  ),
];

/// The view on a site whose sprint is [_sprint]; Mine the issues assigned
/// to me, JQL two of them.
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester, {
  Size size = const Size(1700, 600),
  Tokens tokens = Tokens.dark,
}) => openView(
  tester,
  size: size,
  tokens: tokens,
  sites: [_site],
  more: (input) => switch (input) {
    ListJiraIssuesRequest(list: 'mine') => ListJiraIssuesResponse(
      issues: [
        for (final i in _sprint)
          if (i.assigneeId == 'me-1') i,
        _is(
          'OPS-1204',
          'Rotate the deploy keys before the audit, every one of them',
          'To Do',
          'new',
          who: 'Test User',
          id: 'me-1',
          priority: 'High',
        ),
      ],
    ),
    ListJiraIssuesRequest(list: 'sprint') => ListJiraIssuesResponse(
      sprint: 'Sprint 4',
      issues: _sprint,
    ),
    ListJiraIssuesRequest() => ListJiraIssuesResponse(
      issues: [_sprint[1], _sprint[2], _sprint[3]],
    ),
    _ => null,
  },
);

Future<void> _list(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _jql(WidgetTester tester) async {
  await _list(tester, 'JQL');
  await tester.enterText(find.byType(TextField).first, 'project = ACME');
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

/// Picks [who] in the assignee menu (its face says [from]).
Future<void> _filter(WidgetTester tester, String from, String who) async {
  await tester.tap(find.text(from));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(MenuItemButton),
      // The name, then how many.
      matching: find.textContaining(
        RegExp('^${RegExp.escape(who)}   \\d+\$'),
        findRichText: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The keys of the rows shown.
List<String> _keys() => [
  for (final k in [..._sprint.map((i) => i.key), 'OPS-1204'])
    if (find.text(k).evaluate().isNotEmpty) k,
];

/// The rows' columns line up across rows and cards; the trailing control
/// sits at its card's right edge; a long key isn't cut.
void _expectColumns(WidgetTester tester) {
  Set<double> xs(Finder f, Offset Function(Finder) at) => {
    for (var i = 0; i < f.evaluate().length; i++) at(f.at(i)).dx,
  };
  final pills = find.byType(StatusMenu);
  expect(pills, findsWidgets);
  expect(xs(pills, tester.getTopLeft), hasLength(1), reason: 'statuses');
  expect(
    xs(find.byType(Avatar), tester.getCenter).length,
    lessThanOrEqualTo(1),
    reason: 'assignees',
  );
  for (final k in ['ABCD-12345', 'OPS-1204']) {
    if (find.text(k).evaluate().isEmpty) continue;
    expect(
      tester.renderObject<RenderParagraph>(find.text(k)).didExceedMaxLines,
      isFalse,
      reason: '$k is cut',
    );
  }
  final play = find.byIcon(Icons.play_arrow_outlined);
  for (var i = 0; i < play.evaluate().length; i++) {
    final card = find.ancestor(
      of: play.at(i),
      matching: find.byType(CardShell),
    );
    final gap = tester.getTopRight(card).dx - tester.getTopRight(play.at(i)).dx;
    expect(gap, lessThan(14), reason: 'Start work $gap from the edge');
  }
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  test('initials, colors and plain names', () {
    expect(initials('Ann Lee'), 'AL');
    expect(initials('Ann Marie de la Cruz'), 'AC');
    expect(initials('cher'), 'C');
    expect(initials(' '), '?');
    expect(plainName('Zoë \u202eQuinn\u200b\n'), 'Zoë Quinn');
    expect(
      personColor(Tokens.dark, 'ann'),
      personColor(Tokens.dark, 'ann'), // stable
    );
    expect(Tokens.dark.avatars, contains(personColor(Tokens.dark, 'ann')));
    final colors = {
      for (final id in ['ann', 'bob', 'zoe', 'me-1', '712020:x'])
        personColor(Tokens.light, id),
    };
    expect(colors.length, greaterThan(2));
  });

  testWidgets('the sprint: an avatar each, "Unassigned" dashed, names '
      'plain on hover; Mine has none', (tester) async {
    final (_, d) = await _open(tester);
    expect(find.byType(Avatar), findsNothing); // Mine
    expect(find.byType(AssigneeMenu), findsNothing);
    await _list(tester, 'Sprint');
    expect(find.byType(Avatar), findsNWidgets(_sprint.length));
    expect(find.byTooltip('Unassigned'), findsOneWidget);
    expect(find.byTooltip('Ann Lee'), findsNWidgets(2));
    expect(find.byTooltip('Zoë Quinn'), findsOneWidget);
    expect(find.text('AL'), findsNWidgets(2));
    expect(find.text('ZQ'), findsOneWidget);
    _expectColumns(tester);
    await closeView(tester, d);
  });

  testWidgets('the filter: me, unassigned, a person, everyone; remembered '
      'per site and list', (tester) async {
    var (_, d) = await _open(tester);
    await _list(tester, 'Sprint');
    expect(_keys(), hasLength(_sprint.length));
    await _filter(tester, 'Everyone', 'Me');
    expect(_keys(), ['ABCD-12345']);
    await _filter(tester, 'Me', 'Unassigned');
    expect(_keys(), ['ACME-31']);
    await _filter(tester, 'Unassigned', 'Ann Lee');
    expect(_keys()..sort(), ['ACME-3', 'ACME-9']);
    expect(jiraAssignee.value, {
      '${_site.id} sprint': ['person', 'ann', 'Ann Lee'],
    });
    expect((readSaved()['jiraAssignee']! as Map)['${_site.id} sprint'], [
      'person',
      'ann',
      'Ann Lee',
    ]);
    // The keys move through the rows shown only.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(shown(tester), 'ACME-3');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Another list has its own.
    await _jql(tester);
    expect(find.text('Everyone'), findsOneWidget);
    expect(_keys(), hasLength(3));
    // Opened again: the sprint as left.
    await closeView(tester, d);
    (_, d) = await _open(tester);
    await _list(tester, 'Sprint');
    expect(find.text('Ann Lee'), findsOneWidget); // the menu's face
    expect(_keys()..sort(), ['ACME-3', 'ACME-9']);
    await _filter(tester, 'Ann Lee', 'Everyone');
    expect(_keys(), hasLength(_sprint.length));
    expect(jiraAssignee.value, isEmpty);
    await closeView(tester, d);
  });

  testWidgets('a person no longer in the list stays pickable; nothing '
      'left says so', (tester) async {
    jiraAssignee.value = {
      '${_site.id} sprint': ['person', 'gone', 'Cy Old'],
    };
    final (_, d) = await _open(tester);
    await _list(tester, 'Sprint');
    expect(_keys(), isEmpty);
    expect(find.text('Nothing here for Cy Old'), findsOneWidget);
    await _filter(tester, 'Cy Old', 'Everyone');
    expect(_keys(), hasLength(_sprint.length));
    await closeView(tester, d);
  });

  testWidgets('Start work: on hover and on the selected row, ⌘⏎, the '
      'right-click menu', (tester) async {
    final (_, d) = await _open(tester);
    await _list(tester, 'Sprint');
    // The selected row's only.
    expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
    expect(find.byTooltip('Start work (⌘⏎)'), findsOneWidget);
    expect(find.text('Start work'), findsNothing); // no button on every row
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.text('Move the build to the new runners')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_outlined), findsNWidgets(2));
    expect(find.byTooltip('Start work'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
    await mouse.removePointer();
    // ⌘⏎ opens the selected row's folders.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Choose folder', findRichText: true),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // A right-click on any row has it.
    await tester.tap(
      find.text('Write the release notes'),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SubmenuButton),
        matching: find.text('Start work'),
      ),
      findsOneWidget,
    );
    await closeView(tester, d);
  });

  // The Sprint list (a row hovered, the first selected), Mine, and a JQL
  // list with the filter's menu open, wide and narrow, in both themes.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final width in [1700.0, 900.0]) {
      testWidgets('golden, $width, $name', (tester) async {
        final (_, d) = await _open(
          tester,
          size: Size(width, 600),
          tokens: tokens,
        );
        Future<void> shot(String list) => expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/jira_rows_${list}_${width.toInt()}_$name.png',
          ),
        );
        _expectColumns(tester);
        await shot('mine');
        await _list(tester, 'Sprint');
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(
          tester.getCenter(find.text('Write the release notes')),
        );
        await tester.pumpAndSettle();
        _expectColumns(tester);
        await shot('sprint');
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.removePointer();
        await _jql(tester);
        _expectColumns(tester);
        // The bar's filter at the bar's right edge.
        final face = tester.getTopRight(find.byType(AssigneeMenu));
        expect(face.dx, greaterThan(width - 30));
        await tester.tap(find.text('Everyone'));
        await tester.pumpAndSettle();
        await shot('jql_filter');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await closeView(tester, d);
      });
    }
  }
}
