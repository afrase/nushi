import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_inbox.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'github_view_test.dart' show closeView, item, openView, testNow;

/// An inbox with new and old items, long titles and every badge.
ListGitHubInboxResponse inboxForTests() => ListGitHubInboxResponse(
  review: [
    item(
      41,
      'Speed up the diff of long files by caching the tokenizer per language',
      repo: 'octo/tools',
      checks: 'pending',
      review: 'review_required',
      age: const Duration(minutes: 20),
    ),
    item(
      7,
      'Retry flaky uploads',
      repo: 'octo/infrastructure-terraform',
      checks: 'failure',
      review: 'changes_requested',
      unresolved: 12,
      age: const Duration(days: 12),
    ),
    item(
      3,
      'Move the build to the new runners',
      repo: 'octo/tools',
      checks: 'success',
      review: 'approved',
      age: const Duration(days: 40),
    ),
  ],
  mine: [
    item(
      1,
      'Add Sub and Neg',
      checks: 'failure',
      unresolved: 2,
      age: const Duration(hours: 3),
    ),
    item(5, 'Try a merge queue', draft: true, age: const Duration(days: 100)),
  ],
  assigned: [
    item(2, 'Add a Mul function', pull: false, age: const Duration(days: 340)),
    item(9, 'Old idea', pull: false, age: const Duration(days: 400)),
  ],
  reviewTotal: 3,
  mineTotal: 2,
  assignedTotal: 2,
  atMs: Int64(testNow.millisecondsSinceEpoch),
);

final List<Chat> _chats = [
  chat('c1', 'claude', 'Fix Sub')
    ..github = GitHubLink(
      host: 'github.com',
      id: 'PR_1',
      repo: 'afrase/nushi-gh-test',
      number: 1,
      pull: true,
    ),
];

/// Every text in the inbox's rows takes one line.
void _expectOneLine(WidgetTester tester) {
  final texts = find.descendant(
    of: find.byType(ItemRow),
    matching: find.byType(RichText),
  );
  expect(texts, findsWidgets);
  for (final e in texts.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    final line = p.text.style?.fontSize ?? 14;
    expect(
      p.size.height,
      lessThan(line * 2),
      reason: '"${p.text.toPlainText()}" wraps',
    );
  }
}

