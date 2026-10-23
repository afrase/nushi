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
}
