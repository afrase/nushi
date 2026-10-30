import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets(
      "a chat row's right-click menu: rows a pointer hits without aiming, "
      'in groups, with icons, the key on the right, Delete in red ($name)',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        viewport(tester, const Size(520, 520));
        final d = await FakeDaemon([
          chat('a', 'claude', 'Wire the ledger', folder: '/Users/me/ledger'),
          chat(
            'b',
            'codex',
            'Cap the rates',
            folder: '/Users/me/ledger',
            age: 1,
          ),
        ]).connect(tester);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 260,
                  height: 500,
                  child: ListenableBuilder(
                    listenable: d,
                    builder: (context, _) => Sidebar(daemon: d),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(
          find.text('Wire the ledger'),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();

        final rows = find.byType(MenuItemButton);
        expect(rows, findsWidgets);
        for (final e in rows.evaluate()) {
          expect(tester.getSize(find.byWidget(e.widget)).height, 30);
        }
        expect(find.byType(Divider), findsWidgets);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/chat_menu_$name.png'),
        );
        d.dispose();
      },
    );
  }

  testWidgets('an action menu of more than ten rows has no filter field', (
    tester,
  ) async {
    Widget menu({required bool filter}) => MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: Scaffold(
        body: Menu(
          filter: filter,
          entries: [
            for (var i = 0; i < 12; i++)
              MenuEntry('Row $i', icon: Icons.edit_outlined, onPick: () {}),
          ],
          builder: (context, open) =>
              TextButton(onPressed: open, child: const Text('open')),
        ),
      ),
    );
    await tester.pumpWidget(menu(filter: false));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(12));

    // A long list of choices still gets one.
    await tester.tapAt(Offset.zero);
    await tester.pumpWidget(menu(filter: true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOne);
  });
}
