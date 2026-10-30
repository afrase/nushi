import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/status.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The app at [size] on chat c, with a side chat open: [talked], one with
/// a question and its answer in it; else an empty one.
Future<(Daemon, FakeDaemon, ChatState)> _app(
  WidgetTester tester, {
  bool talked = true,
  Size size = const Size(1400, 800),
}) async {
  viewport(tester, size);
  final fake = FakeDaemon([chat('c', 'claude', 'Fix the login redirect')]);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  // It can fork, so ⇧⌘B applies.
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
  d
    ..sides['s'] = side
    ..chats['c']!.side.value = side;
  await tester.pumpAndSettle();
  return (d, fake, side);
}

Finder get _dialog => find.text('End the side chat?');

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byTooltip('End the side chat'));
  await tester.pumpAndSettle();
}

Finder get _chip => find.byType(SideChip);

Future<void> _hide(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.remove));
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester) async {
  await tester.tap(_chip);
  await tester.pumpAndSettle();
}

Future<void> _shiftCmdB(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

/// Whether the side chat is still open, and the daemon wasn't told to end it.
void _open(Daemon d, FakeDaemon fake, ChatState side) {
  expect(d.chats['c']!.side.value, side);
  expect(find.byType(SideChat), findsOne);
  expect(fake.calls.whereType<CloseSideChatRequest>(), isEmpty);
}

/// Whether the side chat ended, the daemon told.
void _ended(Daemon d, FakeDaemon fake) {
  expect(d.chats['c']!.side.value, isNull);
  expect(find.byType(SideChat), findsNothing);
  expect(fake.calls.whereType<CloseSideChatRequest>().single.chatId, 's');
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  testWidgets('an empty side chat ends at once by its ×', (tester) async {
    final (d, fake, _) = await _app(tester, talked: false);
    await _close(tester);
    expect(_dialog, findsNothing);
    _ended(d, fake);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('one with messages asks first; Cancel and Esc keep it', (
    tester,
  ) async {
    final (d, fake, side) = await _app(tester);
    await _close(tester);
    expect(_dialog, findsOne);
    expect(
      find.text(
        'Its conversation is deleted; nothing from it is added to the chat.',
      ),
      findsOne,
    );
    // End is the default: the focus starts on it.
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(
        of: find.text('End'),
        matching: find.byWidget(focused.widget),
      ),
      findsOne,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    _open(d, fake, side);

    await _close(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    _open(d, fake, side);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('End and ⏎ end it', (tester) async {
    for (final end in [
      () => tester.tap(find.text('End')),
      () => tester.sendKeyEvent(LogicalKeyboardKey.enter),
    ]) {
      final (d, fake, side) = await _app(tester);
      await _close(tester);
      expect(_dialog, findsOne);
      _open(d, fake, side);
      await end();
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      _ended(d, fake);
      await closeView(tester, d);
    }
  }, variant: _mac);

  testWidgets('⇧⌘B or − hides it, alive: its transcript and draft stay; '
      '⇧⌘B or the chip shows it again', (tester) async {
    final (d, fake, side) = await _app(tester);
    final c = d.chats['c']!;
    side.draft.text.text = 'And the fragment?';
    await tester.pumpAndSettle();
    for (final (hide, show) in [(_shiftCmdB, _shiftCmdB), (_hide, _tapChip)]) {
      expect(_chip, findsNothing); // only while hidden
      await hide(tester);
      expect(c.sideHidden.value, isTrue);
      expect(find.byType(SideChat), findsNothing);
      expect(_chip, findsOne);
      expect(_dialog, findsNothing);
      await show(tester);
      _open(d, fake, side);
      expect(_chip, findsNothing);
      expect(side.items, hasLength(2));
      expect(
        find.textContaining('keep the query string', findRichText: true),
        findsOne,
      );
      expect(find.text('And the fragment?'), findsOne); // the side's box
    }
    // × still asks.
    await _close(tester);
    expect(_dialog, findsOne);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('⇧⌘B opens one when the chat has none', (tester) async {
    final (d, fake, _) = await _app(tester);
    d.closeSide(d.chats['c']!);
    await tester.pumpAndSettle();
    fake.calls.clear();
    await _shiftCmdB(tester);
    expect(fake.calls.whereType<ForkChatRequest>().single.chatId, 'c');
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets("the chip's dot: working, then a turn ended unseen until "
      'shown; the daemon ending it takes the chip away', (tester) async {
    final (d, fake, side) = await _app(tester);
    await _hide(tester);
    Finder dot() => find.descendant(of: _chip, matching: find.byType(ChatDot));
    expect(dot(), findsNothing); // idle: no dot
    fake.emit(_status(1, busy: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(side.phase, ChatPhase.working);
    expect(dot(), findsOne);
    fake.emit(_status(2));
    await tester.pump(const Duration(seconds: 3));
    expect(side.phase, ChatPhase.done);
    expect(dot(), findsOne);

    await _tapChip(tester); // seen
    expect(side.done, isNull);
    await _hide(tester);
    expect(dot(), findsNothing);

    // A turn that ends while it shows isn't unseen.
    await _shiftCmdB(tester);
    fake
      ..emit(_status(3, busy: true))
      ..emit(_status(4));
    await tester.pump(const Duration(seconds: 3));
    expect(side.done, isNull);

    await _hide(tester);
    fake.emit(EventsResponse(chatId: 's', removed: true));
    await tester.pumpAndSettle();
    expect(_chip, findsNothing);
    expect(d.chats['c']!.side.value, isNull);
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    for (final (what, size) in [
      ('wide', const Size(1700, 900)),
      ('narrow', const Size(720, 800)),
    ]) {
      testWidgets('the dialog, $what ($name)', (tester) async {
        final (d, _, _) = await _app(tester, size: size);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _close(tester);
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/side_chat_end_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    for (final (what, size) in [
      ('wide', const Size(1700, 900)),
      ('narrow', const Size(720, 800)),
    ]) {
      testWidgets('the chip, a turn unseen, $what ($name)', (tester) async {
        final (d, fake, _) = await _app(tester, size: size);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _hide(tester);
        fake
          ..emit(_status(1, busy: true))
          ..emit(_status(2));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(NushiApp),
          matchesGoldenFile('goldens/side_chat_chip_${what}_$name.png'),
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}

/// The side chat's status event [seq]: a turn runs while [busy].
EventsResponse _status(int seq, {bool busy = false}) => EventsResponse(
  chatId: 's',
  seq: Int64(seq),
  status: ChatStatus(busy: busy),
);
