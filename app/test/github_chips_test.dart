import 'package:fixnum/fixnum.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_link_chip.dart';
import 'package:nushi/line_icons.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Int64 _ago(Duration d) => Int64(fixtureNow.subtract(d).millisecondsSinceEpoch);

GitHubItem ghItem(
  String repo,
  int n,
  String title, {
  bool pull = true,
  String state = 'open',
  bool draft = false,
  String reason = '',
  String author = 'mira-k',
  int adds = 48,
  int dels = 12,
  int files = 3,
  int comments = 0,
  Duration age = const Duration(minutes: 12),
}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: repo, number: n),
  id: '${pull ? 'PR' : 'I'}_$n',
  pull: pull,
  title: title,
  url: 'https://github.com/$repo/${pull ? 'pull' : 'issues'}/$n',
  state: state,
  draft: draft,
  stateReason: reason,
  author: author,
  createdMs: _ago(age),
  updatedMs: _ago(age),
  additions: adds,
  deletions: dels,
  changedFiles: files,
  comments: comments,
);

const _feed = 'lumen-dev/lumen';

final List<GitHubItem> _items = [
  ghItem(_feed, 221, 'Break cursor ties by post id'),
  ghItem(_feed, 218, 'Paginate the home feed with a keyset cursor'),
  ghItem(
    _feed,
    201,
    'Page 2 of the feed repeats posts',
    pull: false,
    comments: 4,
  ),
  ghItem(
    'jackc/pgx',
    1893,
    'Keyset pagination example skips rows with equal keys',
    state: 'merged',
    author: 'jackc',
  ),
];

const _user =
    'The feed still breaks on page 2. Can you check '
    'https://github.com/lumen-dev/lumen/pull/218 against '
    'https://github.com/lumen-dev/lumen/issues/201?';

const _agent =
    'Found it: the cursor skips posts that share a `published` time. I '
    'opened https://github.com/lumen-dev/lumen/pull/221 on top of '
    '[#218](https://github.com/lumen-dev/lumen/pull/218), so the two merge '
    'in order. [pgx had the same bug](https://github.com/jackc/pgx/pull/1893), '
    'and https://github.com/acme/infra/pull/88 is private. '
    '[Another host](https://git.example/a/b/pull/3) stays a link, and so '
    'does `https://github.com/lumen-dev/lumen/pull/9` in code.';

