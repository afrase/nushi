import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/markdown.dart';

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
}
