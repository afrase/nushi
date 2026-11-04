import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_header.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

const _new = 'package sub\n\nfunc Sub(a, b int) int {\n\treturn a - b\n}\n';

/// The owner's report: a review comment went with a queued message, the
/// agent committed, and the comment was left where it couldn't be removed
/// or changed. Each case below is one way a comment's file leaves the view
/// it was made in, with the comment unsent, in the box, queued or answered.
void main() {
  setUpAll(loadFonts);

  // What the folder's Uncommitted scope has: sub.go until the agent
  // commits it.
  late List<FileChange> files;

  /// The app on chat c's Changes, sub.go changed and one comment on its
  /// line 4, not sent.
  Future<(Daemon, ChatState)> open(
    WidgetTester tester, {
    double width = 1700,
    Brightness brightness = Brightness.dark,
  }) async {
    viewport(tester, Size(width, 640), brightness: brightness);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('nushi/fonts'),
          (_) async => <String>[],
        );
    paneWidths.value = {};
    showDetails.value = false;
    files = [
      FileChange(
        path: 'sub.go',
        oldText: 'package sub\n',
        newText: _new,
        added: 4,
      ),
    ];
    final fake = FakeDaemon([chat('c', 'claude', 'Subtract')])
      ..answer = (input) => switch (input) {
        GetFolderStatusRequest() => GetFolderStatusResponse(
          git: true,
          branch: 'subtract',
          defaultBase: 'main',
        ),
        GetDiffRequest() => GetDiffResponse(files: files),
        _ => null,
      };
    final d = await fake.connect(tester);
    setComments('c', [
      ReviewComment(
        id: '1',
        where: 'uncommitted',
        path: 'sub.go',
        old: false,
        start: 4,
        end: 4,
        quote: '\treturn a - b',
        before: 'func Sub(a, b int) int {',
        after: '}',
        text: 'Check for overflow.',
      ),
    ]);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final state = d.chats['c']!;
    state.tab.value = ChatTab.changes;
    await tester.pumpAndSettle();
    return (d, state);
  }

  /// Lets the view take what changed: a busy chat's spinner never
  /// settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  void busy(ChatState chat, {required bool on}) {
    chat
      ..status(ChatStatus(busy: on))
      ..notifyListeners();
  }

  /// The composer sends the box while the agent works: its cards go into
  /// a queued message.
  Future<void> queue(WidgetTester tester, ChatState chat) async {
    final cards = chat.draft.replies.value;
    chat.draft.replies.value = const [];
    chat
      ..queue = [QueuedMessage(id: 'q', text: withReplies(cards, 'Thanks.'))]
      ..notifyListeners();
    await tester.pump(const Duration(seconds: 3));
  }

  /// The queued message goes to the agent: it's in the transcript.
  Future<void> deliver(WidgetTester tester, ChatState chat) async {
    final text = chat.queue.single.text;
    chat
      ..queue = []
      ..items.add(
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: text),
      )
      ..notifyListeners();
    await tester.pump(const Duration(seconds: 3));
  }

  /// The agent commits sub.go; the view reads the folder again.
  Future<void> commit(WidgetTester tester, ChatState chat) async {
    files = [];
    await tester.tap(find.byTooltip('Reload'));
    await settle(tester);
  }

  Finder inHeader(String text) =>
      find.descendant(of: find.byType(ChatHeader), matching: find.text(text));

  /// Hovers the comment's card, for its Edit and Remove.
  TestGesture? mouse;
  setUp(() => mouse = null);
  Future<void> hover(WidgetTester tester, String text) async {
    final at = tester.getCenter(find.text(text));
    if (mouse case final m?) {
      await m.moveTo(at);
    } else {
      final m = mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await m.addPointer(location: at);
      addTearDown(m.removePointer);
    }
    await tester.pump();
  }

  testWidgets("the owner's case: sent with a queued message, then the "
      'agent commits; it shows outdated, removable, and goes once the '
      'message is answered', (tester) async {
    final (d, chat) = await open(tester);
    busy(chat, on: true);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    await queue(tester, chat);
    expect(commentsOf('c').single.sent, isTrue);

    await commit(tester, chat);
    // Before the queued message goes: it shows, outdated, with its quote.
    expect(find.text('No changes'), findsOne);
    expect(find.text('Check for overflow.'), findsOne);
    expect(find.text('\treturn a - b'), findsOne);
    expect(find.textContaining('Outdated'), findsOne);
    await hover(tester, 'Check for overflow.');
    expect(find.byTooltip('Remove'), findsOne);
    expect(find.byTooltip('Edit'), findsNothing); // it's sent

    // The message goes and is answered: the comment is done with.
    await deliver(tester, chat);
    busy(chat, on: false);
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(find.text('Check for overflow.'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('one not sent when the commit lands shows outdated, counted, '
      'with Edit and Remove', (tester) async {
    final (d, chat) = await open(tester);
    await commit(tester, chat);
    expect(inHeader('Changes 1'), findsOne);
    expect(find.text('Check for overflow.'), findsOne);
    expect(commentsOf('c').single.outdated, isTrue);

    await hover(tester, 'Check for overflow.');
    await tester.tap(find.byTooltip('Edit'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText).last, 'Overflow?');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(commentsOf('c').single.text, 'Overflow?');

    await hover(tester, 'Overflow?');
    await tester.tap(find.byTooltip('Remove'));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(inHeader('Changes'), findsOne);
    d.dispose();
  }, variant: _mac);

  testWidgets('sent and answered, then a commit: dropped', (tester) async {
    final (d, chat) = await open(tester);
    busy(chat, on: true);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    await queue(tester, chat);
    await deliver(tester, chat);
    busy(chat, on: false);
    await settle(tester);
    expect(commentsOf('c').single.sent, isTrue); // its file is unchanged

    await commit(tester, chat);
    expect(commentsOf('c'), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('the queued message removed after the commit: its comment '
      'goes with it', (tester) async {
    final (d, chat) = await open(tester);
    busy(chat, on: true);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    await queue(tester, chat);
    await commit(tester, chat);

    chat
      ..queue = []
      ..notifyListeners();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(inHeader('Changes'), findsOne);
    expect(find.text('Check for overflow.'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('the queued message taken back to edit: sent again, the '
      'comment stays sent; its card removed from the box, it goes', (
    tester,
  ) async {
    final (d, chat) = await open(tester);
    busy(chat, on: true);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    await queue(tester, chat);
    await commit(tester, chat);

    // Edit: out of the queue, its cards back in the box.
    final text = chat.queue.single.text;
    Future<void> takeBack() async {
      chat
        ..queue = []
        ..notifyListeners();
      chat.draft.replies.value = splitReplies(text).$1;
      await tester.pump(const Duration(seconds: 3));
    }

    await takeBack();
    expect(commentsOf('c').single.sent, isTrue);
    // Sent again: queued again, still sent.
    await queue(tester, chat);
    expect(commentsOf('c').single.sent, isTrue);
    // Taken back again, and the card removed from the box: gone.
    await takeBack();
    chat.draft.replies.value = const [];
    await tester.pump(const Duration(seconds: 3));
    expect(commentsOf('c'), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets("the owner's second report: a stranded comment sent to the "
      'box and its card removed is gone; the next Send to agent sends only '
      'the new comments', (tester) async {
    final (d, chat) = await open(tester);
    await commit(tester, chat);
    expect(inHeader('Changes 1'), findsOne);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    expect(chat.draft.replies.value, hasLength(1));
    // The card taken out of the box (its ×, or the box cleared).
    chat.draft.replies.value = const [];
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(inHeader('Changes'), findsOne);

    // New comments, sent to a queued message: only they go.
    busy(chat, on: true);
    setComments('c', [
      ReviewComment(
        id: '2',
        where: 'uncommitted',
        path: 'add.go',
        old: false,
        start: 1,
        end: 1,
        quote: 'package add',
        text: 'Why a new package?',
      ),
    ]);
    await settle(tester);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    expect(chat.draft.replies.value.map((r) => r.text), ['Why a new package?']);
    await queue(tester, chat);
    expect(splitReplies(chat.queue.single.text).$1, hasLength(1));
    expect(commentsOf('c').map((c) => c.id), ['2']);
    d.dispose();
  }, variant: _mac);

  testWidgets('a comment made in another view shows in this one, named by '
      'its view', (tester) async {
    final (d, chat) = await open(tester);
    chat.scope = 'branch';
    await settle(tester);
    // Branch shows sub.go too, but not Uncommitted's comment on it.
    expect(find.text('Check for overflow.'), findsOne);
    expect(find.textContaining('Uncommitted'), findsWidgets);
    await hover(tester, 'Check for overflow.');
    await tester.tap(find.byTooltip('Remove'));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    d.dispose();
  }, variant: _mac);

  /// Sends the box to the agent as a message (to a busy chat, the agent
  /// takes it into the turn): the cards go with it into the transcript.
  Future<void> send(WidgetTester tester, ChatState chat) async {
    final cards = chat.draft.replies.value;
    chat.draft.replies.value = const [];
    chat
      ..items.add(
        Item(
          id: 'u',
          kind: ItemKind.ITEM_KIND_USER_MESSAGE,
          text: withReplies(cards, 'Thanks.'),
        ),
      )
      ..notifyListeners();
    await tester.pump(const Duration(seconds: 3));
  }

  /// The agent changes sub.go to [text] during its turn, which then ends:
  /// the view reads the folder again.
  Future<void> answer(WidgetTester tester, ChatState chat, String text) async {
    files = [
      FileChange(
        path: 'sub.go',
        oldText: 'package sub\n',
        newText: text,
        added: 4,
      ),
    ];
    busy(chat, on: false);
    await settle(tester);
  }

  // The owner's screenshot: "Outdated · Lines 124–139 · sent" above a file
  // still in the diff, after the turn ended.
  testWidgets('sent, then the agent rewrote its lines: outdated once the '
      'turn ends, and dropped', (tester) async {
    final (d, chat) = await open(tester);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    busy(chat, on: true);
    await send(tester, chat);
    await answer(
      tester,
      chat,
      'package sub\n\nfunc Sub(a, b int) (int, error) {\n'
      '\treturn checked(a - b)\n}\n',
    );
    expect(commentsOf('c'), isEmpty);
    expect(find.text('Check for overflow.'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('sent, then the agent changed the file around its lines: '
      'dropped once the turn ends', (tester) async {
    final (d, chat) = await open(tester);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    busy(chat, on: true);
    await send(tester, chat);
    await answer(tester, chat, '// Package sub subtracts.\n$_new');
    expect(commentsOf('c'), isEmpty);
    d.dispose();
  }, variant: _mac);

  testWidgets('sent and answered with the file unchanged: it stays, dimmed, '
      'and Remove on hover takes it out', (tester) async {
    final (d, chat) = await open(tester);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    busy(chat, on: true);
    await send(tester, chat);
    await answer(tester, chat, _new);
    expect(commentsOf('c').single.sent, isTrue);
    expect(find.text('Line 4 · sent'), findsOne); // under its line
    await hover(tester, 'Check for overflow.');
    expect(find.byTooltip('Edit'), findsNothing);
    await tester.tap(find.byTooltip('Remove'));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(find.text('Check for overflow.'), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('sent and outdated above its file while the turn runs: '
      'Remove on hover takes it out', (tester) async {
    final (d, chat) = await open(tester);
    await tester.tap(find.text('Send to agent (1)'));
    await settle(tester);
    busy(chat, on: true);
    await send(tester, chat);
    files = [
      FileChange(
        path: 'sub.go',
        oldText: 'package sub\n',
        newText: 'package sub\n\nfunc Sub() {}\n',
        added: 2,
      ),
    ];
    await tester.tap(find.byTooltip('Reload'));
    await settle(tester);
    expect(find.text('Outdated · Line 4 · sent'), findsOne);
    await hover(tester, 'Check for overflow.');
    await tester.tap(find.byTooltip('Remove'));
    await settle(tester);
    expect(commentsOf('c'), isEmpty);
    expect(find.text('Check for overflow.'), findsNothing);
    d.dispose();
  }, variant: _mac);

  // Changes with a comment whose file was committed, another file still
  // changed: the comment above the list, at full size.
  for (final (width, brightness) in [
    (1700.0, Brightness.dark),
    (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    (720.0, Brightness.light),
  ]) {
    testWidgets('renders: ${width.round()} ${brightness.name}', (tester) async {
      final (d, chat) = await open(
        tester,
        width: width,
        brightness: brightness,
      );
      await commit(tester, chat);
      files = [
        FileChange(
          path: 'add.go',
          oldText: '',
          newText:
              'package sub\n\nfunc Add(a, b int) int {\n\treturn a + b\n}\n',
          added: 5,
        ),
      ];
      await tester.tap(find.byTooltip('Reload'));
      await settle(tester);
      expect(find.text('1 comment not on these files'), findsOne);
      expect(find.text('Outdated · sub.go · Line 4'), findsOne);
      // Above the list, inside the files' column.
      expect(
        tester.getBottomLeft(find.text('Check for overflow.')).dy,
        lessThan(tester.getTopLeft(find.textContaining('add.go')).dy),
      );
      expectTextInside(tester, width);
      await render(
        tester,
        find.byType(NushiApp),
        'review_orphan_${width.round()}_${brightness.name}',
      );
      d.dispose();
    }, variant: _mac);
  }
}
