import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _summary =
    'This session is being continued from a previous conversation that ran '
    'out of context. The summary below covers the earlier portion of the '
    'conversation.\n\n**Primary request**: move the session store into its '
    'own package, keeping its tests.';

/// A chat reopened after a compaction and then an edit in a terminal:
/// Nushi's copy above the marks, Claude's history below.
final _reopened = [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Move the session store into its own package.',
  ),
  Item(
    id: 't1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'read',
    title: 'Read store/sessions.go',
    status: 'completed',
  ),
  Item(
    id: 'm1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Moved it to `internal/sessions`; the tests pass.',
  ),
  Item(
    id: 'c1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'compacted',
    title: 'Compacted here',
    text: _summary,
  ),
  Item(
    id: 'm2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Also renamed `Store` to `Sessions` where it was exported.',
  ),
  Item(id: 'u2', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: '/compact'),
  Item(
    id: 't2',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'think',
    title: 'Compact conversation',
    status: 'completed',
  ),
  Item(
    id: 'u3',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Now add a test for a missing file.',
  ),
  Item(
    id: 'd1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'history_differs',
    text: "Claude's history differs from Nushi's copy from here on",
  ),
  Item(
    id: 'u4',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Add a test for an empty file instead.',
  ),
  Item(
    id: 'm4',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Added `TestEmptyFile`.',
  ),
];

/// A chat whose session Claude deleted, kept for Nushi's copy.
final List<Item> _expired = [
  ..._reopened.take(3),
  Item(
    id: 'n1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'session_gone',
    text:
        'Claude no longer has this session (Claude Code deletes sessions '
        'after 30 days by default).',
  ),
];

Future<(FakeDaemon, Future<void> Function())> _open(
  WidgetTester tester,
  List<Item> items, {
  Brightness brightness = Brightness.dark,
  bool gone = false,
}) async {
  viewport(tester, Size(900, gone ? 520 : 900), brightness: brightness);
  showDetails.value = false;
  final status = ChatStatus(reopenFailed: gone, sessionGone: gone);
  final c = chat('c', 'claude', 'Move the session store', status: status);
  final fake = FakeDaemon([c])
    ..answer = (input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: items, status: status)
        : null;
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus(); // no caret blinking
  await tester.pumpAndSettle();
  return (
    fake,
    () async {
      await closeView(tester, d);
    },
  );
}

void main() {
  setUpAll(loadFonts);

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('where a reopened chat’s history comes from changes '
        '($name)', (tester) async {
      final (_, end) = await _open(tester, _reopened, brightness: brightness);
      expect(find.text('Compacted here'), findsOneWidget);
      await expectLater(
        find.byType(ChatView),
        matchesGoldenFile('goldens/history_marks_$name.png'),
      );
      await end();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a chat whose session is gone, from its copy: read-only '
        '($name)', (tester) async {
      final (_, end) = await _open(
        tester,
        _expired,
        brightness: brightness,
        gone: true,
      );
      expect(find.byType(Composer), findsNothing);
      expect(find.text('Read-only: Nushi’s copy of the transcript.'), findsOne);
      await expectLater(
        find.byType(ChatView),
        matchesGoldenFile('goldens/expired_copy_$name.png'),
      );
      await end();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('a click on Compacted here shows what Claude kept of it', (
    tester,
  ) async {
    final (_, end) = await _open(tester, _reopened);
    expect(
      find.textContaining('Primary request', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('Compacted here'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Primary request', findRichText: true),
      findsOne,
    );
    await end();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a chat whose session is gone: Delete… asks what it deletes; '
      'Start a new chat here starts one in its folder', (tester) async {
    final (fake, end) = await _open(tester, _expired, gone: true);
    await tester.tap(find.text('Delete…'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Move the session store”?'), findsOneWidget);
    expect(fake.calls.whereType<PlanDeleteChatRequest>().length, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start a new chat here'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fake.started.single.folder, '/Users/me/nushi');
    expect(fake.started.single.agent, 'claude');
    await end();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
