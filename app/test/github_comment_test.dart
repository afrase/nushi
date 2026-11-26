import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show IconTap, LinkText;
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_comment.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart' show loadFonts;
import 'harness.dart';

/// A comment on an issue or in a review's thread, on its own.
void main() {
  setUpAll(loadFonts);

  // A bot's comment folds to a line; Show opens it and reads Hide. The
  // link keeps its width and the time before it its place, so nothing
  // in the line moves as it's pressed.
  testWidgets("a bot's Show keeps its width as it reads Hide, and its "
      'time and Open on GitHub stay put', (tester) async {
    for (final b in renderThemes) {
      viewport(tester, const Size(720, 240));
      await tester.pumpWidget(
        themed(
          tokens: b == Brightness.dark ? Tokens.dark : Tokens.light,
          Padding(
            padding: const EdgeInsets.all(16),
            child: CommentEntry(
              GitHubComment(
                author: 'preview-bot',
                bot: true,
                body: 'Deployed a preview.\n\nIt lives at preview.example.dev.',
                url: 'https://github.com/example/app/issues/7#issuecomment-1',
                createdMs: msAgo(const Duration(minutes: 5)),
              ),
              sendable: false,
            ),
          ),
        ),
      );
      Finder link(String text) =>
          find.byWidgetPredicate((w) => w is LinkText && w.text == text);
      final time = find.text('  5m ago');
      final open = find.byType(IconTap);
      final at = tester.getRect(link('Show'));
      final when = tester.getRect(time);
      final out = tester.getRect(open);
      await render(
        tester,
        find.byType(Scaffold),
        'press_issue_bot_show_${b.name}',
      );
      await tester.tap(link('Show'));
      await tester.pumpAndSettle();
      expect(find.text('It lives at preview.example.dev.'), findsOneWidget);
      expect(tester.getRect(link('Hide')), at);
      expect(tester.getRect(time), when);
      expect(tester.getRect(open), out);
      await render(
        tester,
        find.byType(Scaffold),
        'press_issue_bot_hide_${b.name}',
      );
      await tester.tap(link('Hide'));
      await tester.pumpAndSettle();
      expect(tester.getRect(link('Show')), at);
      expect(tester.getRect(time), when);
    }
  });
}
