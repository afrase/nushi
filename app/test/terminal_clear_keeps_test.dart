import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart' show clearTerminalApi;
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/terminal_clear.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminal_session.dart';
import 'package:nushi/terminals.dart';
import 'package:xterm2/xterm.dart';

import 'fake_daemon.dart' show FakeDaemon;
import 'fake_shells.dart';
import 'harness.dart';

// A clear stays cleared when the app attaches again (issue #122): ⌘K tells
// the daemon the place in the terminal's output, and an attach whose
// replay says where it was clears there again, so the screen is what a
// live ⌘K left plus what came after.

const _cols = 20;
const _rows = 6;

/// The output before the clear: a marked prompt and a command, lines that
/// scroll, a wide character, a command line that wraps, and a pen set to
/// red that output after the clear still uses.
final List<int> _before = utf8.encode(
  '${FakeShells.prompt}ls\r\n'
  '${[for (var i = 1; i <= 20; i++) 'out $i\r\n'].join()}'
  '漢字 wide\r\n'
  '${FakeShells.prompt}echo a made-up line that wraps\r\n'
  'a made-up line that wraps\r\n'
  '\x1b[31m${FakeShells.prompt}make',
);

/// The output after it, in red until the pen is reset.
final List<int> _after = utf8.encode(
  '\r\nred text\r\n\x1b[0m${FakeShells.prompt}',
);

final List<int> _all = [..._before, ..._after];

/// An emulator of [cols] by [rows] that took [bytes] in live and was
/// cleared (⌘K) after the first [at] of them, or not at all when [at] is
/// null.
Terminal _live(List<int> bytes, int? at, {int cols = _cols, int rows = _rows}) {
  final t = Terminal(maxLines: 10000)..resize(cols, rows);
  final text = StringBuffer();
  // The same decoder as the app's, so a character split by the clear
  // comes out as the app's does. Dropped with the test.
  // ignore: close_sinks
  final decoder = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(StringConversionSink.fromStringSink(text));
  void feed(List<int> b) {
    decoder.add(b);
    t.write(text.toString());
    text.clear();
  }

  if (at == null) {
    feed(bytes);
  } else {
    feed(bytes.sublist(0, at));
    clearTerminal(t);
    feed(bytes.sublist(at));
  }
  return t;
}

/// Each row the emulator keeps, as text.
List<String> _text(Terminal t) => [
  for (final line in t.buffer.lines.toList()) line.getText().trimRight(),
];

/// What the emulator holds that shows or decides what shows next: every
/// cell with its colours and attributes (a prompt's mark among them), the
/// rows' wraps and marks, the cursor and its pen.
List<Object> _state(Terminal t) => [
  t.isUsingAltBuffer,
  t.buffer.scrollBack,
  (t.buffer.cursorX, t.buffer.cursorY),
  (t.cursor.foreground, t.cursor.background, t.cursor.attrs),
  for (final (i, l) in t.buffer.lines.toList().indexed)
    [
      l.isWrapped,
      t.isSemanticPromptLine(i),
      for (var x = 0; x < l.length; x++)
        (
          l.getCodePoint(x),
          l.getWidth(x),
          l.getForeground(x),
          l.getBackground(x),
          l.getAttributes(x),
        ),
    ],
];

/// That [got] holds what [want] does, line for line.
void _same(Terminal got, Terminal want) {
  expect(_text(got), _text(want));
  expect(_state(got), _state(want));
}

/// The foreground of the first cell of the row showing [text].
int _colorOf(Terminal t, String text) {
  final line = t.buffer.lines.toList().firstWhere(
    (l) => l.getText().startsWith(text),
  );
  return line.getForeground(0);
}

