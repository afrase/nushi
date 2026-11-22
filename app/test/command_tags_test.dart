import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' show Item;
import 'package:nushi/replies.dart';
import 'package:nushi/rewind_picker.dart';
import 'package:nushi/run_text.dart';

// The tags meet their text with no space between, as sent.
// ignore_for_file: missing_whitespace_between_adjacent_strings

// A command and its output as they go to the agent (bare tags, Claude
// Code's own for a `!` command) and as a sent message reads back.

RunOutput _o(String command, String text, {int exit = 0}) =>
    (key: command, command: command, exit: exit, lines: 1, text: text);

/// [splitCommands]'s answer as a list, which a matcher compares item by
/// item (a record holding a list is equal only to itself).
List<Object?> _split(String m) {
  final (rest, commands) = splitCommands(m);
  return [rest, ...commands];
}

/// An output's end, as written, with an exit of its own.
const _tail =
    '</bash-stdout><bash-stderr></bash-stderr>'
    '<bash-exit-code>3</bash-exit-code>';

SentCommand _c(String command, String? output, int? exit) =>
    (command: command, output: output, exit: exit);

void main() {
  test('a command goes as its tags, nothing else', () {
    expect(
      commandTags('git status', 'On branch main', 0),
      '<bash-input>git status</bash-input>\n'
      '<bash-stdout>On branch main</bash-stdout><bash-stderr></bash-stderr>'
      '<bash-exit-code>0</bash-exit-code>',
    );
  });

  test('what was written reads back: the text, then each command', () {
    final outputs = [
      _o('git status', 'On branch main\nnothing to commit'),
      _o('make check', '', exit: 2),
      _o('sleep 9', '^C', exit: 130),
    ];
    final message = withOutputs('Why does it fail?', outputs);
    final (rest, commands) = splitCommands(message);
    expect(rest, 'Why does it fail?');
    expect(commands, [
      (
        command: 'git status',
        output: 'On branch main\nnothing to commit',
        exit: 0,
      ),
      (command: 'make check', output: '', exit: 2),
      (command: 'sleep 9', output: '^C', exit: 130),
    ]);
    expect(splitCommands(withOutputs('', outputs.sublist(0, 1))).$1, '');
  });

  test('replies, text and commands all read back', () {
    final message = withOutputs(
      withReplies([(quote: 'a line', text: 'this?', from: '')], 'And this'),
      [_o('ls', 'a\nb')],
    );
    final (body, commands) = splitCommands(message);
    expect(commands.single.command, 'ls');
    final (replies, rest) = splitReplies(body);
    expect(replies.single.quote, 'a line');
    expect(rest, 'And this');
  });

  test('an output holding the tags stays one output', () {
    const inner =
        '<bash-input>echo hi</bash-input>\n'
        '<bash-stdout>hi</bash-stdout><bash-stderr></bash-stderr>'
        '<bash-exit-code>0</bash-exit-code>';
    for (final output in [
      inner,
      'before\n\n$inner\n\nafter',
      'x${_tail}y',
      'x$_tail\n\n<bash-input>z',
      '</bash-input>\n<bash-stdout>',
    ]) {
      final outputs = [_o('cat log', output, exit: 1), _o('pwd', '/tmp')];
      final (rest, commands) = splitCommands(withOutputs('Look', outputs));
      expect(rest, 'Look', reason: output);
      expect(commands, [
        (command: 'cat log', output: output, exit: 1),
        (command: 'pwd', output: '/tmp', exit: 0),
      ], reason: output);
    }
  });

  test("Claude Code's own two messages of a `!` each read back", () {
    expect(_split('<bash-input>git status</bash-input>'), [
      '',
      _c('git status', null, null),
    ]);
    expect(
      _split(
        '<bash-stdout>On branch main</bash-stdout>'
        '<bash-stderr>warning: x</bash-stderr>',
      ),
      ['', _c('', 'On branch main\nwarning: x', null)],
    );
    expect(_split('<bash-stdout></bash-stdout><bash-stderr></bash-stderr>'), [
      '',
      _c('', '', null),
    ]);
  });

  test('a message without them, or with them not at its end, is as it '
      'was', () {
    for (final m in [
      'Why?\n\nOutput of `ls` (exit 0):\n\n```\na\n```',
      'What does <bash-input>ls</bash-input> mean?',
      '<bash-input>ls</bash-input>\n\nand then?',
      '<bash-input>ls</bash-input> is what I typed',
      'see<bash-input>ls</bash-input>',
      '',
    ]) {
      expect(_split(m), [m], reason: m);
    }
  });

  test("a message's one line, in the rewind list, is its command's", () {
    expect(
      rewindLine(Item(text: withOutputs('', [_o('git status', 'clean')]))),
      '! git status',
    );
    expect(
      rewindLine(Item(text: withOutputs('Why?', [_o('ls', 'a')]))),
      'Why?',
    );
  });

  test('a message taken back gives back its cards', () {
    final message = withOutputs('Hi', [_o('ls', 'a\nb', exit: 1)]);
    final cards = sentOutputs(splitCommands(message).$2);
    expect(cards, [
      (key: 'ls', command: 'ls', exit: 1, lines: 2, text: 'a\nb'),
    ]);
    expect(withOutputs('Hi', cards), message);
  });
}
