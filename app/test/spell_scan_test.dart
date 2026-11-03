import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/spell_scan.dart';

List<String> _words(String text) => [for (final w in scanWords(text)) w.word];

void main() {
  test('plain words come with where they are', () {
    expect(scanWords('the qick fox'), [
      (start: 0, end: 3, word: 'the'),
      (start: 4, end: 8, word: 'qick'),
      (start: 9, end: 12, word: 'fox'),
    ]);
  });

  test('punctuation around a word stays out of it', () {
    expect(scanWords('(qick), "brwn"!'), [
      (start: 1, end: 5, word: 'qick'),
      (start: 9, end: 13, word: 'brwn'),
    ]);
    expect(_words("it's the dogs' bone"), ["it's", 'the', 'dogs', 'bone']);
    expect(_words('don’t stop'), ['don’t', 'stop']);
  });

  group('skipped, never flagged', () {
    for (final (name, text) in [
      ('inline code', 'run `chekc` now'),
      ('inline code with spaces', 'run `chekc thrid` now'),
      ('an unclosed backtick', 'run `chekc'),
      ('a fence', 'see\n```\nchekc thrid\n```\nend'),
      ('an unclosed fence', '```\nchekc thrid'),
      ('a relative path', 'app/lib/composer.dart'),
      ('an absolute path', '/usr/local/thrid'),
      ('a home path', '~/thrid'),
      ('a URL', 'https://example.com/chekc'),
      ('another scheme', 'ssh://chekc'),
      ('a slash start', '/chekc'),
      ('an at start', '@chekc'),
      ('a hash start', '#chekc'),
      ('a tilde start', '~chekc'),
      ('a dollar start', r'$chekc'),
      ('a dash start', '-chekc'),
      ('two dashes', '--chekc'),
      ('digits inside', 'che2kc'),
      ('digits at the end', 'chekc42'),
      ('digits at the start', '2chekc'),
      ('a dot inside', 'chekc.thrid'),
      ('an underscore inside', 'chekc_thrid'),
      ('a colon inside', 'chekc:thrid'),
      ('a slash inside', 'chekc/thrid'),
      ('camelCase', 'chekcThrid'),
      ('PascalCase mid-word', 'ChekcThrid'),
      ('ALLCAPS', 'CHEKC'),
      ('two letters', 'qz'),
      ('one letter', 'q'),
      ('a capital mid-sentence', 'ask Chekc about it'),
      ('a capital after a comma', 'yes, Chekc said so'),
    ]) {
      test(name, () {
        final skipped = {'chekc', 'thrid', 'Chekc', 'CHEKC', 'qz', 'q'};
        expect(_words(text).where(skipped.contains), isEmpty, reason: text);
      });
    }
  });

  group('a capital starts a sentence', () {
    for (final text in [
      'Chekc this',
      '  Chekc this',
      'Done. Chekc this',
      'Done! Chekc this',
      'Done? Chekc this',
      'Note: Chekc this',
      'Done\nChekc this',
    ]) {
      test(text, () => expect(_words(text), contains('Chekc')));
    }
  });

  test('a hyphenated word is checked part by part', () {
    expect(scanWords('well-knwon'), [
      (start: 0, end: 4, word: 'well'),
      (start: 5, end: 10, word: 'knwon'),
    ]);
    expect(_words('a-b-cat'), ['cat']); // the short parts aren't checked
  });

  test('code stops being skipped where it closes', () {
    expect(_words('`one` qick `two` brwn'), ['qick', 'brwn']);
    expect(_words('```\nnot this\n``` qick'), ['qick']);
  });

  test('sentenceStart looks back past spaces and tabs only', () {
    expect(sentenceStart('Word', 0), isTrue);
    expect(sentenceStart(' \tWord', 2), isTrue);
    expect(sentenceStart('end. Word', 5), isTrue);
    expect(sentenceStart('and Word', 4), isFalse);
    expect(sentenceStart('"Word', 1), isFalse);
  });

  test('known words lose their case and curly apostrophes', () {
    expect(knownForm('Don’t'), "don't");
    expect(wordsOf(['The nushid daemon', 'Don’t 42 stop']), {
      'the',
      'nushid',
      'daemon',
      "don't",
      'stop',
    });
  });

  test('a suggestion keeps the shape of the word it replaces', () {
    expect(inShapeOf('Chekc', 'check'), 'Check');
    expect(inShapeOf('chekc', 'check'), 'check');
    expect(inShapeOf('chekc', 'Czech'), 'Czech');
  });
}
