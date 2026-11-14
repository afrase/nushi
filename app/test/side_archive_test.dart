import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/side_toast.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A side chat's × archives it, and a toast says so with Undo (ADR 0115).

/// The app at [size] on chat c, with a side chat of it open, a question
/// and its answer in it ([talked]) and "And the fragment?" in its box;
/// the daemon archives it as "a" and brings it back as "s2".
Future<(Daemon, FakeDaemon, ChatState)> _app(
  WidgetTester tester, {
  bool talked = true,
  Size size = const Size(1400, 800),
}) async {
  viewport(tester, size);
  final fake =
      FakeDaemon([
          chat('c', 'claude', 'Fix the login redirect'),
          chat('o', 'claude', 'Another chat'),
        ])
        ..answer = (input) => switch (input) {
          ArchiveSideChatRequest() => ArchiveSideChatResponse(
            chatId: talked ? 'a' : '',
          ),
          RestoreSideChatRequest() => RestoreSideChatResponse(chatId: 's2'),
          _ => null,
        };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  fake.emit(
    EventsResponse(
      chatId: 'c',
      seq: Int64(1),
      status: ChatStatus(canFork: true),
    ),
  );
  final side = ChatState('s', '/Users/me')
    ..agent = 'claude'
    ..loaded = true;
  if (talked) {
    side.items.addAll([
      Item(
        id: 'u',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'Why does the redirect keep the query string?',
      ),
      Item(
        id: 'm',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text: 'So the page you asked for opens after you sign in.',
      ),
    ]);
  }
  side.draft.text.text = 'And the fragment?';
  d
    ..sides['s'] = side
    ..chats['c']!.side.value = side;
  await tester.pumpAndSettle();
  return (d, fake, side);
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byTooltip('End the side chat'));
  await tester.pumpAndSettle();
}

Finder get _toast => find.byKey(const ValueKey('archived-side'));
Finder get _failed => find.byKey(const ValueKey('archived-side-undo-failed'));

