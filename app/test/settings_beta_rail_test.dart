import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_rail.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sidebar_view.dart';

import 'fake_daemon.dart';
import 'project_tile_fixture.dart';
import 'sidebar_fixture.dart';

// An `app.json` of v0.30.0-beta.1, where the project rail was on at
// first: it saved `projectRail: true` for everyone, and here a picked
// project. The rail is off at first now (ADR 0112), for them too.

void main() {
  setUpAll(() async {
    await loadFonts();
    // Read before anything else is.
    Directory(dataDir).createSync(recursive: true); // the tests' own
    File('$dataDir/app.json').writeAsStringSync(
      jsonEncode({
        'projectRail': true,
        'sidebarProject': cappy,
        'sidebarProjects': [ledger, cappy, garden, notes, attic],
        'projectTiles': {
          garden: {'mark': 'G7', 'color': 'amber'},
        },
      }),
    );
  });

  testWidgets('a beta’s rail, on for everyone, is off; its pick narrows '
      'nothing; the tiles set are kept; the old key goes with a save', (
    tester,
  ) async {
    expect(projectRail.value, isFalse);
    expect(sidebarProject.value, cappy);
    expect(shownProject, isNull);
    expect(projectTiles.value[garden]?.toJson(), {
      'mark': 'G7',
      'color': 'amber',
    });
    final (d, _) = await arrangedSidebar(tester);
    expect(find.byType(ProjectRail), findsNothing);
    expect(shownInOrder(tester, arrangeTitles), hasLength(6));
    expect(find.text('G7'), findsOneWidget);

    // Turned on in Settings, the pick is as it was left.
    projectRail.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(ProjectRail), findsOneWidget);
    expect(shownInOrder(tester, arrangeTitles), ['Cap the rates']);
    final saved = readSaved();
    expect(saved.containsKey('projectRail'), isFalse);
    expect(saved['projectRailOn'], isTrue);
    d.dispose();
  });
}
