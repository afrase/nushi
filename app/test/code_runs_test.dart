import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_text.dart';
import 'package:nushi/shell_marks.dart';
import 'package:nushi/terminals.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';

// A shell block's run: what it types, where its output starts and ends
// (fish's OSC 133 marks, as fish 4.9 sends them), and what goes to the
// composer.

const _fishPrompt = '\x1b]133;A;click_events=1\x1b\\> \x1b]133;B\x1b\\';

/// Lets the run's calls and the stream's messages through.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

typedef _Setup = (FakeShells, Terminals, CodeRuns);

_Setup _setup({String replay = _fishPrompt, String program = ''}) {
  final fake = FakeDaemon([]);
  final shells = FakeShells(
    fake,
    terminals: [
      Terminal(
        id: 'a',
        chatId: 'c',
        folder: '/Users/me/nushi',
        shell: 'fish',
        program: program,
      ),
    ],
  )..replay['a'] = replay;
  final terms = Terminals(NushiServiceClient(fake));
  final runs = CodeRuns('c', ValueNotifier(const []));
  addTearDown(shells.close);
  addTearDown(runs.dispose);
  return (shells, terms, runs);
}

void main() {
  group('what a block types', () {
    test('only a shell block, a prompt off the lines that have one', () {
      expect(runnableScript('bash', r'$ make check'), 'make check');
      expect(runnableScript('ZSH', '% ls\ncd app'), 'ls\ncd app');
      expect(runnableScript('python', 'print(1)'), isNull);
      expect(runnableScript('', 'ls'), isNull);
      expect(runnableScript('sh', r'echo $HOME'), r'echo $HOME');
    });

    test('none that hides a key or reorders what shows', () {
      for (final hidden in [
        '\r',
        '\x03',
        '\x15',
        '\x1b[2K',
        String.fromCharCode(0x202e),
      ]) {
        expect(runnableScript('bash', 'ls${hidden}rm -rf ~'), isNull);
      }
      expect(runnableScript('bash', 'printf "a\tb"\n'), 'printf "a\tb"');
    });

    test("a console block's lines without a prompt are output, left out", () {
      expect(
        runnableScript('console', '\$ go test ./...\nok  nushi 0.3s\n\$ ls'),
        'go test ./...\nls',
      );
      expect(runnableScript('console', 'just output'), isNull);
    });
  });

  test('marks cut between chunks, either end', () {
    final m = ShellMarks();
    final a = m.feed('out\x1b]13');
    expect(a.map((p) => p.text), ['out']);
    final b = m.feed('3;D;2\x1b');
    expect(b, isEmpty);
    final c = m.feed('\\next\x07');
    expect(c.first.mark, (kind: 'D', exit: 2));
    expect(c.last.text, 'next\x07');
    expect(m.seen, isTrue);
  });

  test('plain lines: escapes out, a rewritten line as written last', () {
    expect(plainLines('\x1b[1mbold\x1b[m\r\n10%\r50%\r100%\n\x1b]0;t\x07x'), [
      'bold',
      '100%',
      'x',
    ]);
  });

  test('kept output: the last 400 lines, saying how many are left out', () {
    final lines = [for (var i = 1; i <= 450; i++) 'line $i'];
    final kept = keptOutput(lines).split('\n');
    expect(kept.first, '… 50 earlier lines left out');
    expect(kept.length, 401);
    expect(kept.last, 'line 450');
    final wide = [for (var i = 0; i < 100; i++) 'x' * 1000];
    expect(keptOutput(wide).split('\n').first, '… 68 earlier lines left out');
  });

  test("outputs follow the message's text, fenced past their backticks", () {
    const o = (
      key: 'k',
      command: 'cat notes.md',
      exit: 1,
      lines: 2,
      text: '```\nquoted',
    );
    expect(
      withOutputs('Why?', [o]),
      'Why?\n\nOutput of `cat notes.md` (exit 1):\n\n````\n```\nquoted\n````',
    );
    expect(withOutputs('', [o]), startsWith('Output of'));
  });

  test('a run in the tab at its prompt: typed there, its output between '
      'C and D, then in the box', () async {
    final (shells, terms, runs) = _setup();
    terms.active['c'] = 'a';
    final run = runs.of(r'$ make check');
    await runs.start(terms, run, 'make check');
    expect(shells.typed['a'], ['make check\r']);
    expect(run.state, RunState.running);
    expect(run.busy(null), isTrue);

    shells
      ..write('a', 'make check\r\n') // the echo isn't output
      ..write('a', '\x1b]133;C\x1b\\\x1b[32mok\x1b[m  lint\r\n');
    await _settle();
    expect(run.lastLine, 'ok  lint');
    expect(runs.outputs.value, isEmpty, reason: 'nothing while it runs');

    shells.write('a', 'FAIL app\r\n\x1b]133;D;2\x1b\\$_fishPrompt');
    await _settle();
    expect(
      (run.state, run.exit, run.lastLine),
      (RunState.ended, 2, 'FAIL app'),
    );
    final out = runs.outputs.value.single;
    expect((out.command, out.exit, out.lines), ('make check', 2, 2));
    expect(out.text, 'ok  lint\nFAIL app');

    // Run again: its card goes at once, the new one comes at its end.
    await runs.start(terms, run, 'make check');
    expect(shells.typed['a'], hasLength(2));
    expect(runs.outputs.value, isEmpty);
    shells.runs('a', 'all good\r\n');
    await _settle();
    expect(runs.outputs.value.single.text, 'all good');
  });

  test(
    'stopped (its ✕, or ⌃C in the terminal): nothing goes in the box',
    () async {
      final (shells, terms, runs) = _setup();
      terms.active['c'] = 'a';
      final run = runs.of('npm run dev');
      await runs.start(terms, run, 'npm run dev');
      shells.write('a', '\x1b]133;C\x1b\\serving on :8000\r\n');
      await _settle();
      await runs.stop(terms, run);
      expect(shells.typed['a']!.last, '\x03');
      shells.write('a', '^C\x1b]133;D;130\x1b\\$_fishPrompt');
      await _settle();
      expect((run.state, run.exit), (RunState.stopped, 130));
      expect(run.lastLine, '^C', reason: 'as the terminal shows it');
      expect(runs.outputs.value, isEmpty);

      // ⌃C typed in the terminal is the same.
      await runs.start(terms, run, 'npm run dev');
      shells.runs('a', 'serving\r\n^C', exit: 130);
      await _settle();
      expect(run.state, RunState.stopped);
      expect(runs.outputs.value, isEmpty);
    },
  );

  test(
    'the tab busy: a new tab, not shown, typed into at its first prompt',
    () async {
      // The tab runs a command: its last mark is C.
      final (shells, terms, runs) = _setup(
        replay: '$_fishPrompt\x1b]133;C\x1b\\serving',
      );
      terms.active['c'] = 'a';
      final run = runs.of('curl localhost:8000');
      await runs.start(terms, run, 'curl localhost:8000');
      expect(shells.typed['a'], isNull);
      expect(run.terminalId, 'new0');
      expect(shells.typed['new0'], ['curl localhost:8000\r']);
      expect(terms.active['c'], 'a', reason: 'the panel shows what it showed');
      expect(terms.focusNext, isNull);
    },
  );

  test('a busy tab by its program, a shell without marks', () async {
    final (shells, terms, runs) = _setup(replay: r'$ ', program: 'vim');
    terms.active['c'] = 'a';
    shells.newReplay = '% ';
    final run = runs.of('ls');
    await runs.start(terms, run, 'ls');
    expect(run.terminalId, 'new0');
  });

  test('a shell without marks: output after the typed line, no end', () async {
    final (shells, terms, runs) = _setup(replay: r'$ ');
    terms.active['c'] = 'a';
    final run = runs.of('ls');
    await runs.start(terms, run, 'ls');
    expect(run.marked, isFalse);
    shells.write('a', 'ls\r\nREADME.md\r\napp\r\n');
    await _settle();
    expect(run.lastLine, 'app');
    expect(run.lines(), ['README.md', 'app']);
    expect(run.state, RunState.running);
    expect(runs.outputs.value, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    expect(run.busy(shells.list.first), isFalse, reason: 'no program runs');
  });

  test('lines typed as one paste, but into bash one by one', () async {
    final (shells, terms, runs) = _setup();
    terms.active['c'] = 'a';
    await runs.start(terms, runs.of('a'), 'cd app\nmake');
    expect(shells.typed['a'], ['\x1b[200~cd app\nmake\x1b[201~\r']);
    shells.runs('a', '');
    await _settle();
    await runs.start(terms, runs.of('t'), 'printf "a\tb"');
    expect(shells.typed['a']!.last, '\x1b[200~printf "a\tb"\x1b[201~\r');
    shells.list.first.shell = 'bash';
    shells.runs('a', '');
    await _settle();
    await runs.start(terms, runs.of('b'), 'cd app\nmake');
    expect(shells.typed['a']!.last, 'cd app\rmake\r');
  });
}
