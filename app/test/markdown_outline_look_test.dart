import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/preview_pane.dart';
import 'package:nushi/preview_path.dart';
import 'package:nushi/rail.dart';
import 'package:nushi/rail_menu.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';
import 'outline_fixture.dart';

// The Markdown outline's looks: its goldens, its renders, and the phone's.

void main() {
  setUpAll(loadFonts);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('golden: the rail and its menu, $name', (tester) async {
      final d = await outlineApp(tester, width: 1200, brightness: brightness);
      await expectLater(
        find.byType(PreviewPane),
        matchesGoldenFile('goldens/markdown_outline_$name.png'),
      );
      await closeView(tester, d);
      // The rail on its own, its menu open, a row under the pointer.
      viewport(tester, const Size(360, 300), brightness: brightness);
      final current = ValueNotifier(3);
      addTearDown(current.dispose);
      final theme = NushiTheme(
        brightness == Brightness.dark ? Tokens.dark : Tokens.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey(#host),
          debugShowCheckedModeBanner: false,
          theme: theme.toThemeData(),
          home: Scaffold(
            backgroundColor: theme.t.base,
            body: Align(
              alignment: Alignment.topLeft,
              child: Rail(
                label: 'Outline',
                outline: true,
                entries: const [
                  RailEntry('0', 'Roadmap'),
                  RailEntry('1', 'Plans'),
                  RailEntry('2', 'The app', depth: 1),
                  RailEntry('3', 'Previews', depth: 1),
                  RailEntry('4', 'A part of it', depth: 2),
                  RailEntry('5', 'Decisions to revisit'),
                ],
                current: current,
                fit: RailFit.of(55),
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/markdown_outline_rail_$name.png'),
      );
      final mouse = await hoverRail(tester);
      await mouse.moveTo(tester.getCenter(find.text('The app')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey(#host)),
        matchesGoldenFile('goldens/markdown_outline_menu_$name.png'),
      );
    }, variant: mac);

    for (final width in [1700.0, 720.0]) {
      testWidgets('renders: the outline, ${width.toInt()} wide, $name', (
        tester,
      ) async {
        final d = await outlineApp(
          tester,
          width: width,
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'outline_${width.toInt()}_$name',
        );
        await hoverRail(tester);
        await render(
          tester,
          find.byType(NushiApp),
          'outline_${width.toInt()}_menu_$name',
        );
        await closeView(tester, d);
      }, variant: mac);
    }

    testWidgets('the phone: the path line, and a tap on the rail lists the '
        'headings, $name', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 3, brightness: brightness);
      final phone = Phone(
        PhonePlatform()..saved = pairedRecord(),
        connectTo: (_) => Daemon(transport: outlineDaemon(), remote: true),
      );
      await tester.pumpWidget(PhoneApp(phone));
      await phone.start();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      await tester.tap(find.text('Plan the work'));
      await tester.pumpAndSettle();
      PreviewScreen.open(
        tester.element(find.byType(Navigator).first),
        phone.daemon!,
        phone.daemon!.chats['c']!,
        'docs/roadmap.md',
      );
      await tester.pumpAndSettle();
      expect(find.text('docs / roadmap.md'), findsOneWidget);
      expect(find.byType(SourceButton), findsOneWidget);
      expect(find.byType(Rail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await render(tester, find.byType(PhoneApp), 'outline_phone_$name');
      await tester.tap(find.byType(Rail));
      await tester.pumpAndSettle();
      expect(find.byType(RailMenu), findsOneWidget);
      await render(tester, find.byType(PhoneApp), 'outline_phone_menu_$name');
      await tester.tap(
        find.descendant(
          of: find.byType(RailMenu),
          matching: find.text('Decisions to revisit'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RailMenu), findsNothing);
      expect(tester.widget<Rail>(find.byType(Rail)).current.value, 6);
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
