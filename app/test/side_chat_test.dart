import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/side_chat.dart';
import 'package:nushi/status.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// The app at [size] on chat c, with a side chat open: [talked], one with
/// a question and its answer in it; else an empty one. With [old], on a
/// daemon older than [archiveSideApi], whose × deletes a side chat (the
/// archive and its toast: side_archive_test.dart).
Future<(Daemon, FakeDaemon, ChatState)> _app(
  WidgetTester tester, {
  bool talked = true,
  bool old = false,
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
  // Only what the × does depends on it.
  if (old) d.daemonApi = archiveSideApi - 1;
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

  testWidgets('an older daemon: an empty side chat ends at once by its ×', (
    tester,
  ) async {
    final (d, fake, _) = await _app(tester, talked: false, old: true);
    await _close(tester);
    expect(_dialog, findsNothing);
    _ended(d, fake);
    await closeView(tester, d);
  }, variant: _mac);

  testWidgets('an older daemon: one with messages asks first; Cancel, Esc '
      'and ⏎ keep it', (tester) async {
    final (d, fake, side) = await _app(tester, old: true);
    await _close(tester);
    expect(_dialog, findsOne);
    expect(
      find.text(
        'Its conversation is deleted; nothing from it is added to the chat.',
      ),
      findsOne,
    );
    // Ending deletes its conversation: the focus starts on Cancel, so ⏎
    // keeps it (docs/design.md).
    expect(focusedButton(tester), 'Cancel');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    _open(d, fake, side);

    await _close(tester);
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

  testWidgets('an older daemon: End ends it', (tester) async {
    final (d, fake, side) = await _app(tester, old: true);
    await _close(tester);
    expect(_dialog, findsOne);
    _open(d, fake, side);
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(_dialog, findsNothing);
    _ended(d, fake);
    await closeView(tester, d);
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

  testWidgets("its composer has the chat's pickers, which set the side "
      "chat's own options", (tester) async {
    final (d, fake, _) = await _app(tester);
    fake.emit(_config);
    await tester.pumpAndSettle();
    final mode = find.descendant(
      of: find.byType(SideChat),
      matching: find.text('Plan'),
    );
    expect(mode, findsOne);
    expect(
      find.descendant(
        of: find.byType(SideChat),
        matching: find.textContaining('Sonnet', findRichText: true),
      ),
      findsOne,
    );
    await tester.tap(mode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual').last);
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetConfigOptionRequest>().single;
    expect((set.chatId, set.configId, set.value), ('s', 'mode', 'default'));
    await closeView(tester, d);
  }, variant: _mac);

  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('the side chat with its pickers ($name)', (tester) async {
      final (d, fake, _) = await _app(tester);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      fake.emit(_config);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SideChat),
        matchesGoldenFile('goldens/side_chat_pickers_$name.png'),
      );
      await closeView(tester, d);
    }, variant: _mac);

    for (final (what, size) in [
      ('wide', const Size(1700, 900)),
      ('narrow', const Size(720, 800)),
    ]) {
      testWidgets('the pickers, $what ($name)', (tester) async {
        final (d, fake, _) = await _app(tester, size: size);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        fake.emit(_config);
        await tester.pumpAndSettle();
        expectTextInside(tester, size.width);
        // A side chat's box is too narrow for them in its row (ADR
        // 0111): under the box, inside the pane.
        final pane = tester.getRect(find.byType(SideChat));
        final effort = tester.getRect(
          find.descendant(
            of: find.byType(SideChat),
            matching: find.textContaining('Sonnet', findRichText: true),
          ),
        );
        final plus = tester.getRect(
          find.descendant(
            of: find.byType(SideChat),
            matching: find.byType(PlusButton),
          ),
        );
        expect(effort.right, lessThanOrEqualTo(pane.right));
        expect(effort.left, greaterThan(pane.left));
        expect(effort.top, greaterThan(plus.bottom));
        await render(
          tester,
          find.byType(NushiApp),
          'side_chat_pickers_${what}_$name',
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
      testWidgets('the dialog of an older daemon, $what ($name)', (
        tester,
      ) async {
        final (d, _, _) = await _app(tester, size: size, old: true);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await _close(tester);
        expectTextInside(tester, size.width);
        final dialog = tester.getRect(find.byType(Dialog));
        expect(dialog.left, greaterThanOrEqualTo(0));
        expect(dialog.right, lessThanOrEqualTo(size.width));
        await render(
          tester,
          find.byType(NushiApp),
          'side_chat_end_${what}_$name',
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
        expectTextInside(tester, size.width);
        expect(tester.getRect(_chip).right, lessThanOrEqualTo(size.width));
        await render(
          tester,
          find.byType(NushiApp),
          'side_chat_chip_${what}_$name',
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

/// The side chat's options, as the daemon sends them.
EventsResponse get _config => EventsResponse(
  chatId: 's',
  seq: Int64(1),
  config: ChatConfig(options: _sideConfig),
);

/// A side chat's options as Claude's Go agent has them: its chat's Plan
/// mode, and the model with its effort.
final _sideConfig = [
  ConfigOption(
    id: 'mode',
    name: 'Mode',
    category: 'mode',
    current: 'plan',
    values: [
      ConfigValue(value: 'default', name: 'Manual'),
      ConfigValue(value: 'plan', name: 'Plan'),
      ConfigValue(value: 'auto', name: 'Auto'),
    ],
  ),
  ConfigOption(
    id: 'model',
    name: 'Model',
    category: 'model',
    current: 'sonnet',
    values: [
      ConfigValue(value: 'opus', name: 'Opus 5.5'),
      ConfigValue(value: 'sonnet', name: 'Sonnet 5'),
    ],
  ),
  ConfigOption(
    id: 'effort',
    name: 'Effort',
    category: 'thought_level',
    current: 'high',
    values: [
      ConfigValue(value: 'medium', name: 'Medium'),
      ConfigValue(value: 'high', name: 'High'),
    ],
  ),
];
