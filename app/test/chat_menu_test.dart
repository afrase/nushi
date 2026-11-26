import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/main.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/review.dart';
import 'package:nushi/sidebar.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets(
      "a chat row's right-click menu: rows a pointer hits without aiming, "
      'in groups, with icons, the key on the right, Delete in red ($name)',
      variant: onMac,
      (tester) async {
        viewport(tester, const Size(520, 520));
        final d = await FakeDaemon([
          chat('a', 'claude', 'Wire the parcel', folder: '/Users/me/parcel'),
          chat(
            'b',
            'codex',
            'Fold the maps',
            folder: '/Users/me/parcel',
            age: 1,
          ),
        ]).connect(tester);
        await tester.pumpWidget(
          themed(
            Align(
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
            tokens: tokens,
            banner: false,
          ),
        );
        await tester.pump();
        await tester.tap(
          find.text('Wire the parcel'),
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
    Widget menu({required bool filter}) => themed(
      Menu(
        filter: filter,
        entries: [
          for (var i = 0; i < 12; i++)
            MenuEntry('Row $i', icon: Icons.edit_outlined, onPick: () {}),
        ],
        builder: (context, open) =>
            TextButton(onPressed: open, child: const Text('open')),
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

  // The row builds its menu when it opens, so what changed since (a review
  // comment added, which doesn't rebuild the sidebar) is in it.
  testWidgets(
    'a row’s menu offers the review comments added since it '
    'was built',
    variant: onMac,
    (tester) async {
      viewport(tester, const Size(1200, 700));
      final d = await FakeDaemon([
        chat('a', 'claude', 'Fix the login redirect', age: 2),
        chat('b', 'codex', 'Bump the API version', age: 1),
      ]).connect(tester);
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      addTearDown(() => setComments('a', []));
      setComments('a', [
        ReviewComment(
          id: 'r1',
          where: 'uncommitted',
          path: 'main.go',
          old: false,
          start: 1,
          end: 1,
          quote: 'x',
          text: 'Rename this',
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Fix the login redirect'),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Send review comments'), findsOneWidget);
      await closeView(tester, d);
    },
  );
}
