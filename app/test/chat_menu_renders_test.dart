import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _wt = '/Users/me/.nushi/worktrees/parcel/quiet-fox';

/// The chat's ⋯ menu open, drawn: an awake chat with everything on offer
/// (a linked pull request, a worktree, review comments to send), and a
/// sleeping one; wide and narrow, in both themes.
void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final width in const [1700.0, 720.0]) {
    for (final b in Brightness.values) {
      for (final asleep in [false, true]) {
        final state = asleep ? 'asleep' : 'awake';
        renderTest('the chat menu, $state (${width.toInt()}, ${b.name})', (
          tester,
        ) async {
          showDetails.value = false;
          final c =
              chat(
                  'c',
                  'claude',
                  'Wire the parcel',
                  folder: _wt,
                  status: asleep
                      ? ChatStatus(asleep: true)
                      : ChatStatus(canSleep: true, canFork: true),
                )
                ..worktree = Worktree(
                  repo: '/Users/me/parcel',
                  path: _wt,
                  branch: 'nushi/quiet-fox',
                  base: 'main',
                )
                ..pull = GitHubLink(
                  host: 'github.com',
                  repo: 'example/parcel',
                  number: 42,
                  pull: true,
                );
          addTearDown(() => setComments('c', []));
          setComments('c', [
            ReviewComment(
              id: 'r1',
              where: 'uncommitted',
              path: 'parcel.go',
              old: false,
              start: 1,
              end: 1,
              quote: 'x',
              text: 'Rename this',
            ),
          ]);
          final d = await openApp(
            tester,
            // Agents with MCP servers, so the menu has MCP servers….
            FakeDaemon([c])
              ..agents = [for (final a in readyAgents()) a..mcp = true],
            size: Size(width, 900),
            brightness: b,
          );
          FocusManager.instance.primaryFocus?.unfocus(); // no caret
          await tester.tap(find.byTooltip('Chat menu'));
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(NushiApp),
            'chat_menu_${state}_${width.toInt()}_${b.name}',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }
}
