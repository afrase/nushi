import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/terminals.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';

// A command typed after `!`: it runs in a terminal of its own, its card
// in the box from the start, filled with its exit and output when it
// ends; stopped, it's gone and sends nothing; its terminal closes unless
// the user opened it.
//
// The tags meet their text with no space between, as sent.
// ignore_for_file: missing_whitespace_between_adjacent_strings

typedef _Setup = (FakeShells, Terminals, CodeRuns, Draft);

_Setup _setup() {
  final fake = FakeDaemon([]);
  final shells = FakeShells(fake);
  final terms = Terminals(NushiServiceClient(fake));
  final draft = Draft();
  final runs = CodeRuns('c', draft.outputs);
  addTearDown(shells.close);
  addTearDown(runs.close);
  return (shells, terms, runs, draft);
}

/// Lets the calls and the stream's messages through.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'it runs in a terminal of its own, its card filled at its end',
    () async {
      final (shells, terms, runs, draft) = _setup();
      shells.commands['git status'] = (
        output: '\x1b[32mOn branch main\x1b[m\r\nclean\r\n',
        exit: 0,
      );
      final run = await runs.command(terms, 'git status');
      expect(shells.opened, ['git status']);
      expect(terms.focusNext, isNull, reason: 'not shown');
      await _settle();
      expect(run.state, RunState.ended);
      expect(run.exit, 0);
      final card = draft.outputs.value.single;
      expect(card.command, 'git status');
      expect(card.exit, 0);
      expect(card.lines, 2);
      expect(card.text, 'On branch main\nclean');
      expect(outputDone(card), isTrue);
      expect(shells.closed, [run.terminalId], reason: 'never opened: closed');
      expect(
        withOutputs('', draft.take().outputs),
        '<bash-input>git status</bash-input>\n'
        '<bash-stdout>On branch main\nclean</bash-stdout>'
        '<bash-stderr></bash-stderr><bash-exit-code>0</bash-exit-code>',
      );
    },
  );

  test(
    'its card shows while it runs, and stays for the message after',
    () async {
      final (shells, terms, runs, draft) = _setup();
      final pending = runs.command(terms, 'make check');
      expect(draft.outputs.value.single.run?.state, RunState.starting);
      final run = await pending;
      await _settle();
      expect(run.state, RunState.running);
      expect(draft.hasMessage, isFalse, reason: 'nothing to send yet');
      draft.text.text = 'meanwhile';
      final m = draft.take();
      expect(m.outputs, isEmpty);
      expect(draft.outputs.value.single.run, run, reason: 'still waiting');

      shells.write(run.terminalId, 'ok 1\r\nFAIL 2\r\n');
      await _settle();
      expect(run.lastLine, 'FAIL 2');
      shells.ends(run.terminalId, exit: 2);
      await _settle();
      expect(run.state, RunState.ended);
      final card = draft.outputs.value.single;
      expect((card.exit, card.text), (2, 'ok 1\nFAIL 2'));
      expect(draft.hasMessage, isTrue);
    },
  );

  test('a failed command is sent; one ended by ⌃C (130) is not', () async {
    final (shells, terms, runs, draft) = _setup();
    shells.commands['false'] = (output: '', exit: 1);
    shells.commands['sleep 9'] = (output: '^C\r\n', exit: 130);
    await runs.command(terms, 'false');
    final stopped = await runs.command(terms, 'sleep 9');
    await _settle();
    expect(stopped.state, RunState.stopped);
    expect(draft.outputs.value.single.command, 'false');
    expect(draft.outputs.value.single.exit, 1);
    expect(shells.closed, hasLength(2));
  });

  test(
    '✕ closes a terminal never shown and drops the card; nothing is sent',
    () async {
      final (shells, terms, runs, draft) = _setup();
      final run = await runs.command(terms, 'git log');
      await _settle();
      shells.write(run.terminalId, 'commit 1\r\n:');
      await _settle();
      await runs.stopCommand(terms, run);
      expect(shells.closed, [run.terminalId], reason: 'less ignores ⌃C');
      expect(shells.typed[run.terminalId], isNull);
      expect(run.state, RunState.stopped);
      expect(draft.outputs.value, isEmpty);
    },
  );

  test('✕ sends ⌃C to a terminal the user opened, which stays', () async {
    final (shells, terms, runs, draft) = _setup();
    final run = await runs.command(terms, 'npm run dev');
    run.shown = true;
    await _settle();
    shells.write(run.terminalId, 'listening on 3000\r\n');
    await _settle();
    await runs.stopCommand(terms, run);
    expect(shells.typed[run.terminalId], ['\x03']);
    expect(draft.outputs.value, isEmpty);
    shells.ends(run.terminalId, exit: 130);
    await _settle();
    expect(run.state, RunState.stopped);
    expect(draft.outputs.value, isEmpty);
    expect(shells.closed, isEmpty);
  });

  test('stopped before its terminal opened, it is closed once open', () async {
    final (shells, terms, runs, draft) = _setup();
    final pending = runs.command(terms, 'yes');
    final run = draft.outputs.value.single.run!;
    await runs.stopCommand(terms, run);
    expect(draft.outputs.value, isEmpty);
    await pending;
    await _settle();
    expect(shells.closed, [run.terminalId]);
    expect(run.state, RunState.stopped);
  });

  test('a terminal the user opened stays when it ends', () async {
    final (shells, terms, runs, draft) = _setup();
    final run = await runs.command(terms, 'make');
    run.shown = true;
    await _settle();
    shells.ends(run.terminalId);
    await _settle();
    expect(run.state, RunState.ended);
    expect(shells.closed, isEmpty);
    expect(draft.outputs.value.single.exit, 0);
  });

  test('its terminal gone before it ended: nothing to send', () async {
    final (shells, terms, runs, draft) = _setup();
    final run = await runs.command(terms, 'make');
    await _settle();
    await shells.close();
    await _settle();
    expect(run.state, RunState.left);
    expect(draft.outputs.value, isEmpty);
  });

  test(
    "a terminal that can't open: no card, the error to the caller",
    () async {
      final (shells, terms, runs, draft) = _setup();
      shells.fake.answer = (input) =>
          input is OpenTerminalRequest ? Future<Object>.error('old') : null;
      await expectLater(runs.command(terms, 'ls'), throwsA('old'));
      expect(draft.outputs.value, isEmpty);
    },
  );

  test('several run at once, each its own card, in order', () async {
    final (shells, terms, runs, draft) = _setup();
    shells
      ..commands['a'] = (output: 'A\r\n', exit: 0)
      ..commands['b'] = (output: 'B\r\n', exit: 0);
    final slow = await runs.command(terms, 'slow');
    await runs.command(terms, 'a');
    await runs.command(terms, 'b');
    await _settle();
    expect(
      [for (final o in draft.outputs.value) o.command],
      ['slow', 'a', 'b'],
    );
    expect(draft.take().outputs.map((o) => o.text), ['A', 'B']);
    expect(draft.outputs.value.single.run, slow);
  });

  test("a code block's ▷ never types into a command's terminal", () async {
    final (shells, terms, runs, draft) = _setup();
    final ssh = await runs.command(terms, 'ssh prod');
    await _settle();
    expect(terms.active['c'], ssh.terminalId, reason: 'the only terminal');
    final block = runs.of('rm -rf build');
    await runs.start(terms, block, 'rm -rf build');
    expect(block.terminalId, isNot(ssh.terminalId));
    expect(shells.typed[ssh.terminalId], isNull);
    expect(shells.typed[block.terminalId], ['rm -rf build\r']);
  });

  test('closing the chat stops following', () async {
    final (shells, terms, runs, draft) = _setup();
    final run = await runs.command(terms, 'make');
    await _settle();
    runs.close();
    shells.ends(run.terminalId);
    await _settle();
    expect(run.state, RunState.running);
    expect(draft.outputs.value.single.run, run);
  });
}
