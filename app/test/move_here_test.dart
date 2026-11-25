import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/call_times.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/move_here.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript_entries.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Move chat here (ADR 0150): the agent's own call that entered a worktree
// offers to move the chat into it.

const _repo = '/Users/me/kettle';
const _tree = '$_repo/.claude/worktrees/tidy-store';
const _other = '$_repo/.claude/worktrees/fix-docs';

Item _ask(String id) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_USER_MESSAGE,
  text: 'Tidy the store package in a worktree of its own.',
);

Item _read(String id, {String parent = ''}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'read',
  title: 'Read internal/store/get.go',
  paths: ['internal/store/get.go'],
  status: 'completed',
  parent: parent,
);

/// Claude's EnterWorktree, done: [path] where it now works.
Item _enter(String id, String path) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'other',
  title: 'EnterWorktree',
  status: 'completed',
  worksIn: WorksIn(path: path),
);

/// Claude's ExitWorktree, done: back in the session's folder.
Item _exit(String id) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'other',
  title: 'ExitWorktree',
  status: 'completed',
  worksIn: WorksIn(),
);

ChatState _chat(List<Item> items, {String folder = _repo}) =>
    ChatState('c', folder)
      ..load(GetChatResponse(status: ChatStatus(), items: items));

String? _offer(ChatState chat, {bool side = false}) =>
    moveOffer(chat, side: side)?.id;

/// The app on chat c in [_repo], whose agent entered [_tree].
Future<(FakeDaemon, Daemon)> _open(
  WidgetTester tester, {
  ChatStatus? status,
  Size size = const Size(1700, 900),
  Brightness? brightness,
}) async {
  showDetails.value = false;
  final c = chat('c', 'claude', 'Tidy the store package', folder: _repo)
    ..status = status ?? ChatStatus();
  final fake = FakeDaemon([c])
    ..chatItems['c'] = [_ask('u'), _read('r'), _enter('e', _tree)];
  final d = await openApp(tester, fake, size: size, brightness: brightness);
  return (fake, d);
}

/// Its Move chat here.
Finder _button() => find.widgetWithText(PillButton, 'Move chat here');

