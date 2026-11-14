import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_link_chip.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/pull_states.dart';

import 'fake_daemon.dart';
import 'github_fixture.dart' show item, pull;
import 'harness.dart';

const _repo = 'afrase/nushi-gh-test';

GitHubLink _link(int n) => GitHubLink(
  host: 'github.com',
  repo: _repo,
  number: n,
  id: 'PR_$n',
  pull: true,
);

Chat _chat() => chat('a', 'claude', 'Add Sub')
  ..pull = _link(1)
  ..pulls.addAll([_link(1), _link(2), _link(3)]);

GitHubItem _item(int n) => switch (n) {
  1 => item(1, 'Add Sub', checks: 'failure'),
  2 => item(2, 'Add Neg', checks: 'pending', draft: true),
  _ => item(3, 'Docs for Sub and Neg', checks: 'success', state: 'merged'),
}..additions = 10 * n;

Object? _answer(Object input) => switch (input) {
  GetChatRequest() => GetChatResponse(
    chat: _chat(),
    items: [
      Item(
        id: 'm',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text:
            'I opened https://github.com/$_repo/pull/2 on top of '
            'https://github.com/$_repo/pull/1.',
      ),
    ],
  ),
  GetGitHubPullRequest() => GetGitHubPullResponse(
    pull: pull()..item.id = 'PR_1',
  ),
  GetGitHubItemsRequest(:final refs) => GetGitHubItemsResponse(
    items: [for (final r in refs) _item(r.number)],
  ),
  GetGitHubStatesRequest() => GetGitHubStatesResponse(
    items: [_item(1), _item(2), _item(3)],
  ),
  _ => null,
};

void main() {
  setUpAll(loadFonts);

  for (final size in const [Size(390, 844), Size(430, 932), Size(844, 390)]) {
    for (final (name, brightness) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets("the chat's bar: the primary and +2; a tap, the rows; a "
          'chip, its card as a sheet '
          '(${size.width.toInt()}×${size.height.toInt()}, $name)', (
        tester,
      ) async {
        viewport(tester, size, ratio: 2);
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final fake = FakeDaemon([_chat()])..answer = _answer;
        final platform = PhonePlatform()..saved = pairedRecord();
        final phone = await startPhone(tester, fake, platform: platform);
        await tester.tap(find.text('Add Sub'));
        await tester.pumpAndSettle();
        await tester.pump(GitHubItems.gather);
        await tester.pumpAndSettle();
        final chip = find.byType(PullChip);
        expect(find.descendant(of: chip, matching: find.text('+2')), findsOne);
        expect(tester.getTopRight(chip).dx, lessThanOrEqualTo(size.width));
        expect(find.byType(GitHubLinkChip), findsNWidgets(2));
        final tag = '${size.width.toInt()}_$name';
        await render(tester, find.byType(PhoneApp), 'pull_phone_chips_$tag');
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(find.text('3 pull requests'), findsOne);
        expect(find.text('Docs for Sub and Neg'), findsOne);
        await render(tester, find.byType(PhoneApp), 'pull_phone_rows_$tag');
        await tester.tapAt(const Offset(10, 10)); // the scrim
        await tester.pumpAndSettle();
        await tester.tap(find.byType(GitHubLinkChip).first);
        await tester.pumpAndSettle();
        expect(find.byType(GitHubCardBody), findsOne);
        expect(find.text('Open on GitHub'), findsOne);
        await render(tester, find.byType(PhoneApp), 'pull_phone_card_$tag');
        await endPhone(tester, phone);
      });
    }
  }
}