void main() {
  setUpAll(loadFonts);

  test('ages in a narrow column', () {
    final cases = {
      const Duration(seconds: 20): 'now',
      const Duration(minutes: 5): '5m',
      const Duration(hours: 3): '3h',
      const Duration(days: 12): '12d',
      const Duration(days: 29): '29d',
      const Duration(days: 35): '5w',
      const Duration(days: 90): '12w',
      const Duration(days: 91): '3mo',
      const Duration(days: 364): '11mo',
      const Duration(days: 400): '1y',
      const Duration(days: 800): '2y',
      const Duration(minutes: -3): 'now', // a clock ahead of ours
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      expect(agoShort(key), value, reason: '$key');
    }
    expect(dateTime(DateTime(2026, 9, 16, 9, 5)), '2026-09-16 09:05');
  });

  testWidgets('every row says its age the same short way, on one line, '
      'the date and time on hover', (tester) async {
    for (final width in [400.0, 480.0, 1100.0]) {
      final (_, d) = await openView(
        tester,
        size: Size(width, 640),
        inbox: inboxForTests(),
        chats: _chats,
      );
      for (final age in ['20m', '12d', '5w', '3h', '3mo', '11mo', '1y']) {
        expect(find.text(age), findsOneWidget, reason: '$age at $width');
      }
      expect(find.textContaining('2026-'), findsNothing);
      _expectOneLine(tester);
      // The column is as wide in every row.
      final widths = {
        for (final e in find.byType(ItemAge).evaluate())
          (e.renderObject! as RenderBox).size.width,
      };
      expect(widths, hasLength(1));
      await closeView(tester, d);
    }
    final (_, d) = await openView(tester, inbox: inboxForTests());
    final tip = tester.widget<Tooltip>(
      find.ancestor(of: find.text('12d'), matching: find.byType(Tooltip)),
    );
    final when = testNow.subtract(const Duration(days: 12));
    expect(tip.message, 'Updated ${dateTime(when)}');
    await closeView(tester, d);
  });

  testWidgets("a long repository's name never cuts the title: each has "
      'its own line', (tester) async {
    final (_, d) = await openView(
      tester,
      size: const Size(420, 640),
      inbox: ListGitHubInboxResponse(
        mine: [
          item(
            7,
            'Retry flaky uploads',
            repo: 'boltops-tools/puma-cloudwatch-and-a-much-longer-name',
          ),
        ],
      ),
    );
    RenderParagraph p(String text) =>
        tester.renderObject(find.textContaining(text)) as RenderParagraph;
    expect(p('Retry flaky uploads').didExceedMaxLines, isFalse);
    expect(p('boltops-tools/').didExceedMaxLines, isTrue); // cut instead
    await closeView(tester, d);
  });

  testWidgets('the inbox as it was last, until GitHub answers; rows that '
      'are coming when nothing was kept', (tester) async {
    for (final kept in [true, false]) {
      final fresh = Completer<ListGitHubInboxResponse>();
      final (_, d) = await openView(
        tester,
        more: (input) => switch (input) {
          ListGitHubInboxRequest(cached: true) => ListGitHubInboxResponse(
            mine: [if (kept) item(7, 'As it was')],
            atMs: kept
                ? Int64(
                    testNow
                        .subtract(const Duration(minutes: 5))
                        .millisecondsSinceEpoch,
                  )
                : Int64.ZERO,
          ),
          ListGitHubInboxRequest() => fresh.future,
          _ => null,
        },
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('As it was'), kept ? findsOneWidget : findsNothing);
      expect(
        find.text('Updated 5m ago · refreshing'),
        kept ? findsOneWidget : findsNothing,
      );
      expect(find.byType(RowsLoading), kept ? findsNothing : findsOneWidget);
      fresh.complete(
        ListGitHubInboxResponse(
          mine: [item(8, 'As it is')],
          atMs: Int64(testNow.millisecondsSinceEpoch),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('As it was'), findsNothing);
      expect(find.text('As it is'), findsOneWidget);
      expect(find.textContaining('Updated'), findsNothing);
      await closeView(tester, d);
    }
  });

  testWidgets('Review requested: only me at first, or me and my teams, '
      'remembered', (tester) async {
    Directory(dataDir).createSync(recursive: true); // the tests' own
    // The asks that reach GitHub, not those for what the daemon kept.
    List<ListGitHubInboxRequest> asks(FakeDaemon fake) => [
      for (final r in fake.calls.whereType<ListGitHubInboxRequest>())
        if (!r.cached) r,
    ];
    var (fake, d) = await openView(tester);
    final first = asks(fake).single;
    expect(first.teams, isFalse);
    await tester.tap(find.text('Only me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me and my teams').last);
    await tester.pumpAndSettle();
    final asked = asks(fake);
    expect((asked.length, asked.last.teams), (2, true));
    expect(find.text('Me and my teams'), findsOneWidget);
    expect(githubTeamReviews.value, isTrue);
    final saved = jsonDecode(File('$dataDir/app.json').readAsStringSync());
    expect((saved as Map)['githubTeams'], isTrue);
    await closeView(tester, d);
    // Opened again (the app restarted keeps it in app.json): as left.
    (fake, d) = await openView(tester, teams: null);
    expect(asks(fake).single.teams, isTrue);
    expect(find.text('Me and my teams'), findsOneWidget);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final (wide, width) in [('narrow', 480.0), ('wide', 1100.0)]) {
      testWidgets('golden, $wide, $name', (tester) async {
        final (_, d) = await openView(
          tester,
          tokens: tokens,
          size: Size(width, 520),
          inbox: inboxForTests(),
          chats: _chats,
        );
        await expectLater(
          find.byType(GitHubView),
          matchesGoldenFile('goldens/github_rows_${wide}_$name.png'),
        );
        await closeView(tester, d);
      });
    }
  }
}
