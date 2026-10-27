import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/replies.dart';

void main() {
  test('a message with replies, and back', () {
    const replies = [
      (quote: 'line one\nline two', text: 'why?'),
      (quote: 'just this', text: ''),
    ];
    final message = withReplies(replies, 'and the rest');
    expect(
      message,
      '<!-- reply 1 -->\n> line one\n> line two\n\nwhy?\n\n'
      '<!-- reply 2 -->\n> just this\n\nand the rest',
    );
    // A reply without text followed by text reads as that reply's text;
    // they show the same.
    var (got, rest) = splitReplies(withReplies(replies, ''));
    expect(got, replies);
    expect(rest, '');
    (got, rest) = splitReplies(withReplies(replies.sublist(0, 1), 'a\n\nb'));
    expect(got, replies.sublist(0, 1));
    expect(rest, 'a\n\nb');
    (got, rest) = splitReplies('> a plain quote');
    expect(got, isEmpty);
    expect(rest, '> a plain quote');
  });

  test('a reply with lines, and with a blank line, comes back whole', () {
    const lines = (
      quote: 'kept as a DateTime',
      text: 'Why?\nAnd why not a string?',
    );
    var message = withReplies([lines], 'the rest');
    expect(message, isNot(contains('end of replies')));
    var (got, rest) = splitReplies(message);
    expect(got, [lines]);
    expect(rest, 'the rest');

    const paragraphs = (
      quote: 'kept as a DateTime',
      text: 'Why?\n\nAnd why not?',
    );
    for (final text in ['the rest', '']) {
      message = withReplies([lines, paragraphs], text);
      expect(
        message,
        '<!-- reply 1 -->\n> kept as a DateTime\n\nWhy?\nAnd why not a string?'
        '\n\n<!-- reply 2 -->\n> kept as a DateTime\n\nWhy?\n\nAnd why not?'
        '\n\n<!-- end of replies -->${text.isEmpty ? '' : '\n\n$text'}',
      );
      (got, rest) = splitReplies(message);
      expect(got, [lines, paragraphs]);
      expect(rest, text);
    }
  });
}