/// The app on a chat with the user's message and the agent's naming
/// pull requests and issues; GetGitHubItems answers [_items], acme/infra
/// unseen.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required Size size,
  Brightness brightness = Brightness.dark,
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  final c = chat('c', 'claude', 'Paginate the feed');
  final fake = FakeDaemon([c])
    ..answer = (input) => switch (input) {
      GetChatRequest() => GetChatResponse(
        chat: c,
        items: [
          Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: _user),
          Item(
            id: 't',
            kind: ItemKind.ITEM_KIND_TOOL_CALL,
            title: 'gh pr view 221',
            status: 'completed',
            text: 'https://github.com/lumen-dev/lumen/pull/221',
          ),
          Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: _agent),
        ],
      ),
      GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
        items: [
          for (final r in refs)
            ?_items
                .where((i) => i.ref.repo == r.repo && i.ref.number == r.number)
                .firstOrNull,
        ],
        unseen: [
          for (final r in refs)
            if (r.repo == 'acme/infra') r,
        ],
      ),
      _ => null,
    };
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  // The chips' asks, gathered.
  await tester.pump(GitHubItems.gather);
  await tester.pumpAndSettle();
  return (d, fake);
}

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  setUpAll(loadFonts);

  test('an address of a pull request or an issue, and text that names it', () {
    final a = githubAddress(
      'https://github.com/Lumen-Dev/lumen/pull/221/files#x',
    )!;
    expect(
      (a.host, a.repo, a.number, a.pull),
      ('github.com', 'Lumen-Dev/lumen', 221, true),
    );
    expect(a.short, 'Lumen-Dev/lumen#221');
    expect(githubAddress('https://github.com/a/b/issues/3')!.pull, isFalse);
    for (final not in [
      'http://github.com/a/b/pull/3',
      'https://github.com/a/b/pull/x',
      'https://github.com/a/b/pulls',
      'https://github.com/a/../pull/3',
      'https://github.com/a/b/pull/3 and more',
    ]) {
      expect(githubAddress(not), isNull, reason: not);
    }
    const href = 'https://github.com/lumen-dev/lumen/pull/221';
    final b = githubAddress(href)!;
    for (final names in [
      href,
      '#221',
      'lumen-dev/lumen#221',
      'PR #221',
      'pull request lumen-dev/lumen#221',
    ]) {
      expect(namesItem(names, b, href), isTrue, reason: names);
    }
    for (final words in ['the fix', '#222', 'other/repo#221', 'issue 221']) {
      expect(namesItem(words, b, href), isFalse, reason: words);
    }
  });

  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    for (final width in [1700.0, 720.0]) {
      testWidgets(
        'links in messages are chips, asked for in one call; words stay '
        'words; code, tool output and another host stay as written '
        '(${width.round()}, $name)',
        (tester) async {
          final (d, fake) = await _app(
            tester,
            size: Size(width, 700),
            brightness: brightness,
          );
          // 218 twice, 221, 201, acme/infra#88; pgx#1893 as words, asked
          // for only on hover.
          expect(find.byType(GitHubLinkChip), findsNWidgets(5));
          expect(find.byType(GitHubLinkWords), findsOneWidget);
          final asked = fake.calls.whereType<GetGitHubItemsRequest>().toList();
          expect(asked, hasLength(1));
          expect(
            asked.single.refs.map((r) => '${r.repo}#${r.number}').toSet(),
            {
              'lumen-dev/lumen#218',
              'lumen-dev/lumen#201',
              'lumen-dev/lumen#221',
              'acme/infra#88',
            },
          );
          expect(asked.single.quiet, isTrue);
          expect(find.text('Break cursor ties by post id'), findsOneWidget);
          expect(find.text('acme/infra#88'), findsOneWidget);
          expect(find.textContaining('git.example'), findsNothing);
          await render(
            tester,
            find.byType(NushiApp),
            'github_chips_${width.round()}_$name',
          );
          // The pointer on a chip: its card after 400 ms.
          final gesture = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          addTearDown(gesture.removePointer);
          await gesture.moveTo(
            tester.getCenter(find.text('Break cursor ties by post id')),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(GitHubCard), findsNothing);
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(find.byType(GitHubCard), findsOneWidget);
          expect(find.text('lumen-dev/lumen #221'), findsOneWidget);
          expect(find.text('+48 −12', findRichText: true), findsOneWidget);
          await render(
            tester,
            find.byType(NushiApp),
            'github_chip_card_${width.round()}_$name',
          );
          await gesture.moveTo(Offset.zero);
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(find.byType(GitHubCard), findsNothing);
          await closeView(tester, d);
        },
        variant: _mac,
      );
    }
  }

  testWidgets('a chip without data: the address alone, its icon muted', (
    tester,
  ) async {
    viewport(tester, const Size(500, 120));
    final fake = FakeDaemon([]);
    final d = await fake.connect(tester);
    await tester.pumpWidget(
      themed(
        GitHubLinks(
          daemon: d,
          child: Center(
            child: GitHubLinkChip(
              githubAddress('https://github.com/a/b/pull/7')!,
              typed: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(GitHubItems.gather);
    await tester.pumpAndSettle();
    expect(find.text('a/b#7'), findsOneWidget);
    expect(find.text(' · '), findsNothing);
    await closeView(tester, d);
  });

  // Each state the hover card shows, as goldens in both themes.
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the hover card in each state ($name)', (tester) async {
      viewport(tester, const Size(700, 760));
      GitHubAddress at(String repo, int n, {bool pull = true}) =>
          GitHubAddress(host: 'github.com', repo: repo, number: n, pull: pull);
      final asOf = fixtureNow.subtract(const Duration(minutes: 25));
      final cards = [
        GitHubCard(
          at(_feed, 224),
          GitHubLook(
            item: ghItem(
              _feed,
              224,
              'Older posts link in the templates',
              draft: true,
              adds: 31,
              dels: 4,
              files: 2,
            ),
            at: fixtureNow,
          ),
        ),
        GitHubCard(
          at('jackc/pgx', 1893),
          GitHubLook(item: _items[3], at: fixtureNow),
        ),
        GitHubCard(
          at(_feed, 203),
          GitHubLook(
            item: ghItem(
              _feed,
              203,
              'Offset pagination for the feed',
              state: 'closed',
            ),
            at: fixtureNow,
          ),
        ),
        GitHubCard(
          at(_feed, 201, pull: false),
          GitHubLook(item: _items[2], at: fixtureNow),
        ),
        GitHubCard(
          at(_feed, 187, pull: false),
          GitHubLook(
            item: ghItem(
              _feed,
              187,
              'Feed shows deleted posts',
              pull: false,
              state: 'closed',
              reason: 'completed',
              comments: 7,
            ),
            at: fixtureNow,
          ),
        ),
        GitHubCard(
          at(_feed, 176, pull: false),
          GitHubLook(
            item: ghItem(
              _feed,
              176,
              'Infinite scroll on the feed',
              pull: false,
              state: 'closed',
              reason: 'not_planned',
              comments: 12,
            ),
            at: fixtureNow,
          ),
        ),
        GitHubCard(at('acme/infra', 88), const GitHubLook(unseen: true)),
        GitHubCard(
          at(_feed, 218),
          GitHubLook(item: _items[1], at: asOf, error: 'offline'),
        ),
        GitHubCard(at(_feed, 201, pull: false), const GitHubLook(signIn: true)),
        GitHubCard(at(_feed, 221), const GitHubLook(asking: true)),
      ];
      await tester.pumpWidget(
        themed(
          tokens: tokens,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 16, runSpacing: 16, children: cards),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not planned'), findsOneWidget);
      expect(find.textContaining("doesn't show this"), findsOneWidget);
      expect(find.textContaining('Sign in'), findsOneWidget);
      expect(find.textContaining('As it was 25m ago'), findsOneWidget);
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/github_card_states_$name.png'),
      );
      await render(tester, find.byType(Wrap), 'github_card_states_$name');
    });
  }

  testWidgets("GitHub's state icons, large", (tester) async {
    viewport(tester, const Size(460, 70));
    const icons = [
      LineIcon.pullOpen,
      LineIcon.pullDraft,
      LineIcon.pullMerged,
      LineIcon.pullClosed,
      LineIcon.issueOpen,
      LineIcon.issueDone,
      LineIcon.issueNotPlanned,
    ];
    await tester.pumpWidget(
      themed(
        tokens: Tokens.light,
        Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            spacing: 12,
            children: [
              for (final i in icons) i.view(size: 48, color: Colors.black),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Row),
      matchesGoldenFile('goldens/github_state_icons.png'),
    );
  });
}