/// A session of terminal `a` attached to a fake daemon of API [api]
/// that kept [replay] from [replayAt] on, cleared at [cleared], and
/// writes [onAttach] next.
Future<(FakeDaemon, FakeShells, TermSession)> _attached(
  WidgetTester tester, {
  required List<int> replay,
  int replayAt = 0,
  int? cleared,
  List<int>? onAttach,
  int api = clearTerminalApi,
}) async {
  final fake = FakeDaemon([]);
  final shells =
      FakeShells(
          fake,
          terminals: [pb.Terminal(id: 'a', chatId: 'chat', shell: 'zsh')],
        )
        ..replay['a'] = utf8.decode(replay)
        ..replayAt['a'] = replayAt;
  if (cleared != null) shells.cleared['a'] = cleared;
  if (onAttach != null) shells.onAttach['a'] = utf8.decode(onAttach);
  final s = TermSession(NushiServiceClient(fake), 'a', 'chat', api: () => api);
  addTearDown(() async {
    s.dispose();
    await shells.close();
  });
  s.terminal.resize(_cols, _rows); // its view laid out: it attaches
  await tester.pump(const Duration(seconds: 1));
  return (fake, shells, s);
}

void main() {
  final red = _live(utf8.encode('\x1b[31mx'), null).buffer.lines[0];

  test('the output before and after the clear is as the tests need it', () {
    final t = _live(_all, _before.length);
    expect(_text(t).first, '> make', reason: 'the clear kept the prompt');
    expect(_colorOf(t, 'red text'), red.getForeground(0));
    expect(_text(_live(_all, null)), contains('out 20'));
  });

  group('an attach whose replay was cleared', () {
    final p = _before.length;
    final cases = <String, Map<String, Object>>{
      'in the middle of the first message': {'replay': _all, 'cleared': p},
      "exactly at the first message's end": {
        'replay': _before,
        'onAttach': _after,
        'cleared': p,
      },
      // Inside the prompt's escape sequence, which goes on in the next.
      'in a later message': {
        'replay': _before.sublist(0, p - 10),
        'onAttach': [..._before.sublist(p - 10), ..._after],
        'cleared': p,
      },
    };
    for (final MapEntry(key: name, value: c) in cases.entries) {
      testWidgets('clears again where it was: $name', (tester) async {
        final (_, _, s) = await _attached(
          tester,
          replay: c['replay']! as List<int>,
          cleared: c['cleared']! as int,
          onAttach: c['onAttach'] as List<int>?,
        );
        _same(s.terminal, _live(_all, p));
        expect(_colorOf(s.terminal, 'red text'), red.getForeground(0));
        expect(_text(s.terminal), isNot(contains('out 20')));
      });
    }

    testWidgets("clears at the replay's very end, before live output", (
      tester,
    ) async {
      final (_, shells, s) = await _attached(
        tester,
        replay: _before,
        cleared: p,
      );
      _same(s.terminal, _live(_before, p));
      shells.writeBytes('a', _after);
      await tester.pump();
      _same(s.terminal, _live(_all, p));
    });

    // The daemon no longer keeps the bytes before the clear: the clear is
    // at the replay's start.
    testWidgets('clears before its first byte when the clear is older than '
        'what the daemon keeps', (tester) async {
      final (_, _, s) = await _attached(
        tester,
        replay: _all,
        replayAt: 5000,
        cleared: 1000,
      );
      _same(s.terminal, _live(_all, 0));
    });
  });

  group('⌘K', () {
    testWidgets('sends the place after the last byte taken in, a character '
        'and an escape sequence split across messages, and an attach after '
        'it clears there again', (tester) async {
      final fake = FakeDaemon([]);
      final info = pb.Terminal(id: 'a', chatId: 'chat', shell: 'zsh');
      final replay = utf8.encode('${FakeShells.prompt}ls\r\nout\r\n');
      final shells = FakeShells(fake, terminals: [info])
        ..replay['a'] = utf8.decode(replay)
        ..replayAt['a'] = 300;
      final terms = Terminals(
        NushiServiceClient(fake),
        api: () => clearTerminalApi,
      );
      addTearDown(shells.close);
      await tester.pumpWidget(
        themed(
          TerminalPanel(
            chatId: 'chat',
            terms: terms,
            onHide: () {},
            showChange: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = terms.session(info);
      // An escape sequence ends in the next message, then a character
      // ends after the clear.
      final e = utf8.encode('é');
      final parts = [
        utf8.encode('more out\r\n\x1b[3'),
        [...utf8.encode('1mcaf'), e[0]],
        [e[1], ...utf8.encode(' done\r\n')],
      ];
      shells
        ..writeBytes('a', parts[0])
        ..writeBytes('a', parts[1]);
      await tester.pump();
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true);
      final at = replay.length + parts[0].length + parts[1].length;
      expect(
        [for (final c in shells.clears) (c.terminalId, c.at.toInt())],
        [('a', 300 + at)],
      );
      expect(shells.typedAll, isEmpty);
      shells.writeBytes('a', parts[2]);
      await tester.pump();
      final bytes = [...replay, ...parts.expand((p) => p)];
      Terminal live(int at) => _live(
        bytes,
        at,
        cols: s.terminal.viewWidth,
        rows: s.terminal.viewHeight,
      );

      _same(s.terminal, live(at));
      expect(_text(s.terminal).first, 'café done');

      // The app attaches again (a restart of it, a dropped stream): the
      // daemon replays all it kept, with the clear's place.
      shells.replay['a'] = utf8.decode(bytes);
      s.attach();
      await tester.pumpAndSettle();
      expect(identical(s.terminal, terms.session(info).terminal), isTrue);
      _same(s.terminal, live(at));
      await tester.pumpWidget(const SizedBox());
      terms.dispose();
    });

    testWidgets('a second ⌘K replaces the first, output between them', (
      tester,
    ) async {
      final (_, shells, s) = await _attached(tester, replay: _before);
      s.clear();
      shells.writeBytes('a', _after);
      await tester.pump();
      s.clear();
      expect(
        [for (final c in shells.clears) c.at.toInt()],
        [_before.length, _all.length],
      );
      expect(shells.cleared['a'], _all.length);
      shells.replay['a'] = utf8.decode(_all);
      s.attach();
      s.terminal.resize(_cols, _rows);
      await tester.pump(const Duration(seconds: 1));
      _same(s.terminal, _live(_all, _all.length));
    });

    testWidgets('the stream drops and attaches again: the clear stays', (
      tester,
    ) async {
      final (fake, shells, s) = await _attached(tester, replay: _before);
      s.clear();
      shells.writeBytes('a', _after);
      await tester.pump();
      _same(s.terminal, _live(_all, _before.length));
      shells.replay['a'] = utf8.decode(_all);
      fake.down = true;
      await tester.pump();
      fake.down = false;
      await tester.pump(const Duration(seconds: 2)); // past the retry's wait
      // A fresh emulator, which attaches once its view sizes it.
      s.terminal.resize(_cols, _rows);
      await tester.pump(const Duration(seconds: 1));
      expect(shells.attached('a'), isTrue);
      _same(s.terminal, _live(_all, _before.length));
    });

    testWidgets('after the stream ended and before it attaches again makes '
        "no call: its place was the old stream's", (tester) async {
      // The terminal may have restarted meanwhile (another client's doing):
      // a place counted in the old shell's output names nothing in the new.
      final (_, shells, s) = await _attached(tester, replay: _before);
      shells.drops('a');
      await tester.pump();
      s.clear();
      await tester.pump();
      expect(shells.clears, isEmpty);
      _same(s.terminal, _live(_before, _before.length));
      await tester.pump(const Duration(seconds: 2)); // past the retry's wait
    });

    testWidgets('in the alternate screen makes no call', (tester) async {
      final (_, shells, s) = await _attached(
        tester,
        replay: [..._before, ...utf8.encode('\x1b[?1049h~ vi')],
      );
      expect(s.terminal.isUsingAltBuffer, isTrue);
      s.clear();
      await tester.pump();
      expect(shells.clears, isEmpty);
    });

    testWidgets('a failed call shows nothing and the clear on screen stands', (
      tester,
    ) async {
      final (_, shells, s) = await _attached(tester, replay: _before);
      shells.list.clear(); // closed meanwhile: the daemon refuses it
      s.clear();
      await tester.pump();
      expect(shells.clears, isEmpty);
      _same(s.terminal, _live(_before, _before.length));
    });

    for (final api in [0, clearTerminalApi - 1]) {
      testWidgets('with a daemon of API $api makes no call, and a place in a '
          'replay is not used', (tester) async {
        final (_, shells, s) = await _attached(
          tester,
          replay: _all,
          cleared: _before.length,
          api: api,
        );
        _same(s.terminal, _live(_all, null));
        s.clear();
        await tester.pump();
        expect(shells.clears, isEmpty);
        expect(_text(s.terminal).first, isNot(contains('out')));
      });
    }
  });
}
