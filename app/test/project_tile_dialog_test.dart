import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/project_tile.dart';
import 'package:nushi/project_tile_dialog.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tile_look.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'project_tile_fixture.dart';

// Change tile… (ADR 0112): the dialog that sets a project's tile.

/// A button that opens Change tile… for garden, whose repository has an
/// icon, pressed: the dialog is open.
Future<Daemon> _changeTile(
  WidgetTester tester, {
  Tokens tokens = Tokens.dark,
}) async {
  final fake = FakeDaemon([])..projectIcons[garden] = await iconPng(tester);
  final d = await fake.connect(tester);
  await tester.pumpWidget(
    themed(
      tokens: tokens,
      Builder(
        builder: (context) => Center(
          child: Button(
            label: 'Open',
            onPressed: () => changeTile(context, d, garden, color: 3),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await decodeImages(tester);
  return d;
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  testWidgets('Change tile… keeps an emoji or two letters and a color; '
      'Cancel keeps nothing, Reset forgets them', (tester) async {
    final d = await _changeTile(tester);
    ProjectTile preview() =>
        tester.widget(find.byKey(const Key('tile preview')));
    Button button(String label) =>
        tester.widget(find.widgetWithText(Button, label));
    // As it is by itself: the repository's icon; nothing to reset.
    expect(preview().look.isEmpty, isTrue);
    expect(preview().icon, isNotNull);
    expect(button('Reset').onPressed, isNull);

    // A third character doesn't go in; an emoji is one.
    await tester.enterText(find.byType(TextField), '🌱x');
    await tester.enterText(find.byType(TextField), '🌱xy');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '🌱x',
    );
    await tester.tap(find.byTooltip('Violet'));
    await tester.pump();
    expect(preview().look.toJson(), {'mark': '🌱x', 'color': 'violet'});
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' ab ');
    await tester.tap(find.byTooltip('Teal'));
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeTileDialog), findsNothing);
    expect(projectTiles.value[garden]?.toJson(), {
      'mark': 'ab',
      'color': 'teal',
    });
    expect(readSaved()['projectTiles'], {
      garden: {'mark': 'ab', 'color': 'teal'},
    });

    // Open again, it has them; a color alone is kept too.
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ab',
    );
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(Button, 'Save'));
    await tester.pumpAndSettle();
    expect(projectTiles.value[garden]?.toJson(), {'color': 'teal'});

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Reset'));
    await tester.pumpAndSettle();
    expect(projectTiles.value, isEmpty);
    expect(readSaved()['projectTiles'], isEmpty);
    d.dispose();
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: Change tile…, $name', (tester) async {
      viewport(tester, const Size(640, 360));
      projectTiles.value = {garden: const TileLook(mark: 'G7', color: 'rust')};
      final d = await _changeTile(tester, tokens: tokens);
      await tester.tap(find.byTooltip('Violet'));
      await tester.pump();
      await expectLater(
        find.byType(ChangeTileDialog),
        matchesGoldenFile('goldens/project_tile_dialog_$name.png'),
      );
      d.dispose();
    });
  }
}
