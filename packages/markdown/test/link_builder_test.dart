import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 13.5, height: 1.5),
  code: TextStyle(fontSize: 12.5),
  codeBackground: Colors.black12,
  codeRadius: 6,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _plain,
);

TextSpan? _plain(String language, String code, TextStyle style) => null;

void main() {
  testWidgets('a link builder draws the links it takes in the line; the '
      'rest stay linked text; none while streaming', (tester) async {
    final built = <String>[];
    final tapped = <String>[];
    Widget md({required bool streaming}) => MaterialApp(
      home: Scaffold(
        body: StreamingMarkdown(
          'See https://x.test/chip and [the docs](https://x.test/docs), '
          '`https://x.test/code` too.',
          style: _style,
          streaming: streaming,
          onTapLink: (href, _) => tapped.add(href),
          linkBuilder: (context, href, text, style) {
            built.add(text);
            return href.endsWith('chip')
                ? const SizedBox(key: Key('chip'), width: 40, height: 10)
                : null;
          },
        ),
      ),
    );
    await tester.pumpWidget(md(streaming: false));
    expect(find.byKey(const Key('chip')), findsOneWidget);
    expect(built, ['https://x.test/chip', 'the docs']);
    await tester.tapOnText(find.textRange.ofSubstring('the docs'));
    expect(tapped, ['https://x.test/docs']);
    built.clear();
    await tester.pumpWidget(md(streaming: true));
    expect(find.byKey(const Key('chip')), findsNothing);
    expect(built, isEmpty);
  });
}
