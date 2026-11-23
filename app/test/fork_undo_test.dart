import 'package:connectrpc/connect.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/fork_toast.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// The toast after a fork, with Undo (#58).

const ItemKind _user = ItemKind.ITEM_KIND_USER_MESSAGE;
const ItemKind _agent = ItemKind.ITEM_KIND_AGENT_MESSAGE;

/// The app on chat c, whose agent forks: a question and the agent's
/// answer. [deleteFails] makes DeleteChat fail.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  Size size = const Size(1400, 800),
  Brightness? brightness,
  bool deleteFails = false,
}) async {
  showDetails.value = false;
  final c = chat('c', 'claude', 'Fix the login redirect');
  final status = ChatStatus(canFork: true, canRewind: true);
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest(chatId: 'c') => GetChatResponse(
        chat: c,
        status: status,
        items: [
          Item(id: 'u1', kind: _user, text: 'Why keep the query string?'),
          Item(
            id: 'm1',
            kind: _agent,
            text: 'So the page you asked for opens after you sign in.',
            forkable: true,
          ),
        ],
      ),
      DeleteChatRequest() when deleteFails => throw ConnectException(
        Code.failedPrecondition,
        'the agent is still starting',
      ),
      _ => null,
    };
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  fake.emit(EventsResponse(chatId: 'c', seq: Int64(9), status: status));
  await tester.pumpAndSettle();
  return (d, fake);
}

/// Fork in the chat's menu.
Future<void> _fork(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chat menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Fork'));
  await tester.pumpAndSettle();
}

Finder get _toast => find.text('Forked into a new chat');
Finder get _undo => find.widgetWithText(Button, 'Undo');

void main() {
  setUpAll(loadFonts);

  testWidgets('a fork says so, with Undo as a button; it goes after its '
      'time, the fork kept', (tester) async {
    final (d, fake) = await _app(tester);
    await _fork(tester);
    expect(d.selectedId, 'fork');
    expect(_toast, findsOne);
    expect(_undo, findsOne);
    expect(find.byTooltip('Dismiss'), findsOne);
    await tester.pump(forkedFor);
    await tester.pump(Motion.exit);
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    expect(d.chats.containsKey('fork'), isTrue);
    expect(d.selectedId, 'fork');
    expect(fake.calls.whereType<DeleteChatRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('Undo deletes the fork, its worktree kept, and goes back to '
      'the chat', (tester) async {
    final (d, fake) = await _app(tester);
    await _fork(tester);
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    final del = fake.calls.whereType<DeleteChatRequest>().single;
    expect(del.chatId, 'fork');
    expect(del.worktrees, isEmpty); // shared with c: it stays
    expect(d.selectedId, 'c');
    expect(d.chats.containsKey('fork'), isFalse);
    expect(_toast, findsNothing);
    expect(find.textContaining('So the page you asked'), findsOne);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('no Undo once a message is sent in the fork, or it works', (
    tester,
  ) async {
    final (d, fake) = await _app(tester);
    await _fork(tester);
    expect(_undo, findsOne);
    // A turn of the fork's own: what Undo would throw away.
    fake.emit(
      EventsResponse(
        chatId: 'fork',
        seq: Int64(1),
        status: ChatStatus(busy: true, started: Int64(1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    expect(_undo, findsNothing);
    expect(fake.calls.whereType<DeleteChatRequest>(), isEmpty);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a message sent in the fork takes the toast away at once', (
    tester,
  ) async {
    final (d, _) = await _app(tester);
    await _fork(tester);
    // Shown in the transcript as it goes, before the daemon has it.
    d.chats['fork']!.outbox.send('and the logout page?', const []);
    await tester.pumpAndSettle();
    expect(_toast, findsNothing);
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a second fork replaces the first’s toast; its Undo deletes '
      'only the second', (tester) async {
    final (d, fake) = await _app(tester);
    await _fork(tester);
    d.select('c');
    await tester.pumpAndSettle();
    await _fork(tester);
    expect(d.selectedId, 'fork2');
    expect(_toast, findsOne);
    expect(find.byKey(const ValueKey('forked-fork2')), findsOne);
    expect(find.byKey(const ValueKey('forked-fork')), findsNothing);
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<DeleteChatRequest>().single.chatId, 'fork2');
    expect(d.chats.containsKey('fork'), isTrue);
    expect(d.selectedId, 'c');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('a failed delete says so; the chat forked from shows', (
    tester,
  ) async {
    final (d, _) = await _app(tester, deleteFails: true);
    await _fork(tester);
    await tester.tap(_undo);
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't delete the fork: the agent is still starting"),
      findsOne,
    );
    expect(find.byIcon(Icons.error_outline), findsOne);
    expect(d.selectedId, 'c');
    expect(d.chats.containsKey('fork'), isTrue); // still in the sidebar
    await closeView(tester, d);
  }, variant: onMac);

  // The toast to look at (`make renders`).
  for (final (what, size) in [
    ('wide', const Size(1700, 900)),
    ('narrow', const Size(720, 800)),
  ]) {
    for (final b in renderThemes) {
      testWidgets('the fork’s toast, $what, ${b.name}', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        await _fork(tester);
        expect(_undo, findsOne);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'fork_undo_toast_${what}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
