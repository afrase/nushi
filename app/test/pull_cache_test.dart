import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_link.dart';
import 'package:nushi/pull_skeleton.dart';

import 'fake_daemon.dart';
import 'pull_fixture.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

final _ref = GitHubRef(host: 'github.com', repo: fixtureRepo, number: 412);

const _title = "Ignore q params that aren't hashes in admin filters";

/// Keeps the fixture's pull request as read [ago] before the fixture's
/// now, as an earlier open would have.
void _kept(Duration ago, {GitHubPull? pull}) {
  clock = () => fixtureNow.subtract(ago);
  keepPull(_ref, pull ?? fixturePull());
  clock = DateTime.now;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a first open: the skeleton until GitHub answers', (
    tester,
  ) async {
    final answer = Completer<GetGitHubPullResponse>();
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => input is GetGitHubPullRequest ? answer.future : null,
    );
    expect(find.byType(PullSkeleton), findsOneWidget);
    expect(find.text(_title), findsNothing);
    answer.complete(GetGitHubPullResponse(pull: fixturePull()));
    await tester.pumpAndSettle();
    expect(find.byType(PullSkeleton), findsNothing);
    expect(find.text(_title), findsOneWidget);
    expect(find.byKey(const ValueKey('pull-kept')), findsNothing);
    d.dispose();
  }, variant: _mac);

  testWidgets('an open of a pull request read before: it shows at once, '
      '"Updated 2m ago · refreshing", then what GitHub says', (tester) async {
    _kept(const Duration(minutes: 2));
    final answer = Completer<GetGitHubPullResponse>();
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => input is GetGitHubPullRequest ? answer.future : null,
    );
    expect(find.byType(PullSkeleton), findsNothing);
    expect(find.text(_title), findsOneWidget);
    expect(find.text('To do'), findsOneWidget);
    expect(find.text('Updated 2m ago · refreshing'), findsOneWidget);
    answer.complete(
      GetGitHubPullResponse(pull: fixturePull()..item.title = 'Renamed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    expect(find.byKey(const ValueKey('pull-kept')), findsNothing);
    // And it's what shows next time.
    expect(cachedPull(_ref)!.$2.item.title, 'Renamed');
    d.dispose();
  }, variant: _mac);

  testWidgets('after a restart (nothing in memory) it comes from the data '
      "folder; a failed ask keeps it and says when it's from", (tester) async {
    _kept(const Duration(minutes: 5));
    forgetPulls(disk: false);
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      more: (input) => input is GetGitHubPullRequest
          ? Future<GetGitHubPullResponse>.error(StateError('offline'))
          : null,
    );
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Updated 5m ago'), findsOneWidget);
    d.dispose();
  }, variant: _mac);

  testWidgets("the PR widget's pull request is the one kept until asked", (
    tester,
  ) async {
    _kept(const Duration(minutes: 2));
    final (d, _) = await openPullTab(
      tester,
      fixturePull(),
      open: false,
      more: (input) => input is GetGitHubPullRequest
          ? Completer<GetGitHubPullResponse>().future
          : null,
    );
    final cp = ChatPull.of(d, d.chats['c']!);
    expect(cp.pull?.item.title, _title);
    expect(cp.keptAt, fixtureNow.subtract(const Duration(minutes: 2)));
    d.dispose();
  }, variant: _mac);

  test('kept files: one per pull request, private, the 50 newest', () {
    for (var n = 1; n <= 52; n++) {
      keepPull(
        GitHubRef(host: 'github.com', repo: fixtureRepo, number: n),
        fixturePull(),
      );
    }
    forgetPulls(disk: false);
    expect(
      cachedPull(GitHubRef(host: 'github.com', repo: fixtureRepo, number: 52)),
      isNotNull,
    );
    final dir = Directory('$dataDir/pulls');
    final files = dir.listSync().whereType<File>().toList();
    expect(files, hasLength(50));
    expect(
      files.map((f) => f.uri.pathSegments.last),
      contains('github.com_octo_notes_52.pb'),
    );
    String mode(String path) =>
        (Process.runSync('stat', ['-f', '%Lp', path]).stdout as String).trim();
    expect(mode(dir.path), '700');
    expect(mode(files.first.path), '600');
  });
}
