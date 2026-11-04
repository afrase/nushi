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

  /// The agent commits sub.go; the view reads the folder again.
  Future<void> commit(WidgetTester tester, ChatState chat) async {
    files = [];
    await tester.tap(find.byTooltip('Reload'));
    await settle(tester);
  }

  Finder inHeader(String text) =>
      find.descendant(of: find.byType(ChatHeader), matching: find.text(text));

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
}
