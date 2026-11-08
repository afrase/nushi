import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/outside_page.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/web_views_linux.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'outside_fixture.dart';

// Linux's web views (ADR 0102): none, so a file's preview and a browser tab
// are placeholders whose button opens the page in the default browser,
// through the runner's nushi/browser.

void main() {
  setUpAll(loadFonts);

  group("Linux's web views", () {
    test('are placeholders and no diagrams; the browser opens through the '
        'runner, which names it', () async {
      const web = LinuxWebViews();
      expect(web.embedded, isFalse);
      expect(web.page(), isA<OutsidePage>());
      expect(web.tab(BrowserTab()), isA<OutsideTab>());
      expect(web.diagram(), isNull);
      expect(await web.sincePress(), isNull);
      final calls = answerBrowser(
        (c) => c.method == 'browserName' ? 'Firefox' : null,
      );
      await web.openWithBrowser(Uri.file('/Users/me/nushi/index.html'));
      expect(await web.defaultBrowserName(), 'Firefox');
      expect(
        [for (final c in calls) (c.method, c.arguments)],
        [('open', 'file:///Users/me/nushi/index.html'), ('browserName', null)],
      );
    });

    test('say why the browser didn’t open, in words to show', () async {
      const web = LinuxWebViews();
      final url = Uri.parse('https://example.com/');
      Future<String> why() async {
        try {
          await web.openWithBrowser(url);
        } on BrowserError catch (e) {
          return e.message;
        }
        return 'opened';
      }

      // The runner without the call yet (not implemented).
      Exception error = MissingPluginException();
      answerBrowser((_) => throw error);
      expect(await why(), 'Couldn’t open your browser.');
      error = PlatformException(code: 'no-browser');
      expect(
        await why(),
        'No default browser is set: choose one in your system’s settings.',
      );
      error = PlatformException(
        code: 'failed',
        message: 'Failed to execute child process “firefox”',
      );
      expect(
        await why(),
        'Couldn’t open your browser: Failed to execute child process '
        '“firefox”',
      );
    });
  });

  for (final (name, tokens) in [
    ('light', Tokens.light),
    ('dark', Tokens.dark),
  ]) {
    group('looks, $name', () {
      testWidgets('a page’s placeholder', (tester) async {
        pagesOutside();
        defaultBrowser.value = 'Firefox';
        const size = Size(560, 320);
        viewport(tester, size);
        await tester.pumpWidget(
          themed(
            tokens: tokens,
            Center(
              child: RepaintBoundary(
                key: const ValueKey('page'),
                child: SizedBox.fromSize(
                  size: size,
                  child: ColoredBox(
                    color: tokens.base,
                    child: OutsideView(
                      icon: Icons.web_outlined,
                      name: 'index.html',
                      onOpen: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('page')),
          matchesGoldenFile('goldens/outside_page_$name.png'),
        );
      }, variant: linuxOnly);
    });
  }
}
