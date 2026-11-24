import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/pull_polls.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'pull_fixture.dart';

/// A chat's Pull request tab, drawn as it says how fresh it is: after a
/// good read, while it asks again, and after an ask that failed; wide and
/// narrow, in both themes.
void main() {
  setUpAll(loadFonts);

  for (final width in const [1700.0, 720.0]) {
    for (final b in Brightness.values) {
      renderTest('the tab after a read, asking, failed '
          '(${width.toInt()}, ${b.name})', (tester) async {
        final tag = '${width.toInt()}_${b.name}';
        Completer<GetGitHubPullResponse>? hang;
        var failing = false;
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: Size(width, 900),
          brightness: b,
          open: false,
          more: (input) => input is! GetGitHubPullRequest
              ? null
              : failing
              ? Future<GetGitHubPullResponse>.error(Exception('no network'))
              : hang?.future,
        );
        // The header's tab name may fold away when narrow.
        d.chats['c']!.tab.value = ChatTab.pull;
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'pull_fresh_read_$tag');
        hang = Completer();
        await tester.pump(pullWidgetPoll);
        await tester.pump();
        await render(tester, find.byType(NushiApp), 'pull_fresh_asking_$tag');
        hang.complete(GetGitHubPullResponse(pull: fixturePull()));
        hang = null;
        await tester.pumpAndSettle();
        failing = true;
        await tester.pump(pullWidgetPoll);
        await tester.pumpAndSettle();
        await render(tester, find.byType(NushiApp), 'pull_fresh_failed_$tag');
        await closeView(tester, d);
      }, variant: onMac);

      renderTest('the tab whose first read failed, nothing kept '
          '(${width.toInt()}, ${b.name})', (tester) async {
        final (d, _) = await openPullTab(
          tester,
          fixturePull(),
          size: Size(width, 900),
          brightness: b,
          open: false,
          more: (input) => input is GetGitHubPullRequest
              ? Future<GetGitHubPullResponse>.error(Exception('no network'))
              : null,
        );
        d.chats['c']!.tab.value = ChatTab.pull;
        await tester.pumpAndSettle();
        await render(
          tester,
          find.byType(NushiApp),
          'pull_fresh_unread_${width.toInt()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }
}
