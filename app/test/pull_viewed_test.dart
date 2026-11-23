import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_viewed.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_files_fixture.dart';
import 'pull_fixture.dart';
import 'pull_overview_fixture.dart';

/// The Files tab of [overviewPull], auth/middleware.go viewed and
/// docs/auth.md viewed before a change; [refuse], GitHub refuses a mark.
Future<(Daemon, FakeDaemon)> _files(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
  Brightness brightness = Brightness.dark,
  bool refuse = false,
}) async {
  sidebarHidden.value = true;
  final (d, fake) = await openPullTab(
    tester,
    overviewPull(),
    size: size,
    brightness: brightness,
    commits: overviewCommits(),
    more: (input) => switch (input) {
      GetGitHubFilesRequest() => overviewFiles(),
      GetGitHubViewedRequest() => GetGitHubViewedResponse(
        viewed: ['auth/middleware.go'],
        changed: ['docs/auth.md'],
      ),
      SetGitHubViewedRequest() when refuse => throw ConnectException(
        Code.permissionDenied,
        'Resource not accessible by integration',
      ),
      ListGitHubHostsRequest() => ListGitHubHostsResponse(
        hosts: [GitHubHost(host: 'github.com', login: 'mira', source: 'gh')],
      ),
      _ => null,
    },
  );
  await tester.tap(find.text('Files changed  4'));
  await tester.pumpAndSettle();
  return (d, fake);
}

Finder _count(String n) => find.text('$n files viewed', findRichText: true);

void main() {
  setUpAll(loadFonts);

  testWidgets('Viewed: read from GitHub, counted, ticked and unticked on '
      'GitHub; a viewed file folds, its chevron opens it again, and the box '
      'never moves', (tester) async {
    final (d, fake) = await _files(tester);
    expect(
      fake.calls.whereType<GetGitHubViewedRequest>().single.ref.number,
      218,
    );
    expect(_count('1 / 4'), findsOneWidget);
    // session.go is picked (it has a thread open), not viewed.
    expect(find.text('auth/session.go'), findsOneWidget);
    expect(tester.widget<ViewedBox>(find.byType(ViewedBox)).viewed, isFalse);
    final box = tester.getRect(find.byType(ViewedBox));

    await tester.tap(find.text('Viewed'));
    await tester.pumpAndSettle();
    final set = fake.calls.whereType<SetGitHubViewedRequest>().single;
    expect(
      (set.host, set.pull, set.path, set.viewed),
      ('github.com', 'PR_218', 'auth/session.go', true),
    );
    expect(_count('2 / 4'), findsOneWidget);
    expect(tester.widget<ViewedBox>(find.byType(ViewedBox)).viewed, isTrue);
    expect(tester.getRect(find.byType(ViewedBox)), box, reason: 'stays put');
    expect(find.textContaining('Its diff is folded'), findsOneWidget);
    expect(find.text('// line 12, changed'), findsNothing);

    await tester.tap(find.byTooltip('Show the diff'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Its diff is folded'), findsNothing);
    expect(tester.widget<ViewedBox>(find.byType(ViewedBox)).viewed, isTrue);

    await tester.tap(find.text('Viewed'));
    await tester.pumpAndSettle();
    expect(fake.calls.whereType<SetGitHubViewedRequest>().last.viewed, isFalse);
    expect(_count('1 / 4'), findsOneWidget);
    expect(tester.getRect(find.byType(ViewedBox)), box);

    // Viewed before a change since: unticked, and GitHub's words.
    await tester.tap(find.text('auth.md'));
    await tester.pumpAndSettle();
    expect(find.text('Changed since last view'), findsOneWidget);
    expect(tester.widget<ViewedBox>(find.byType(ViewedBox)).viewed, isFalse);
    // A viewed one picked shows folded.
    await tester.tap(find.text('middleware.go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Its diff is folded'), findsOneWidget);
    d.dispose();
  }, variant: onMac);

  testWidgets("GitHub's refusal: the box goes back and says why", (
    tester,
  ) async {
    final (d, _) = await _files(tester, refuse: true);
    await tester.tap(find.text('Viewed'));
    await tester.pumpAndSettle();
    expect(_count('1 / 4'), findsOneWidget);
    expect(tester.widget<ViewedBox>(find.byType(ViewedBox)).viewed, isFalse);
    expect(
      find.textContaining('Resource not accessible', findRichText: true),
      findsOneWidget,
    );
    d.dispose();
  }, variant: onMac);

  for (final dark in [true, if (rendering) false]) {
    final name = dark ? 'dark' : 'light';
    for (final width in [1700.0, 720.0]) {
      testWidgets('renders ${width.toInt()}, $name', (tester) async {
        final (d, _) = await _files(
          tester,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        viewport(tester, Size(width, 1000));
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        // The Viewed box at the head's end, inside the window.
        expect(
          tester.getRect(find.byType(ViewedBox)).right,
          lessThanOrEqualTo(width),
        );
        final at = '${width.toInt()}_$name';
        await render(tester, find.byType(NushiApp), 'files_after_$at');
        await tester.tap(find.text('Viewed'));
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'files_after_folded_$at');
        d.dispose();
      }, variant: onMac);
    }
  }
}