Future<void> _undo(WidgetTester tester) async {
  await tester.tap(find.text('Undo'));
  await tester.pumpAndSettle();
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('its × archives one with messages at once: no question, a '
      'toast with Undo and ×', (tester) async {
    final (d, fake, _) = await _app(tester);
    await _close(tester);
    expect(find.text('End the side chat?'), findsNothing);
    expect(fake.calls.whereType<ArchiveSideChatRequest>().single.chatId, 's');
    expect(fake.calls.whereType<CloseSideChatRequest>(), isEmpty);
    expect(d.chats['c']!.side.value, isNull);
    expect(d.sides, isEmpty);
    expect(find.byType(SideChat), findsNothing);
    expect(_toast, findsOne);
    expect(
      find.descendant(of: _toast, matching: find.text('Archived side chat')),
      findsOne,
    );
    expect(
      find.descendant(of: _toast, matching: find.byIcon(Icons.info_outline)),
      findsOne,
    );
    expect(find.descendant(of: _toast, matching: find.text('Undo')), findsOne);
    expect(
      find.descendant(of: _toast, matching: find.byIcon(Icons.close)),
      findsOne,
    );
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('an empty one just ends: no toast', (tester) async {
    final (d, fake, _) = await _app(tester, talked: false);
    await _close(tester);
    expect(fake.calls.whereType<ArchiveSideChatRequest>().single.chatId, 's');
    expect(d.chats['c']!.side.value, isNull);
    expect(_toast, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('the toast stays ten seconds; its × takes it away', (
    tester,
  ) async {
    final (d, _, _) = await _app(tester);
    await _close(tester);
    await tester.pump(archivedSideFor - const Duration(seconds: 1));
    expect(_toast, findsOne);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);

    // Opened again and closed: × dismisses it.
    final side = ChatState('s', '/Users/me')..loaded = true;
    d
      ..sides['s'] = side
      ..chats['c']!.side.value = side;
    await tester.pumpAndSettle();
    await _close(tester);
    await tester.tap(
      find.descendant(of: _toast, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('Undo brings it back beside its chat, shown, its box as it '
      'was, from another chat too', (tester) async {
    final (d, fake, _) = await _app(tester);
    final c = d.chats['c']!;
    await _close(tester);
    d.select('o');
    await tester.pumpAndSettle();
    await _undo(tester);
    expect(fake.calls.whereType<RestoreSideChatRequest>().single.chatId, 'a');
    expect(d.selectedId, 'c');
    final back = c.side.value!;
    expect(back.id, 's2');
    expect(d.sides['s2'], back);
    expect(c.sideHidden.value, isFalse);
    expect(find.byType(SideChat), findsOne);
    expect(back.draft.text.text, 'And the fragment?');
    expect(_toast, findsNothing);
    expect(_failed, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("Undo says why when it can't: another side chat open, the "
      'chat archived, the daemon refusing', (tester) async {
    final (d, fake, _) = await _app(tester);
    final c = d.chats['c']!;
    Future<void> undoFails(String why) async {
      await _undo(tester);
      expect(
        find.descendant(
          of: _failed,
          matching: find.text("Couldn't undo: $why"),
        ),
        findsOne,
      );
      await tester.tap(
        find.descendant(of: _failed, matching: find.byIcon(Icons.close)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> closeAgain() async {
      final side = ChatState('s', '/Users/me')..loaded = true;
      d
        ..sides['s'] = side
        ..chats['c']!.side.value = side;
      await tester.pumpAndSettle();
      await _close(tester);
    }

    await _close(tester);
    final other = ChatState('s3', '/Users/me')..loaded = true;
    d
      ..sides['s3'] = other
      ..chats['c']!.side.value = other;
    await tester.pumpAndSettle();
    await undoFails('the chat has another side chat open');
    expect(c.side.value, other);
    expect(fake.calls.whereType<RestoreSideChatRequest>(), isEmpty);

    await closeAgain();
    c.archived = true;
    await undoFails('the chat it came from is archived');
    c.archived = false;

    fake.answer = (input) => switch (input) {
      ArchiveSideChatRequest() => ArchiveSideChatResponse(chatId: 'a'),
      RestoreSideChatRequest() => throw ConnectException(
        Code.failedPrecondition,
        'the chat it came from was deleted',
      ),
      _ => null,
    };
    await closeAgain();
    await undoFails('the chat it came from was deleted');
    expect(c.side.value, isNull);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("a daemon that can't archive it asks, saying why, and End "
      'deletes it', (tester) async {
    final (d, fake, side) = await _app(tester);
    fake.answer = (input) => switch (input) {
      ArchiveSideChatRequest() => throw ConnectException(
        Code.failedPrecondition,
        "the agent can't reopen sessions, so the side chat can't be kept",
      ),
      _ => null,
    };
    await _close(tester);
    expect(find.text('End the side chat?'), findsOne);
    expect(
      find.textContaining("It can't be archived: the agent can't reopen"),
      findsOne,
    );
    expect(d.chats['c']!.side.value, side);
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<CloseSideChatRequest>().single.chatId, 's');
    expect(d.chats['c']!.side.value, isNull);
    expect(_toast, findsNothing);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('the toast ($name)', (tester) async {
      final (d, _, _) = await _app(tester);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _close(tester);
      // The toast's layer: a strip as wide as the window, the card in it.
      await expectLater(
        find.descendant(of: _toast, matching: find.byType(Material)).first,
        matchesGoldenFile('goldens/side_chat_archived_toast_$name.png'),
      );
      await closeView(tester, d);
    }, variant: _mac);

    for (final (what, size) in [
      ('wide', const Size(1700, 900)),
      ('narrow', const Size(720, 800)),
    ]) {
      testWidgets('the toast, $what ($name)', (tester) async {
        final (d, _, _) = await _app(tester, size: size);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _close(tester);
        expectTextInside(tester, size.width);
        // Its card (the SnackBar's own box is wider than what it draws):
        // the text first, the close button last, inside the window.
        final text = tester.getRect(find.text('Archived side chat'));
        final close = tester.getRect(
          find.descendant(of: _toast, matching: find.byIcon(Icons.close)),
        );
        expect(text.left, greaterThanOrEqualTo(0));
        expect(close.right, lessThanOrEqualTo(size.width));
        expect(close.bottom, lessThanOrEqualTo(size.height));
        await render(
          tester,
          find.byType(NushiApp),
          'side_chat_archived_${what}_$name',
        );
        // Undo refused: the toast says why.
        final c = d.chats['c']!..archived = true;
        await _undo(tester);
        expect(_failed, findsOne);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'side_chat_undo_failed_${what}_$name',
        );
        c.archived = false;
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
