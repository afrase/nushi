import 'dart:io';

import 'package:connectrpc/connect.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_reactions.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';
import 'pull_overview_fixture.dart';

GitHubReaction _r(String kind, int n, {bool mine = false}) =>
    GitHubReaction(content: kind, count: n, mine: mine);

/// [overviewPull] with reactions: on its description, mira's comment and
/// tomas's thread comment.
GitHubPull _pull() {
  final p = overviewPull();
  p.reactions.add(_r('hooray', 2));
  p.conversation.single.reactions.addAll([
    _r('thumbs_up', 3, mine: true),
    _r('eyes', 1),
  ]);
  p.threads.first.comments.first.reactions.add(_r('heart', 1));
  return p;
}

/// The Overview of [_pull], scrolled to mira's comment; GitHub keeps each
/// reaction (the pull request read again says it), or with [refuse]
/// refuses it.
Future<(Daemon, FakeDaemon)> _open(
  WidgetTester tester, {
  Size size = const Size(1700, 1000),
  Brightness brightness = Brightness.dark,
  bool refuse = false,
}) async {
  sidebarHidden.value = true;
  final whole = _pull();
  final (d, fake) = await openPullTab(
    tester,
    whole,
    size: size,
    brightness: brightness,
    commits: overviewCommits(),
    more: (input) {
      if (input is! ReactGitHubRequest) {
        return input is ListGitHubHostsRequest
            ? ListGitHubHostsResponse(
                hosts: [
                  GitHubHost(host: 'github.com', login: 'mira', source: 'gh'),
                ],
              )
            : null;
      }
      if (refuse) {
        throw ConnectException(Code.permissionDenied, 'Reactions are off');
      }
      final c = whole.conversation.single;
      final now = toggled(c.reactions, input.content);
      c.reactions
        ..clear()
        ..addAll(now);
      return ReactGitHubResponse();
    },
  );
  // In the middle of the window, clear of the slim bar over its top.
  await Scrollable.ensureVisible(
    tester.element(
      find.textContaining('Moved it into', findRichText: true).first,
    ),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  return (d, fake);
}

/// Mira's comment's reactions.
Finder get _mira =>
    find.byWidgetPredicate((w) => w is Reactions && w.subject == 'IC_mira');

Finder _inMira(Finder f) => find.descendant(of: _mira, matching: f);

/// The Mac's emoji font, for a picture to look at; the tests' fonts have
/// none.
const _emojiFont = '/System/Library/Fonts/Apple Color Emoji.ttc';

void main() {
  setUpAll(loadFonts);

  test('the words, and a toggle keeps GitHub order', () {
    expect(
      reactedWords(_r('thumbs_up', 3, mine: true)),
      'You and 2 others '
      'reacted with +1',
    );
    expect(
      reactedWords(_r('heart', 2, mine: true)),
      'You and 1 other '
      'reacted with heart',
    );
    expect(reactedWords(_r('heart', 1, mine: true)), 'You reacted with heart');
    expect(reactedWords(_r('eyes', 4)), '4 reacted with eyes');
    final shown = [_r('thumbs_up', 1, mine: true), _r('eyes', 1)];
    expect(toggled(shown, 'thumbs_up'), [_r('eyes', 1)]);
    expect(toggled(shown, 'rocket'), [
      _r('thumbs_up', 1, mine: true),
      _r('rocket', 1, mine: true),
      _r('eyes', 1),
    ]);
    expect(toggled(shown, 'eyes').last, _r('eyes', 2, mine: true));
  });

  testWidgets('reactions under the description, a comment and a thread '
      "comment; a pill takes mine away, the picker adds one, and GitHub's "
      'refusal puts it back', (tester) async {
    final (d, fake) = await _open(tester);
    expect(find.byType(Reactions), findsNWidgets(6), reason: 'each comment');
    expect(find.byTooltip('You and 2 others reacted with +1'), findsOneWidget);
    expect(find.byTooltip('1 reacted with heart'), findsOneWidget);
    expect(find.byTooltip('2 reacted with hooray'), findsOneWidget);

    await tester.tap(find.byTooltip('You and 2 others reacted with +1'));
    await tester.pumpAndSettle();
    final off = fake.calls.whereType<ReactGitHubRequest>().single;
    expect(
      (off.host, off.subject, off.content, off.remove),
      ('github.com', 'IC_mira', 'thumbs_up', true),
    );
    expect(_inMira(find.byTooltip('2 reacted with +1')), findsOneWidget);

    final smiley = _inMira(find.byTooltip('Add reaction'));
    final at = tester.getRect(smiley);
    await tester.tap(smiley);
    await tester.pumpAndSettle();
    for (final (kind, _, _) in reactionKinds) {
      expect(find.byKey(ValueKey('react $kind')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('react rocket')));
    await tester.pumpAndSettle();
    final on = fake.calls.whereType<ReactGitHubRequest>().last;
    expect((on.content, on.remove), ('rocket', false));
    expect(_inMira(find.byTooltip('You reacted with rocket')), findsOneWidget);
    expect(tester.getRect(smiley), at, reason: 'the smiley never moves');
    d.dispose();
  }, variant: onMac);

  testWidgets("GitHub's refusal puts the pill back and says why", (
    tester,
  ) async {
    final (d, _) = await _open(tester, refuse: true);
    await tester.tap(find.byTooltip('You and 2 others reacted with +1'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('You and 2 others reacted with +1'), findsOneWidget);
    expect(
      find.textContaining('Reactions are off', findRichText: true),
      findsOneWidget,
    );
    d.dispose();
  }, variant: onMac);

  for (final dark in [true, if (rendering) false]) {
    final name = dark ? 'dark' : 'light';
    for (final width in [1700.0, 720.0]) {
      testWidgets(
        'renders ${width.toInt()}, $name, the picker open',
        (tester) async {
          final font = FontLoader('Apple Color Emoji')
            ..addFont(
              Future.value(
                ByteData.sublistView(File(_emojiFont).readAsBytesSync()),
              ),
            );
          await tester.runAsync(font.load);
          // Opened wide, then narrowed: the chat's header folds its tabs
          // at 720.
          final (d, _) = await _open(
            tester,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          viewport(tester, Size(width, 1000));
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(tester.element(_mira), alignment: 0.5);
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await tester.tap(_inMira(find.byTooltip('Add reaction')));
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(NushiApp),
            'reactions_after_${width.toInt()}_$name',
          );
          d.dispose();
        },
        variant: onMac,
        // The Mac's emoji font, read where it is: not on Linux.
        skip: !File(_emojiFont).existsSync(),
      );
    }
  }

  // Gates above the floor keep one test of the daemon below them (ADR
  // 0004): before reactions (API 131), none shows, and no picker.
  testWidgets('a daemon older than reactions shows none', (tester) async {
    final fake = FakeDaemon([])
      ..answer = (input) => input is PingRequest
          ? PingResponse(apiVersion: reactionsApi - 1)
          : null;
    final d = await fake.connect(tester);
    Widget reactions() => themed(
      Reactions(
        'IC_mira',
        [_r('thumbs_up', 3, mine: true)],
        reacting: (daemon: d, host: 'github.com', onChanged: () async {}),
      ),
    );
    await tester.pumpWidget(reactions());
    expect(find.byTooltip('Add reaction'), findsNothing);
    expect(find.byTooltip('You and 2 others reacted with +1'), findsNothing);
    // From reactions on, the same shows them.
    d.daemonApi = reactionsApi;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(reactions());
    expect(find.byTooltip('Add reaction'), findsOne);
    expect(find.byTooltip('You and 2 others reacted with +1'), findsOne);
    d.dispose();
  });
}
