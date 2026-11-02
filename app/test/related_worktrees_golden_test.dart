import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagents.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final TargetPlatformVariant _mac = .only(TargetPlatform.macOS);

const _repo = '/Users/me/nushi';
final String _base = 'b' * 40;

RelatedWorktree _worktree(
  String branch,
  String call, {
  String state = 'present',
  bool merged = false,
}) => RelatedWorktree(
  path: '$_repo/.claude/worktrees/$branch',
  branch: branch,
  baseCommit: _base,
  lastHead: 'c' * 40,
  callId: call,
  state: state,
  merged: merged,
);

// A running one has no time: it would count from the real clock.
Item _subagent(String id, String title, String state) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  agent: 'general-purpose',
  title: title,
  status: state == 'running' ? 'in_progress' : 'completed',
  subagent: state == 'running'
      ? Subagent(state: state)
      : Subagent(state: state, started: Int64(1000), ended: Int64(61000)),
);

final List<RelatedWorktree> _worktrees = [
  _worktree('worktree-agent-parser', 'a'),
  _worktree('worktree-agent-docs-and-a-rather-long-branch-name', 'b'),
  _worktree('worktree-agent-merged', 'c', state: 'removed', merged: true),
  _worktree('worktree-agent-squashed', 'd', state: 'removed'),
  _worktree('worktree-agent-collected', 'e', state: 'removed'),
];

RelatedWorktreeStats _stats(String path) {
  if (path.endsWith('collected')) {
    return RelatedWorktreeStats(path: path, commitsGone: true);
  }
  final docs = path.contains('docs');
  return RelatedWorktreeStats(
    path: path,
    files: docs ? 1 : 4,
    added: docs ? 7 : 128,
    removed: docs ? 0 : 36,
    ahead: docs ? 0 : 3,
  );
}

final GetDiffResponse _diff = GetDiffResponse(
  files: [
    FileChange(
      path: 'internal/parser/parse.go',
      oldText: 'package parser\n\nfunc Parse() {}\n',
      newText:
          'package parser\n\n// Parse reads a line.\n'
          'func Parse(line string) error {\n\treturn nil\n}\n',
      added: 4,
      removed: 1,
      status: 'modified',
    ),
    FileChange(
      path: 'README.md',
      newText: 'Notes\n',
      added: 1,
      status: 'added',
    ),
  ],
);

/// The app at [size] on a chat with subagents in related worktrees.
Future<Daemon> _app(
  WidgetTester tester,
  Size size,
  Brightness brightness,
) async {
  viewport(tester, size, brightness: brightness);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('nushi/fonts'),
        (_) async => <String>[],
      );
  paneWidths.value = {};
  showDetails.value = true;
  final fake = FakeDaemon([chat('c', 'claude', 'Rewrite the parser')])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        items: [
          Item(
            id: 'u',
            kind: ItemKind.ITEM_KIND_USER_MESSAGE,
            text: 'Split the parser work among subagents.',
          ),
          _subagent('a', 'Rewrite the parser', 'running'),
          _subagent('b', 'Write the docs', 'done'),
          _subagent('c', 'Fix the tests', 'done'),
        ],
      ),
      GetRelatedWorktreesRequest() => GetRelatedWorktreesResponse(
        worktrees: _worktrees,
      ),
      GetRelatedWorktreeStatsRequest(:final paths) =>
        GetRelatedWorktreeStatsResponse(
          stats: [for (final p in paths) _stats(p)],
        ),
      GetFolderStatusRequest() => GetFolderStatusResponse(
        git: true,
        branch: 'main',
        defaultBase: 'main',
        ahead: 3,
        files: 2,
        added: 5,
        removed: 1,
      ),
      ListCommitsRequest() => ListCommitsResponse(
        commits: [
          Commit(hash: 'c' * 40, short: 'ccccccc', subject: 'Parse a line'),
        ],
      ),
      GetDiffRequest() => _diff,
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  return d;
}

void main() {
  setUpAll(loadFonts);

  for (final (theme, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    Future<void> shot(WidgetTester tester, String name) async {
      // The bar's trailing buttons at its edge, in the Changes tab.
      if (find.byTooltip('Reload').evaluate().isNotEmpty) {
        final right = tester.getTopRight(find.byTooltip('Reload')).dx;
        expect(right, greaterThan(tester.view.physicalSize.width - 40));
      }
      await expectLater(
        find.byType(NushiApp),
        matchesGoldenFile('goldens/${name}_$theme.png'),
      );
    }

    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      Size size() => Size(width, 900);

      testWidgets('golden: the widget and the tags, $w wide, $theme', (
        tester,
      ) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        expect(chat.related.list, hasLength(5));
        // Every line's end at the line's edge, tagged or not.
        final ends = {
          for (final e in find.byIcon(Icons.chevron_right).evaluate())
            if (e.findAncestorWidgetOfExactType<SubagentLine>() != null)
              tester.getTopRight(find.byElementPredicate((x) => x == e)).dx,
        };
        expect(ends, hasLength(1));
        await shot(tester, 'related_chat_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: a worktree in Changes, $w wide, $theme', (
        tester,
      ) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        chat.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        chat.related.pick(_worktrees.first.path);
        await tester.pumpAndSettle();
        await shot(tester, 'related_changes_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: a removed one, $w wide, $theme', (tester) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        chat.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        chat.related.pick(_worktrees[2].path);
        await tester.pumpAndSettle();
        await shot(tester, 'related_removed_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: the menu open, $w wide, $theme', (tester) async {
        final d = await _app(tester, size(), brightness);
        d.chats['c']!.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        await tester.tap(find.text("Chat's folder"));
        await tester.pumpAndSettle();
        await shot(tester, 'related_menu_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: back on the tab, unread, $w wide, $theme', (
        tester,
      ) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        chat.related
          ..pick(_worktrees.first.path)
          ..takeAsked();
        chat.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        expect(find.text('Show its changes'), findsOne);
        await shot(tester, 'related_unread_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: moved on since read, $w wide, $theme', (
        tester,
      ) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        chat.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        chat.related.pick(_worktrees.first.path);
        await tester.pumpAndSettle();
        chat.related.take([
          _worktrees.first.deepCopy()..lastHead = 'd' * 40,
          ..._worktrees.skip(1),
        ]);
        await tester.pumpAndSettle();
        expect(
          find.byTooltip('It changed since this was read: Reload shows it'),
          findsOne,
        );
        await shot(tester, 'related_behind_$w');
        await closeView(tester, d);
      }, variant: _mac);

      testWidgets('golden: commits gone, $w wide, $theme', (tester) async {
        final d = await _app(tester, size(), brightness);
        final chat = d.chats['c']!;
        chat.tab.value = ChatTab.changes;
        await tester.pumpAndSettle();
        chat.related.pick(_worktrees.last.path);
        await tester.pumpAndSettle();
        expect(
          find.text(
            "This worktree's commits are gone: git no longer has them.",
          ),
          findsOne,
        );
        await shot(tester, 'related_gone_$w');
        await closeView(tester, d);
      }, variant: _mac);
    }
  }
}
