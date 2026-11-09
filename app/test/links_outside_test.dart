import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart' show dataDir;
import 'package:nushi/markdown.dart' show openWeb;
import 'package:nushi/native.dart';
import 'package:nushi/terminal_find.dart' show openLink;
import 'package:nushi/web_page.dart' show openInBrowser;
import 'package:nushi/web_views.dart';
import 'package:nushi/web_views_linux.dart';

import 'outside_fixture.dart';

// The links a click opens outside a chat's own pages (Jira's, GitHub's, a
// terminal's, the agents' and an account's page) and mail: on the Mac
// through url_launcher, as always; on Linux through the runner's
// nushi/browser, whose launch leaves Nushi's variables out of the app it
// starts (ADR 0104).

/// What url_launcher was asked to open while the test runs: its default
/// platform's channel, as a test host has it (no app registers the Mac's).
List<String> _launched() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final urls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(channel, (c) async {
          if (c.method == 'launch') {
            urls.add((c.arguments as Map<Object?, Object?>)['url']! as String);
          }
          return true;
        });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return urls;
}

/// app.log's lines that say a link opened nothing.
List<String> _noLink() {
  final log = File('$dataDir/app.log');
  return log.existsSync()
      ? log
            .readAsLinesSync()
            .where((l) => l.contains('the browser opened no link'))
            .toList()
      : [];
}

/// Opens [url] each way a click outside a chat does: the shared call,
/// GitHub's and the update card's [openWeb], a terminal's Ctrl-click.
Future<void> _openEachWay(String url) async {
  await openInDefaultBrowser(Uri.parse(url));
  openWeb(url);
  await openLink(url, '/home/me', (_) async => false);
  // openWeb doesn't wait for its launch.
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('on the Mac a link opens with url_launcher, as it always did, and the '
      'runner hears nothing', () async {
    final launched = _launched();
    final runner = answerBrowser((_) => null);
    await _openEachWay('https://github.com/afrase/nushi/pull/7');
    expect(launched, List.filled(3, 'https://github.com/afrase/nushi/pull/7'));
    expect(runner, isEmpty);
  });

  group('on Linux', () {
    setUp(() => native.web = const LinuxWebViews());

    test('a link opens with the runner’s browser, never url_launcher; '
        'GitHub’s refuses what isn’t http(s)', () async {
      final launched = _launched();
      final runner = answerBrowser((_) => null);
      await _openEachWay('https://example.atlassian.net/browse/NU-1');
      openWeb('javascript:alert(1)');
      await Future<void>.delayed(Duration.zero);
      expect(launched, isEmpty);
      expect([
        for (final c in runner) (c.method, c.arguments),
      ], List.filled(3, ('open', 'https://example.atlassian.net/browse/NU-1')));
    });

    test('only http and https go to the browser; one that opens nothing is '
        'logged without the link, never thrown', () async {
      final runner = answerBrowser(
        (_) => throw PlatformException(code: 'no-browser'),
      );
      final before = _noLink().length;
      await openInDefaultBrowser(Uri.file('/home/me/run.sh'));
      await openInDefaultBrowser(Uri.parse('mailto:me@example.com'));
      expect(runner, isEmpty);
      await openInDefaultBrowser(Uri.parse('https://example.com/secret'));
      expect(runner, hasLength(1));
      final lines = _noLink().sublist(before);
      expect(lines, hasLength(3));
      expect(lines[0], contains('code=refused'));
      expect(lines[2], contains('code=no-browser'));
      expect(lines.join(), isNot(contains('example.com')));
      expect(lines.join(), isNot(contains('/home/me')));
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