void main() {
  setUpAll(loadFonts);

  group('which call offers', () {
    test('a call that entered a worktree', () {
      expect(_offer(_chat([_ask('u'), _read('r'), _enter('e', _tree)])), 'e');
      // Calls after it leave it the offer.
      expect(_offer(_chat([_enter('e', _tree), _read('r')])), 'e');
    });

    test('a call still running says nothing yet', () {
      final running = _enter('e2', _other)..status = 'in_progress';
      expect(_offer(_chat([running])), null);
      // What the last completed call said stands until it completes.
      expect(_offer(_chat([_enter('e1', _tree), running])), 'e1');
      final leaving = _exit('x')..status = 'in_progress';
      expect(_offer(_chat([_enter('e1', _tree), leaving])), 'e1');
    });

    test('entered, then left: none', () {
      expect(_offer(_chat([_enter('e', _tree), _read('r'), _exit('x')])), null);
    });

    test('entered twice: the latest', () {
      expect(_offer(_chat([_enter('e1', _tree), _enter('e2', _other)])), 'e2');
      expect(
        _offer(_chat([_enter('e1', _tree), _exit('x'), _enter('e2', _tree)])),
        'e2',
      );
    });

    test('already there, by its folder or its worktree: none', () {
      expect(_offer(_chat([_enter('e', _tree)], folder: _tree)), null);
      final moved = _chat([_enter('e', _tree)], folder: '$_tree/internal')
        ..worktree = Worktree(path: _tree, repo: _repo, branch: 'b');
      expect(_offer(moved), null);
      // An earlier entry doesn't offer once a later one is where it is.
      expect(
        _offer(
          _chat([_enter('e1', _other), _enter('e2', _tree)], folder: _tree),
        ),
        null,
      );
    });

    test("a subagent's calls never carry it, so they don't end it", () {
      expect(
        _offer(_chat([_enter('e', _tree), _read('s', parent: 'agent')])),
        'e',
      );
    });

    test('an archived chat or a side chat: none', () {
      expect(_offer(_chat([_enter('e', _tree)])..archived = true), null);
      expect(_offer(_chat([_enter('e', _tree)]), side: true), null);
    });

    test('a chat with no such call: none', () {
      expect(_offer(_chat([_ask('u'), _read('r')])), null);
    });

    test('the offering row stands alone, never folded into a run', () {
      final items = [
        _read('r1'),
        _read('r2'),
        _enter('e', _tree),
        _read('r3'),
        _read('r4'),
      ];
      final entries = transcriptEntries(items, alone: 'e');
      expect(entries.map(entryKey), ['r1', 'e', 'r3']);
      expect(entries[1], isA<Item>());
      // With no offer (the phone, or after the move) it folds as before.
      expect(transcriptEntries(items).single, isA<List<Item>>());
      // Leaving keeps its row in a run.
      expect(
        transcriptEntries([_read('r1'), _exit('x')]).single,
        isA<List<Item>>(),
      );
    });
  });

  group('in the app', () {
    testWidgets('pressing moves the chat to the worktree; the offer goes', (
      tester,
    ) async {
      final (fake, d) = await _open(tester);
      final row = find.ancestor(
        of: _button(),
        matching: find.byType(ToolCallView),
      );
      expect(row, findsOne);
      expect(
        find.descendant(of: row, matching: find.text('EnterWorktree')),
        findsOne,
      );
      await tester.tap(_button());
      await tester.pumpAndSettle();
      final moved = fake.calls.whereType<MoveChatRequest>().single;
      expect([moved.chatId, moved.folder, moved.worktree], ['c', _tree, false]);

      fake.emit(
        EventsResponse(
          chat: chat('c', 'claude', 'Tidy the store package', folder: _tree),
        ),
      );
      await tester.pumpAndSettle();
      expect(d.chats['c']!.folder, _tree);
      expect(_button(), findsNothing);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('while the agent works it stays put, disabled, and says '
        'when it can move', (tester) async {
      final (fake, d) = await _open(tester, status: ChatStatus(busy: true));
      expect(_button(), findsOne);
      expect(tester.widget<PillButton>(_button()).onPressed, isNull);
      expect(
        tester.widget<PillButton>(_button()).tooltip,
        'The chat can move once the agent is done',
      );
      final before = tester.getRect(_button());

      fake.emit(
        EventsResponse(chatId: 'c', seq: Int64(9), status: ChatStatus()),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<PillButton>(_button()).onPressed, isNotNull);
      expect(tester.getRect(_button()), before);

      // Waiting on the user, the same.
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(10),
          status: ChatStatus(waiting: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<PillButton>(_button()).onPressed, isNull);
      expect(tester.getRect(_button()), before);
      await closeView(tester, d);
    }, variant: onMac);

    testWidgets('a narrow row: the title gives way, the button is whole', (
      tester,
    ) async {
      const width = 300.0;
      viewport(tester, const Size(width, 200));
      final chat = _chat([_enter('e', _tree)]);
      final d = await FakeDaemon([]).connect(tester);
      await tester.pumpWidget(
        themed(
          Padding(
            padding: const EdgeInsets.all(8),
            child: ToolCallView(
              chat.items.single,
              offer: MoveHereButton(chat.items.single, chat, d),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Move chat here'), findsOne);
      final label = tester.renderObject<RenderParagraph>(
        find.text('Move chat here'),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(tester.getRect(_button()).right, lessThanOrEqualTo(width - 8));
      expectTextInside(tester, width);
      d.dispose();
    });
  });

  testWidgets('a row with no offer showing keeps its time when narrow', (
    tester,
  ) async {
    viewport(tester, const Size(260, 200));
    final timed = _enter('e', _tree)
      ..started = msAgo(const Duration(seconds: 9))
      ..ended = msAgo(const Duration(seconds: 4));
    final chat = _chat([timed], folder: _tree);
    final d = await FakeDaemon([]).connect(tester);
    await tester.pumpWidget(
      themed(
        Padding(
          padding: const EdgeInsets.all(8),
          child: ItemView(timed, chat, d, live: false, still: false),
        ),
      ),
    );
    expect(find.byType(CallTime), findsOne);
    d.dispose();
  });

  group('goldens', () {
    for (final b in Brightness.values) {
      testWidgets('the row: offer, disabled, none, ${b.name}', (tester) async {
        viewport(tester, const Size(640, 150), ratio: 2, brightness: b);
        final d = await FakeDaemon([]).connect(tester);
        Widget row(ChatState chat) => ToolCallView(
          chat.items.single,
          offer: MoveHereButton(chat.items.single, chat, d),
        );
        await tester.pumpWidget(
          themed(
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                spacing: 8,
                children: [
                  row(_chat([_enter('e', _tree)])),
                  row(_chat([_enter('e', _tree)])..busy = true),
                  row(_chat([_enter('e', _tree)], folder: _tree)),
                ],
              ),
            ),
            tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/move_here_${b.name}.png'),
        );
        d.dispose();
      });
    }
  });

  for (final b in renderThemes) {
    for (final size in const [Size(1700, 900), Size(720, 900)]) {
      testWidgets('a chat with the offer, ${size.width.toInt()} wide, '
          '${b.name}', (tester) async {
        final (_, d) = await _open(tester, size: size, brightness: b);
        expect(_button(), findsOne);
        expectTextInside(tester, size.width);
        final row = tester.getRect(
          find.ancestor(of: _button(), matching: find.byType(ToolCallView)),
        );
        // At the row's end, before nothing but its own padding.
        expect(tester.getRect(_button()).right, closeTo(row.right, 16));
        await render(
          tester,
          find.byType(NushiApp),
          'move_here_${size.width.toInt()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
