import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/replies.dart';

void main() {
  test('a message with replies, and back', () {
    const replies = [
      (quote: 'line one\nline two', text: 'why?', from: ''),
      (quote: 'just this', text: '', from: ''),
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
      from: '',
    );
    var message = withReplies([lines], 'the rest');
    expect(message, isNot(contains('end of replies')));
    var (got, rest) = splitReplies(message);
    expect(got, [lines]);
    expect(rest, 'the rest');

    const paragraphs = (
      quote: 'kept as a DateTime',
      text: 'Why?\n\nAnd why not?',
      from: '',
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

  // Whose the quoted text is: one lead line per group (the coordinator's
  // case: Claude took the user's own review comments for a reviewer's).
  test("a group's lead line once before it, and back to its first reply", () {
    const mine = 'My review comments on your changes:';
    const theirs =
        'Review comments from @octo on PR a/b#1 (GitHub), my pull '
        'request:';
    const replies = [
      (quote: 'a.go, line 1', text: 'Rename it.', from: mine),
      (quote: 'a.go, line 2', text: 'Drop it.', from: mine),
      (quote: 'Overflow?', text: 'Address it.', from: theirs),
      (quote: 'selected text', text: 'why?', from: ''),
    ];
    final message = withReplies(replies, 'Thanks.');
    expect(
      message,
      '<!-- from -->\n$mine\n\n'
      '<!-- reply 1 -->\n> a.go, line 1\n\nRename it.\n\n'
      '<!-- reply 2 -->\n> a.go, line 2\n\nDrop it.\n\n'
      '<!-- from -->\n$theirs\n\n'
      '<!-- reply 3 -->\n> Overflow?\n\nAddress it.\n\n'
      '<!-- reply 4 -->\n> selected text\n\nwhy?\n\nThanks.',
    );
    final (got, rest) = splitReplies(message);
    expect(rest, 'Thanks.');
    expect([for (final r in got) r.from], [mine, '', theirs, '']);
    expect(
      [for (final r in got) r.text],
      ['Rename it.', 'Drop it.', 'Address it.', 'why?'],
    );
    // Sent again as parsed, the leads are the same.
    expect(withReplies(got, 'Thanks.'), message);
  });

  test('a lead with a newline in it (a name from GitHub) stays one line, '
      'and the replies come back', () {
    const replies = [
      (
        quote: 'Check CI / lint\nfast: failure',
        text: 'Fix it.',
        from: 'Failed checks on PR a/b#1\n(GitHub):',
      ),
    ];
    final message = withReplies(replies, 'Thanks.');
    expect(
      message,
      startsWith('<!-- from -->\nFailed checks on PR a/b#1 (GitHub):\n\n'),
    );
    final (got, rest) = splitReplies(message);
    expect(rest, 'Thanks.');
    expect(got.single.from, 'Failed checks on PR a/b#1 (GitHub):');
    expect(got.single.quote, 'Check CI / lint\nfast: failure');
    expect(got.single.text, 'Fix it.');
  });
}
