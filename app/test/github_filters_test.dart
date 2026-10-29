import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_view.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'github_inbox_test.dart' show inboxForTests;
import 'github_view_test.dart' show item, openView, testNow;
import 'harness.dart';

/// The asks that reach GitHub, not those for what the daemon kept.
List<ListGitHubInboxRequest> _asks(FakeDaemon fake) => [
  for (final r in fake.calls.whereType<ListGitHubInboxRequest>())
    if (!r.cached) r,
];

/// An inbox as the daemon answers [r]: Review requested and Assigned
/// issues have older items, unless widened.
ListGitHubInboxResponse _answer(ListGitHubInboxRequest r) =>
    ListGitHubInboxResponse(
      review: [
        item(41, 'Speed up the diff', repo: 'octo/tools'),
        if (r.wide.contains('review'))
          item(3, 'An old one', repo: 'octo/tools'),
      ],
      mine: [item(1, 'Add Sub and Neg')],
      reviewTotal: r.wide.contains('review') ? 2 : 1,
      mineTotal: 1,
      reviewOlder: r.updatedDays > 0 && !r.wide.contains('review') ? 1 : 0,
      assignedOlder: r.updatedDays > 0 && !r.wide.contains('assigned') ? 3 : 0,
      atMs: Int64(testNow.millisecondsSinceEpoch),
    );

Future<void> _pick(WidgetTester tester, String menu, Pattern entry) async {
  await tester.tap(find.text(menu));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(entry, findRichText: true).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadFonts();
    Directory(dataDir).createSync(recursive: true); // the tests' own
  });
  tearDown(() {
    githubDays.value = 90;
    githubHidden.value = {};
    githubOwners.value = {};
  });

  testWidgets('the last 90 days at first, in the search; another span asks '
      'again and is remembered', (tester) async {
    final (fake, d) = await openView(tester);
    expect(_asks(fake).single.updatedDays, 90);
    expect(find.text('Last 90 days'), findsOneWidget);
    await _pick(tester, 'Last 90 days', 'Last 30 days');
    expect(_asks(fake).last.updatedDays, 30);
    expect(readSaved()['githubDays'], 30);
    await _pick(tester, 'Last 30 days', 'Any time');
    expect(_asks(fake).last.updatedDays, 0);
    await closeView(tester, d);
  });

  testWidgets("a card's older items: how many, and Show widens only that "
      'card, until the span changes', (tester) async {
    final (fake, d) = await openView(
      tester,
      more: (input) => input is ListGitHubInboxRequest ? _answer(input) : null,
    );
    expect(find.text('1 older than 90 days'), findsOneWidget);
    expect(find.text('3 older than 90 days'), findsOneWidget);
    expect(find.text('An old one'), findsNothing);
    await tester.tap(find.text('Show').first); // Review requested's
    await tester.pumpAndSettle();
    expect(_asks(fake).last.wide, ['review']);
    expect(_asks(fake).last.updatedDays, 90);
    expect(find.text('An old one'), findsOneWidget);
    expect(find.text('1 older than 90 days'), findsNothing);
    expect(find.text('3 older than 90 days'), findsOneWidget); // the other
    await _pick(tester, 'Last 90 days', 'Last year');
    expect(_asks(fake).last.wide, isEmpty);
    expect(find.text('3 older than a year'), findsOneWidget);
    await closeView(tester, d);
  });

  testWidgets("a row's Hide this repository, in the search; shown again "
      'from the menu', (tester) async {
    // The daemon leaves the hidden out.
    final (fake, d) = await openView(
      tester,
      more: (input) {
        if (input is! ListGitHubInboxRequest) return null;
        final all = inboxForTests();
        bool shown(GitHubItem it) =>
            !input.hide.contains(it.ref.repo) &&
            !input.hide.contains(it.ref.repo.split('/').first);
        return all
          ..review.retainWhere(shown)
          ..mine.retainWhere(shown)
          ..assigned.retainWhere(shown);
      },
    );
    await tester.tap(
      find.text('Retry flaky uploads'),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Hide this repository', findRichText: true),
    );
    await tester.pumpAndSettle();
    expect(_asks(fake).last.hide, ['octo/infrastructure-terraform']);
    expect((readSaved()['githubHidden']! as Map)['github.com'], [
      'octo/infrastructure-terraform',
    ]);
    // The menu says so, and lists it to show it again.
    await _pick(
      tester,
      'All repositories · 1 hidden',
      'octo/infrastructure-terraform',
    );
    expect(_asks(fake).last.hide, isEmpty);
    expect(find.text('All repositories'), findsOneWidget);
    // An owner from the menu.
    await _pick(tester, 'All repositories', RegExp(r'^octo$'));
    expect(_asks(fake).last.hide, ['octo']);
    await closeView(tester, d);
  });

  testWidgets('only some owners: checked names, in the search, remembered '
      "per host; my folders' repositories instead", (tester) async {
    final (fake, d) = await openView(tester);
    await _pick(tester, 'All repositories', 'Only owners…');
    await tester.enterText(find.byType(TextField), 'afrase, my org/x');
    await tester.tap(find.text('Only these'));
    await tester.pumpAndSettle();
    expect(find.textContaining("“org/x” isn't"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'afrase my-org');
    await tester.tap(find.text('Only these'));
    await tester.pumpAndSettle();
    expect(_asks(fake).last.owners, ['afrase', 'my-org']);
    expect(githubOwners.value, {
      'github.com': ['afrase', 'my-org'],
    });
    expect(find.text('afrase, my-org'), findsOneWidget);
    await _pick(tester, 'afrase, my-org', "My folders' repositories");
    expect(_asks(fake).last.owners, isEmpty);
    expect(_asks(fake).last.repos, ['afrase/nushi-gh-test']);
    await _pick(tester, "My folders' repositories", 'All repositories');
    expect(_asks(fake).last.owners, isEmpty);
    expect(githubOwners.value['github.com'], isEmpty);
    await closeView(tester, d);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('golden: the older items line, $name', (tester) async {
      githubHidden.value = {
        'github.com': ['boltops-tools/puma-cloudwatch'],
      };
      final (_, d) = await openView(
        tester,
        tokens: tokens,
        size: const Size(760, 400),
        keep: true,
        more: (input) =>
            input is ListGitHubInboxRequest ? _answer(input) : null,
      );
      await expectLater(
        find.byType(GitHubView),
        matchesGoldenFile('goldens/github_older_$name.png'),
      );
      await closeView(tester, d);
    });

    for (final (menu, label) in [
      ('repos', 'All repositories · 1 hidden'),
      ('updated', 'Last 90 days'),
    ]) {
      testWidgets('golden: the $menu menu, $name', (tester) async {
        // The whole window, the menu's overlay with it, at 1×.
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        githubHidden.value = {
          'github.com': ['boltops-tools/puma-cloudwatch'],
        };
        final (_, d) = await openView(
          tester,
          tokens: tokens,
          size: const Size(760, 460),
          keep: true,
          inbox: inboxForTests(),
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/github_${menu}_menu_$name.png'),
        );
        await closeView(tester, d);
      });
    }
  }
}
