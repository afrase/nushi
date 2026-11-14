import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/arrangement.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_arrange.dart';
import 'package:nushi/sidebar_group_header.dart';
import 'package:nushi/sidebar_rows.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'sidebar_fixture.dart';

// Each project sorts its own way from the Sort button on its header (ADR
// 0118), as Claude desktop's Group and sort; one that hasn't picked sorts
// as the sidebar does, which stays the default.

Chat _chat(String id, String title, String folder, int made, int updated) =>
    Chat(
      id: id,
      agent: 'claude',
      title: title,
      folder: folder,
      createdUnixMs: Int64(
        fixtureNow.subtract(Duration(hours: made)).millisecondsSinceEpoch,
      ),
      updatedUnixMs: Int64(
        fixtureNow.subtract(Duration(hours: updated)).millisecondsSinceEpoch,
      ),
      status: ChatStatus(),
    );

/// Two projects: nushi's chats made Beta, Alpha, Gamma (the newest
/// first), Gamma updated last; site's Delta, Echo.
List<Chat> _chats() => [
  _chat('b', 'Beta', '/Users/me/nushi', 1, 5),
  _chat('a', 'Alpha', '/Users/me/nushi', 2, 4),
  _chat('g', 'Gamma', '/Users/me/nushi', 3, 0),
  _chat('d', 'Delta', '/Users/me/site', 4, 4),
  _chat('e', 'Echo', '/Users/me/site', 5, 3),
];

const _titles = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Echo'];

const _nushi = '/Users/me/nushi';

/// The Sort button of the project named [name].
Finder _sortOf(String name) => find.descendant(
  of: find.ancestor(
    of: find.text(name, findRichText: true),
    matching: find.byType(GroupHeader),
  ),
  matching: find.byTooltip(RegExp('^Sort this project')),
);

/// A menu row labelled [label], its detail after it or not.
Finder _row(String label) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      switch (w.textSpan?.toPlainText() ?? w.data) {
        final text? => text == label || text.startsWith('$label   '),
        null => false,
      },
);

void main() {
  setUpAll(loadFonts);

  testWidgets('a project sorted its own way; the rest as the sidebar', (
    tester,
  ) async {
    final (d, _) = await arrangedSidebar(tester, chats: _chats());
    // By hand at first: the newest first.
    expect(shownInOrder(tester, _titles), [
      'Beta',
      'Alpha',
      'Gamma',
      'Delta',
      'Echo',
    ]);
    projectSorts.value = {_nushi: const ProjectSort(SortBy.name)};
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, _titles), [
      'Gamma',
      'Beta',
      'Alpha',
      'Delta',
      'Echo',
    ]);
    // The sidebar's sort for the others: site by when updated, oldest
    // first.
    sidebarSort.value = SortBy.updated;
    sidebarAscending.value = true;
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, _titles), [
      'Gamma',
      'Beta',
      'Alpha',
      'Delta',
      'Echo',
    ]);
    sidebarAscending.value = false;
    await tester.pumpAndSettle();
    expect(shownInOrder(tester, _titles).skip(3), ['Echo', 'Delta']);
    // Its chats drag into an order only in a project sorted by hand.
    projectSorts.value = {_nushi: const ProjectSort(SortBy.manual)};
    sidebarSort.value = SortBy.name;
    await tester.pumpAndSettle();
    bool drags(String folder) => tester
        .widget<MovableRows>(
          find.byWidgetPredicate((w) => w is MovableRows && w.group == folder),
        )
        .reorders;
    expect(drags(_nushi), isTrue);
    expect(drags('/Users/me/site'), isFalse);
    d.dispose();
  });

  testWidgets('its header’s Sort button: under the pointer, its menu, kept '
      'in app.json by folder; in the accent while it’s its own', (
    tester,
  ) async {
    final (d, _) = await arrangedSidebar(tester, chats: _chats());
    final button = tester.widget<Opacity>(
      find.ancestor(of: _sortOf('nushi'), matching: find.byType(Opacity)).first,
    );
    expect(button.opacity, 0, reason: 'not under the pointer');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('nushi')));
    addTearDown(mouse.removePointer);
    await tester.pump();
    await tester.tap(_sortOf('nushi'));
    await tester.pumpAndSettle();
    expect(_row('Sidebar’s sort'), findsOneWidget);
    await tester.tap(_row('Name').last);
    await tester.pumpAndSettle();
    expect(projectSorts.value, {
      _nushi: const ProjectSort(SortBy.name, ascending: true),
    });
    expect(shownInOrder(tester, _titles).take(3), ['Alpha', 'Beta', 'Gamma']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(readSaved()['projectSorts'], {
      _nushi: {'sort': 'name', 'ascending': true},
    });
    // Away from it, it stays, saying it sorts its own way.
    await mouse.moveTo(const Offset(500, 690));
    await tester.pump();
    final shown = find
        .ancestor(of: _sortOf('nushi'), matching: find.byType(Opacity))
        .first;
    expect(tester.widget<Opacity>(shown).opacity, 1);
    expect(find.byTooltip('Sort this project (Name)'), findsOneWidget);
    // Back to the sidebar's.
    await tester.tap(_sortOf('nushi'));
    await tester.pumpAndSettle();
    await tester.tap(_row('Sidebar’s sort').last);
    await tester.pumpAndSettle();
    expect(projectSorts.value, isEmpty);
    d.dispose();
  });

  test('a project removed from the sidebar forgets its sort; Reset clears '
      'them all; an older app’s saved sort stays the default', () {
    sidebarSort.value = SortBy.updated; // as an existing user saved it
    projectSorts.value = {
      _nushi: const ProjectSort(SortBy.name),
      '/Users/me/site': const ProjectSort(SortBy.created, ascending: true),
    };
    forgetProject(_nushi);
    expect(projectSorts.value.keys, ['/Users/me/site']);
    expect(arrangedAsDefault, isFalse);
    resetArrangement();
    expect(projectSorts.value, isEmpty);
    expect(
      ProjectSort.read({'sort': 'updated', 'ascending': true}),
      const ProjectSort(SortBy.updated, ascending: true),
    );
    expect(ProjectSort.read({'sort': 'nope'}), isNull);
    expect(ProjectSort.read('name'), isNull);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: a project sorted its own way, its menu open '
        '($name)', (tester) async {
      projectSorts.value = {_nushi: const ProjectSort(SortBy.updated)};
      final (d, _) = await arrangedSidebar(
        tester,
        chats: _chats(),
        tokens: tokens,
      );
      await tester.tap(_sortOf('nushi'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/project_sort_menu_$name.png'),
      );
      d.dispose();
    });
  }

  group('renders', () {
    for (final width in [1700.0, 720.0]) {
      for (final b in Brightness.values) {
        testWidgets('the window, a project’s Sort menu open, $width wide, '
            '${b.name}', (tester) async {
          viewport(tester, Size(width, 700), brightness: b);
          paneWidths.value = {};
          projectSorts.value = {_nushi: const ProjectSort(SortBy.updated)};
          final d = await FakeDaemon(_chats()).connect(tester);
          d.select('a');
          await tester.pumpWidget(NushiApp(daemon: d));
          await tester.pumpAndSettle();
          await tester.tap(_sortOf('nushi'));
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            'project_sort_${width.toInt()}_${b.name}',
          );
          d.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
      }
    }
  });
}
