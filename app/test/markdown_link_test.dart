import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  test('only web links open', () {
    expect(webLink('https://example.com/a'), isNotNull);
    expect(webLink('HTTP://example.com'), isNotNull);
    for (final href in [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'vscode://file/x',
      'mailto:a@example.com',
      'jira-attachment:10000',
      '/Users/x/a.png',
      'https:///nohost',
    ]) {
      expect(webLink(href), isNull, reason: href);
    }
  });

  // Security review 2026-11-04, L7: a link's text can name one address
  // and go to another; one click opened the other.
  test('a link whose text names another address', () {
    final evil = Uri.parse('https://evil.example/login');
    final gh = Uri.parse('https://github.com/org/repo/pull/12');
    expect(
      linkTextElsewhere('https://github.com/org/repo/pull/12', evil),
      'github.com',
    );
    expect(linkTextElsewhere('github.com/org/repo', evil), 'github.com');
    expect(linkTextElsewhere('www.github.com', evil), 'www.github.com');
    expect(linkTextElsewhere('https://github.com/org/repo/pull/12', gh), null);
    expect(linkTextElsewhere('www.github.com/org', gh), null);
    expect(linkTextElsewhere('the pull request', evil), null);
    expect(linkTextElsewhere('README.md', evil), null);
    expect(linkTextElsewhere('docs/setup.md', evil), null);
  });

  testWidgets('clicking one says where it goes first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: const Scaffold(
          body: AgentMarkdown(
            '[https://github.com/org/repo/pull/12](https://evil.example/login)',
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('github.com/org', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Open evil.example?'), findsOne);
    expect(
      find.text(
        'The link reads github.com, but it goes to '
        'https://evil.example/login.',
      ),
      findsOne,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Open evil.example?'), findsNothing);
  });
}
