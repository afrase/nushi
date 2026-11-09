import 'dart:convert';
import 'dart:io';

import 'package:diff_view/diff_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/changes_bar.dart';
import 'package:nushi/changes_span.dart';
import 'package:nushi/changes_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/commit_box.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/replies.dart';
import 'package:nushi/review.dart';
import 'package:nushi/review_cards.dart';
import 'package:nushi/review_elsewhere.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Review comments in a related worktree's Changes (ADR 0081, amended
// 2026-11-09): its own, apart from the chat's on a file of the same path,
// and sent to the chat's agent with the worktree named.

const _tree = '/x/.claude/worktrees/a';

RelatedWorktree _worktree({String state = 'present'}) => RelatedWorktree(
  path: _tree,
  branch: 'a',
  baseCommit: 'b' * 40,
  lastHead: 'c' * 40,
  state: state,
);

/// A comment on line 1 of same.go's new side, in view [where].
ReviewComment _comment(String id, String where, String quote, String text) =>
    ReviewComment(
      id: id,
      where: where,
      path: 'same.go',
      old: false,
      start: 1,
      end: 1,
      quote: quote,
      text: text,
    );

/// The comments shown in the diff (not those above the list).
Finder _inDiff(String text) =>
    find.descendant(of: find.byType(DiffBox), matching: find.text(text));

/// Where the unified view's line numbers show [row], on screen.
Offset _gutter(WidgetTester tester, int row) {
  final c = tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller;
  final r = c.resources;
  final y =
      c.unifiedGeometry.topOfRow(row) -
      c.unifiedScroll.position.pixels +
      r.lineHeight / 2;
  return tester.getTopLeft(find.byType(UnifiedDiff)) +
      Offset(r.unifiedGutter.numberRight - 4, y);
}

/// A click on the unified view's line number of new line [line] (from 0).
Future<void> _clickLine(WidgetTester tester, int line) async {
  final c = tester.widget<UnifiedDiff>(find.byType(UnifiedDiff)).controller;
  final at = _gutter(tester, c.unifiedRows.rowOf(PaneSide.neu, line));
  final click = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
  await tester.pump();
  await click.up();
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) => tester.enterText(
  find.descendant(
    of: find.byType(ReviewCommentBox),
    matching: find.byType(EditableText),
  ),
  text,
);

void main() {
  setUpAll(loadFonts);

  late FakeDaemon fake;
  late Daemon daemon;
  late ChatState chatState;

  // The same file in both: its text differs, so a comment read against the
  // other's would move or be outdated.
  Object? answers(Object input) => switch (input) {
    GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
      worktrees: chatState.related.list,
    ),
    GetRelatedWorktreeStatsRequest(:final paths) =>
      GetRelatedWorktreeStatsResponse(
        stats: [for (final p in paths) RelatedWorktreeStats(path: p)],
      ),
    GetFolderStatusRequest() => GetFolderStatusResponse(
      git: true,
      branch: 'main',
      defaultBase: 'main',
    ),
    GetDiffRequest(:final folder) => GetDiffResponse(
      files: [
        FileChange(
          path: 'same.go',
          oldText: 'old\n',
          newText: folder == _tree ? 'tree\n' : 'chat\n',
          added: 1,
          removed: 1,
        ),
      ],
    ),
    _ => null,
  };

  /// Chat c's Changes, its own folder shown, with [comments].
  Future<void> setUpChat(
    WidgetTester tester,
    List<ReviewComment> comments, {
    double width = 1100,
  }) async {
    viewport(tester, Size(width, 640));
    fake = FakeDaemon([chat('c', 'claude', 'Subagents')])..answer = answers;
    daemon = await fake.connect(tester);
    setComments('c', comments);
    chatState = ChatState('c', '/x')..scope = 'uncommitted';
    chatState.related
      ..client = daemon.client
      ..take([_worktree()])
      ..scope = 'uncommitted';
    addTearDown(() => chatState.scope = null);
    addTearDown(() => setComments('c', []));
    await tester.pumpWidget(
      themed(ChangesView(chat: chatState, daemon: daemon)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String entry) async {
    await tester.tap(find.byType(MenuField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry).last);
    await tester.pumpAndSettle();
  }

  final inTree = whereIn('uncommitted', worktree: _tree);

  testWidgets("a worktree's comments are its own: written, edited and kept "
      "apart from the chat's on a file of the same path", (tester) async {
    await setUpChat(tester, [
      _comment('1', 'uncommitted', 'chat', "The chat's"),
    ]);
    expect(_inDiff("The chat's"), findsOne);

    diffUnified.value = true;
    await pick(tester, 'a');
    expect(tester.widget<DiffBox>(find.byType(DiffBox)).review?.where, inTree);
    // Nothing there stages or commits; comments are on.
    expect(find.byType(CommitBox), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(_inDiff("The chat's"), findsNothing);
    expect(find.text("The chat's"), findsOne, reason: 'above the list');
    expect(find.text('Uncommitted · same.go · Line 1'), findsOne);

    // Written on line 1, as in the chat's own.
    await _clickLine(tester, 0);
    await _type(tester, 'Half');
    // A half-written box waits for its own view, not the chat's file.
    await pick(tester, "Chat's folder");
    expect(find.byType(ReviewCommentBox), findsNothing);
    await pick(tester, 'a');
    expect(find.byType(ReviewCommentBox), findsOne);
    await _type(tester, "The worktree's");
    await tester.tap(find.text('Comment'));
    await tester.pumpAndSettle();
    final made = commentsOf('c').where((c) => c.id != '1').single;
    expect((made.where, made.path, made.quote), (inTree, 'same.go', 'tree'));
    expect(made.worktree, _tree);
    expect(_inDiff("The worktree's"), findsOne);

    // Edited there: its Edit shows under the pointer.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_inDiff("The worktree's")));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DiffBox),
        matching: find.byTooltip('Edit'),
      ),
    );
    await tester.pumpAndSettle();
    await _type(tester, 'Edited');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(made.text, 'Edited');

    // Kept until sent, each by its view.
    final saved = jsonDecode(File('$dataDir/reviews.json').readAsStringSync());
    expect(
      [for (final c in (saved as Map)['c'] as List) (c as Map)['where']],
      ['uncommitted', inTree],
    );
    // Reading the worktree's same.go left the chat's comment as it was.
    final chats = commentsOf('c').firstWhere((c) => c.id == '1');
    expect((chats.outdated, chats.start), (false, 1));
    expect(find.text('Send to agent (2)'), findsOne);

    await pick(tester, "Chat's folder");
    expect(_inDiff("The chat's"), findsOne);
    expect(_inDiff('Edited'), findsNothing);
    expect(find.text('a · Uncommitted · same.go · Line 1'), findsOne);
    expect(find.byType(CommitBox), findsOne);
    await closeView(tester, daemon);
  });

  testWidgets("Send to agent puts them in the chat's box, the worktree "
      'named', (tester) async {
    await setUpChat(tester, [
      _comment('2', inTree, 'tree', 'On the worktree'),
      _comment('1', 'uncommitted', 'chat', 'On the chat'),
    ]);
    await pick(tester, 'a');
    // No stage or commit controls beside it.
    expect(find.byType(CommitBox), findsNothing);
    await tester.tap(find.text('Send to agent (2)'));
    await tester.pumpAndSettle();
    expect(chatState.tab.value, ChatTab.chat);
    final cards = chatState.draft.replies.value;
    // The chat's own first, then the worktree's under their lead.
    expect(cards.map((r) => r.text), ['On the chat', 'On the worktree']);
    expect(cards.first.from, myReviewComments);
    const lead =
        'My review comments on the changes in the worktree '
        '`/x/.claude/worktrees/a` on branch `a`, its paths relative to that '
        'folder:';
    expect(cards.last.from, lead);
    expect(cards.last.quote, startsWith('`same.go`, line 1:\n'));
    final message = withReplies(cards, 'Thanks');
    expect(
      message.indexOf(lead),
      allOf(
        greaterThan(message.indexOf('On the chat')),
        lessThan(message.indexOf('On the worktree')),
      ),
    );
    expect(unsentComments('c'), isEmpty);
    chatState.draft.replies.value = const [];
    await tester.pump(const Duration(seconds: 3));
    await closeView(tester, daemon);
  });

  testWidgets("a worktree's card on the chat's file and lines is its own: "
      'taken out of the box, only its comment goes', (tester) async {
    // Both on same.go's old line 1, which the two folders share.
    ReviewComment onOld(String id, String where, String text) => ReviewComment(
      id: id,
      where: where,
      path: 'same.go',
      old: true,
      start: 1,
      end: 1,
      quote: 'old',
      text: text,
    );
    await setUpChat(tester, [
      onOld('1', 'uncommitted', "The chat's"),
      _comment('2', inTree, 'other', 'Another'),
      onOld('3', inTree, "The worktree's"),
      _comment('4', inTree, 'more', 'And another'),
    ]);
    await tester.tap(find.text('Send to agent (4)'));
    await tester.pumpAndSettle();
    final cards = chatState.draft.replies.value;
    expect(cards.map((r) => r.text), [
      "The chat's",
      'Another',
      "The worktree's",
      'And another',
    ]);
    expect(cards[0].quote, cards[2].quote);
    // Queued and taken back to edit: splitReplies gives the worktree's
    // lead to its group's first card only.
    chatState.draft.replies.value = splitReplies(withReplies(cards, '')).$1;
    expect(chatState.draft.replies.value.last.from, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(commentsOf('c').map((c) => c.id), ['1', '2', '3', '4']);
    // The worktree's card on the chat's quote out: the chat's stays.
    chatState.draft.replies.value = [...chatState.draft.replies.value]
      ..removeAt(2);
    await tester.pump(const Duration(seconds: 3));
    expect(commentsOf('c').map((c) => c.id), ['1', '2', '4']);
    expect(commentsOf('c').every((c) => c.sent), isTrue);
    chatState.draft.replies.value = const [];
    await tester.pump(const Duration(seconds: 3));
    await closeView(tester, daemon);
  });

  test("a removed worktree's lead says so, and its last commit", () {
    expect(
      worktreeComments(_tree, _worktree(state: 'removed')),
      'My review comments on the changes in the worktree '
      '`/x/.claude/worktrees/a` on branch `a` (removed since: its last '
      'commit is `ccccccc`), its paths relative to that folder:',
    );
    expect(
      worktreeComments(_tree, null),
      'My review comments on the changes in the worktree '
      '`/x/.claude/worktrees/a`, its paths relative to that folder:',
    );
  });

  test('a view is keyed by its worktree, whose folder may hold anything', () {
    const odd = '/x/a\nb:c';
    final where = whereIn('commits:${'1' * 8}:${'1' * 8}', worktree: odd);
    expect(worktreeOf(where), odd);
    expect(scopeOf(where), 'commits:${'1' * 8}:${'1' * 8}');
    expect(worktreeOf('branch'), isNull);
    expect(whereLabel(where), 'a b:c · Commit 1111111');
    expect(whereLabel(where, [_worktree()]), 'a b:c · Commit 1111111');
    expect(
      whereLabel(whereIn('branch', worktree: _tree), [_worktree()]),
      'a · Branch',
    );
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a narrow bar on a worktree with comments to send, $name', (
      tester,
    ) async {
      final chat = ChatState('c', '/x');
      chat.related
        ..take([_worktree()])
        ..pick(_tree);
      addTearDown(() => setComments('c', []));
      setComments('c', [_comment('1', inTree, 'tree', 'Why?')]);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 520,
              child: RepaintBoundary(
                // On the window's color, as in Changes.
                child: ColoredBox(
                  color: NushiTheme(tokens).t.base,
                  child: ChangesBar(
                    chat: chat,
                    scopes: Scope.values,
                    scope: Scope.branch,
                    files: [FileChange(path: 'same.go', added: 1, removed: 1)],
                    stale: false,
                    behind: false,
                    reloading: false,
                    onAgain: () {},
                  ),
                ),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await tester.pumpAndSettle();
      // Its short name: the long one doesn't fit beside the menu.
      expect(find.text('Send (1)'), findsOne);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ChangesBar),
        matchesGoldenFile('goldens/related_bar_comments_$name.png'),
      );
    });
  }

  // A subagent's branch is long, and after a turn its worktree reads
  // Changed until reloaded: what Send to agent shares the bar with.
  for (final behind in [true, false]) {
    for (final unsent in [1, 12]) {
      testWidgets('the bar fits from 500 wide: behind $behind, $unsent '
          'to send, a long branch, many files', (tester) async {
        viewport(tester, const Size(1100, 200));
        final chat = ChatState('c', '/x');
        chat.related
          ..take([
            RelatedWorktree(
              path: _tree,
              branch: 'worktree-agent-a91f3c2e7d0b',
              lastHead: 'c' * 40,
              state: 'present',
            ),
          ])
          ..pick(_tree);
        addTearDown(() => setComments('c', []));
        setComments('c', [
          for (var i = 0; i < unsent; i++)
            _comment('$i', inTree, 'tree', 'Why?'),
        ]);
        for (var width = 500.0; width <= 1040; width += 20) {
          await tester.pumpWidget(
            themed(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: ColoredBox(
                    color: const NushiTheme(Tokens.dark).t.base,
                    child: ChangesBar(
                      chat: chat,
                      scopes: Scope.values,
                      scope: Scope.branch,
                      files: [
                        for (var i = 0; i < 12; i++)
                          FileChange(path: '$i.go', added: 1234, removed: 567),
                      ],
                      stale: false,
                      behind: behind,
                      reloading: false,
                      onAgain: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width wide');
          // Reload, last, at the bar's edge, and Send to agent beside it.
          expect(
            tester.getTopRight(find.byTooltip('Reload')).dx,
            lessThanOrEqualTo(width),
            reason: '$width wide',
          );
          expect(find.textContaining('($unsent)'), findsOne);
          expect(
            find.textContaining('Changed'),
            behind ? findsOne : findsNothing,
          );
          if (width % 100 == 0) {
            await render(
              tester,
              find.byType(ColoredBox).last,
              'related_bar_${behind ? 'behind' : 'read'}_${unsent}_$width',
            );
          }
        }
      });
    }
  }
}
