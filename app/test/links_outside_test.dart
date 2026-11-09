import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart' show openWeb, openWebLink;
import 'package:nushi/native.dart';
import 'package:nushi/terminal_find.dart' show openLink;
import 'package:nushi/web_page.dart' show openInBrowser, openLinkOrSay;
import 'package:nushi/web_views.dart';
import 'package:nushi/web_views_linux.dart';

import 'outside_fixture.dart';

// The links a click opens outside a chat's own pages (Jira's, GitHub's, a
// terminal's, the update card's, the agents' and an account's page) and
// mail: on the Mac through url_launcher, as always; on Linux through the
// runner's nushi/browser, whose launch leaves Nushi's variables out of the
// app it starts (ADR 0104). A click that opens nothing says why in a snack
// bar, as a page's Open in browser does.

/// What url_launcher was asked to open while the test runs, answering
/// [opens]: its default platform's channel, as a test host has it (no app
/// registers the Mac's).
List<String> _launched({bool opens = true}) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final urls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(channel, (c) async {
          if (c.method == 'launch') {
            urls.add((c.arguments as Map<Object?, Object?>)['url']! as String);
          }
          return opens;
        });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return urls;
}

/// A context under a window with a scaffold, where a snack bar shows.
Future<BuildContext> _window(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return context;
}

/// What the window's snack bars say, the last one first shown.
List<String> _said(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
  ))
    t.data!,
];

/// Opens [url] each way a click outside a chat does: the shared call
/// (Jira's, the agents' and an account's page), GitHub's and the update
/// card's [openWeb], a terminal's Ctrl-click.
Future<void> _openEachWay(WidgetTester tester, String url) async {
  final context = await _window(tester);
  await openLinkOrSay(context, Uri.parse(url));
  openWeb(context, url);
  await openLink(context, url, '/home/me', (_) async => false);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on the Mac a link opens with url_launcher, as it always did, '
      'and the runner hears nothing', (tester) async {
    final launched = _launched();
    final runner = answerBrowser((_) => null);
    await _openEachWay(tester, 'https://github.com/afrase/nushi/pull/7');
    expect(launched, List.filled(3, 'https://github.com/afrase/nushi/pull/7'));
    expect(runner, isEmpty);
    expect(_said(tester), isEmpty);
  });

  testWidgets('on the Mac a link url_launcher couldn’t open says so, a '
      'chat’s too', (tester) async {
    _launched(opens: false);
    final context = await _window(tester);
    await openLinkOrSay(context, Uri.parse('https://example.com'));
    await tester.pump();
    expect(_said(tester), ['Couldn’t open your browser.']);
    ScaffoldMessenger.of(context).clearSnackBars();
    await tester.pumpAndSettle();
    await openWebLink(context, Uri.parse('https://example.com'));
    await tester.pump();
    expect(_said(tester), ['Couldn’t open your browser.']);
  });

  group('on Linux', () {
    setUp(() => native.web = const LinuxWebViews());

    testWidgets('a link opens with the runner’s browser, never '
        'url_launcher; GitHub’s refuses what isn’t http(s)', (tester) async {
      final launched = _launched();
      final runner = answerBrowser((_) => null);
      await _openEachWay(tester, 'https://example.atlassian.net/browse/NU-1');
      openWeb(await _window(tester), 'javascript:alert(1)');
      await tester.pump();
      expect(launched, isEmpty);
      expect([
        for (final c in runner) (c.method, c.arguments),
      ], List.filled(3, ('open', 'https://example.atlassian.net/browse/NU-1')));
      expect(_said(tester), isEmpty);
    });

    testWidgets('a link that opens nothing says why in a snack bar, each '
        'way; only http and https go to the browser', (tester) async {
      final runner = answerBrowser(
        (_) => throw PlatformException(code: 'no-browser'),
      );
      const none =
          'No default browser is set: choose one in your system’s settings.';
      final context = await _window(tester);
      for (final click in <Future<void> Function()>[
        () => openLinkOrSay(context, Uri.parse('https://example.com/a')),
        () async => openWeb(context, 'https://example.com/b'),
        () =>
            openLink(context, 'https://example.com/c', '/', (_) async => true),
      ]) {
        await click();
        await tester.pump();
        expect(_said(tester), [none]);
        ScaffoldMessenger.of(context).clearSnackBars();
        await tester.pumpAndSettle();
      }
      expect(runner, hasLength(3));
      await openLinkOrSay(context, Uri.file('/home/me/run.sh'));
      await tester.pump();
      expect(_said(tester), ['Only a web link opens in the browser.']);
      expect(runner, hasLength(3));
    });

    test('mail opens with the runner’s mail app, saying why when it '
        'can’t', () async {
      final launched = _launched();
      Exception? error;
      final runner = answerBrowser((_) {
        if (error case final e?) throw e;
        return null;
      });
      await openInBrowser(Uri.parse('mailto:me@example.com?subject=Hi'));
      expect(launched, isEmpty);
      expect(
        [for (final c in runner) (c.method, c.arguments)],
        [('openMail', 'mailto:me@example.com?subject=Hi')],
      );
      Future<String> why() async {
        try {
          await openInBrowser(Uri.parse('mailto:me@example.com'));
        } on BrowserError catch (e) {
          return e.message;
        }
        return 'opened';
      }

      error = PlatformException(code: 'no-mail-app');
      expect(
        await why(),
        'No default mail app is set: choose one in your system’s settings.',
      );
      error = PlatformException(code: 'failed', message: 'no thunderbird');
      expect(await why(), 'Couldn’t open your mail app: no thunderbird');
      error = MissingPluginException();
      expect(await why(), 'Couldn’t open your mail app.');
    });
  });
}
