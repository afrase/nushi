import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/chat_menu.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'rename_fixture.dart';
import 'sidebar_fixture.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('the arrow keys move the caret when renaming from the sidebar', (
    tester,
  ) async {
    showDetails.value = false;
    final c = chat('c', 'claude', 'Pick me');
    final fake = FakeDaemon([c])
      ..answer = (input) =>
          input is GetChatRequest ? GetChatResponse(chat: c) : null;
    final d = await openApp(tester, fake, size: const Size(1400, 900));
    await tester.tapAt(
      tester.getCenter(find.text('Pick me').first),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').last);
    await tester.pumpAndSettle();
    final text = tester
        .widget<TextField>(
          find.descendant(
            of: find.byType(RenameField),
            matching: find.byType(TextField),
          ),
        )
        .controller!;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(text.selection, const TextSelection.collapsed(offset: 7));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(text.selection.baseOffset, 5);

    await press(
      tester,
      LogicalKeyboardKey.arrowLeft,
      shift: true,
      settle: false,
    );
    expect(text.selection.isCollapsed, isFalse);
    await closeView(tester, d);
  }, variant: onMac);

  // A name edited in place is a low box with small corners round the
  // name where it stood, never a pill, and nothing moves as it starts:
  // the place's height, the name's left edge and its baseline.
  for (final place in renamePlaces) {
    testWidgets('${place.name}: the edit is a low box, and nothing moves', (
      tester,
    ) async {
      final d = await renameApp(tester);
      await place.prepare?.call(tester);
      final height = tester.getSize(place.holder()).height;
      final before = textStart(tester, place.text());

      await place.start(tester, d);
      expect(editing, findsOne);
      expect(tester.getSize(place.holder()).height, height);
      final during = textStart(tester, editing);
      expect((during.dx - before.dx).abs(), lessThanOrEqualTo(1));
      expect((during.dy - before.dy).abs(), lessThanOrEqualTo(1));

      final (box, rect) = editBox(tester);
      final corner = (box.borderRadius! as BorderRadius).topLeft;
      expect(corner, const Radius.circular(NushiTheme.tag));
      expect(corner.x, lessThan(rect.height / 2), reason: 'not a stadium');
      expect(
        (box.border! as Border).top.color,
        NushiTheme.of(tester.element(editing)).t.focus,
      );
      await closeView(tester, d);
    }, variant: onMac);
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a chat renamed in the sidebar ($name)', (tester) async {
      final (d, _) = await arrangedSidebar(
        tester,
        tokens: tokens,
        size: const Size(400, 600),
        height: 560,
        settle: false,
      );
      // The open chat's row, as it's renamed most.
      await tester.tap(find.text('Fold the maps'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Fold the maps'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      expect(find.byType(RenameField), findsOne);
      await expectLater(
        find.byKey(const Key('shot')),
        matchesGoldenFile('goldens/rename_row_$name.png'),
      );
      d.dispose();
    });

    testWidgets('a chat renamed in its header ($name)', (tester) async {
      viewport(tester, const Size(700, 120));
      final d = await FakeDaemon([]).connect(tester);
      final c = ChatState('c', '/Users/me/garden')
        ..agent = 'claude'
        ..title = 'Water the ferns';
      c.renaming.value = true;
      await tester.pumpWidget(
        themed(
          SizedBox(
            width: 700,
            child: ChatHeader(
              c,
              d,
              tab: ChatTab.chat,
              onTab: (_) {},
              panel: true,
              onPanel: () {},
            ),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RenameField), findsOne);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/rename_header_$name.png'),
      );
      d.dispose();
    }, variant: onMac);
  }
}
