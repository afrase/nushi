// What floats over the window in the look of ADR 0111, each drawn on the
// whole app at 1700 and 720 in both themes (`make renders
// TEST=test/overlays_look_test.dart`): a menu with its submenu, a dialog,
// the palette, a tooltip, the find bar, a snack bar and the update card.
// A render draws their shadows as the app does; a golden can't.
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/palette.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';
import 'package:nushi/update_toast.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'update_fixtures.dart';

final _items = [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Paginate the home feed: 20 a page, and keep the reader’s place.',
  ),
  Item(
    id: 'a1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        '`ListPosts` reads the whole table in one query. I’ll give it a '
        'keyset cursor on `(published, id)`, so a post published while '
        'someone reads doesn’t shift the pages.\n\n'
        'The store and the handler page now, and the feed’s foot links to '
        'the older posts.',
  ),
];

final _config = EventsResponse(
  chatId: 'c',
  seq: Int64(2),
  config: ChatConfig(
    options: [
      ConfigOption(
        id: 'mode',
        name: 'Mode',
        category: 'mode',
        current: 'acceptEdits',
        values: [
          ConfigValue(value: 'default', name: 'Manual'),
          ConfigValue(value: 'acceptEdits', name: 'Accept edits'),
          ConfigValue(value: 'plan', name: 'Plan'),
        ],
      ),
      ConfigOption(
        id: 'model',
        name: 'Model',
        category: 'model',
        current: 'opus',
        values: [
          ConfigValue(value: 'opus', name: 'Opus 5.5'),
          ConfigValue(value: 'sonnet', name: 'Sonnet 5'),
        ],
      ),
      ConfigOption(
        id: 'fast',
        name: 'Fast mode',
        category: 'fast',
        type: 'boolean',
        current: 'false',
      ),
    ],
  ),
);

/// The app on an idle chat, the sidebar and the details hidden, at [size]
/// in [brightness]; the daemon found an update when [update].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  bool update = false,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  sidebarHidden.value = true;
  brewCask = 'nushi';
  final fake = updateDaemon(
    () => update ? newerUpdate('0.1.17') : UpdateCheck(),
  );
  final c = fake.chats.single;
  final answer = fake.answer!;
  fake.answer = (input) => input is GetChatRequest
      ? GetChatResponse(chat: c, items: _items)
      : answer(input);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  fake.emit(_config);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (d, fake);
}

const _sizes = [('1700', Size(1700, 1000)), ('720', Size(720, 900))];
final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  for (final b in Brightness.values) {
    for (final (w, size) in _sizes) {
      Future<void> shot(WidgetTester tester, String what) => render(
        tester,
        find.byType(NushiApp),
        'overlay_${what}_${w}_${b.name}',
      );

      testWidgets('a menu and its submenu, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        await tester.tap(
          find.descendant(
            of: find.byType(Pickers),
            matching: find.byType(MenuIcon),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byType(SubmenuButton).first;
        expect(row, findsOneWidget);
        await tester.tap(row);
        await tester.pumpAndSettle();
        // The submenu's rows are in the same overlay, beside the menu's.
        expect(find.byType(MenuItemButton), findsWidgets);
        await shot(tester, 'menu');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('a dialog, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        unawaited(
          confirm(
            tester.element(find.byType(Scaffold).first),
            'Delete “Paginate the feed”?',
            'Its transcript and its worktree go too. This can’t be undone.',
            'Delete',
            destructive: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cancel'), findsOneWidget);
        await shot(tester, 'dialog');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('the palette, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        unawaited(showPalette(tester.element(find.byType(Scaffold).first), d));
        await tester.pumpAndSettle();
        expect(find.byType(Palette), findsOneWidget);
        await shot(tester, 'palette');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('a tooltip and the find bar, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        d.chats['c']!.find.open();
        await tester.pumpAndSettle();
        expect(find.byType(FindBar), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(FindBar),
            matching: find.byType(TextField),
          ),
          'cursor',
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: tester.getCenter(find.byTooltip('Chat menu').first),
        );
        addTearDown(mouse.removePointer);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Chat menu'), findsOneWidget);
        await shot(tester, 'find_tooltip');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('a snack bar and the update card, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: size,
          brightness: b,
          update: true,
        );
        expect(find.byType(UpdateToast), findsOneWidget);
        showError(
          tester.element(find.byType(Scaffold).first),
          'GitHub didn’t answer: the request timed out after 30 s.',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byType(SnackBar), findsOneWidget);
        await shot(tester, 'snack_update');
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
