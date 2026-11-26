import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/terminal_clear.dart';
import 'package:nushi/terminal_panel.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/theme/tokens.dart';
import 'package:xterm2/xterm.dart';

import 'fake_daemon.dart' show FakeDaemon, loadFonts;
import 'fake_shells.dart';
import 'harness.dart';

/// A terminal of [cols] by [rows] that has shown [output].
Terminal _shown(int cols, int rows, String output) => Terminal()
  ..resize(cols, rows)
  ..write(output);

/// Every row the terminal keeps, the scrollback's first, as text.
List<String> _rows(Terminal t) => [
  for (final line in t.buffer.lines.toList()) line.getText().trimRight(),
];

/// [n] lines of made-up output, each ending its line.
String _output(int n) => [for (var i = 1; i <= n; i++) 'out $i\r\n'].join();

/// [kept] on the first rows of a screen [rows] tall, blank below.
List<String> _top(List<String> kept, int rows) => [
  ...kept,
  for (var i = kept.length; i < rows; i++) '',
];

void main() {
  setUpAll(loadFonts);

  // Terminal and iTerm keep the line being typed on (the prompt) and put it
  // on the first row, as a new session has it; xterm2's clear puts it at
  // the bottom (docs/development.md's Dependencies).
  test('a one-line prompt goes to the first row, the cursor where it was, '
      'the scrollback empty', () {
    final t = _shown(20, 5, '${_output(30)}~/veg \$ ');
    expect(t.buffer.scrollBack, greaterThan(0));
    clearTerminal(t);
    expect(_rows(t), _top([r'~/veg $'], 5));
    expect(t.buffer.scrollBack, 0);
    expect((t.buffer.cursorX, t.buffer.cursorY), (8, 0));
  });

  test('a line wrapped over three rows keeps its three rows at the top', () {
    final t = _shown(10, 6, '${_output(20)}\$ echo 0123456789abcdefghi');
    clearTerminal(t);
    expect(_rows(t), _top([r'$ echo 012', '3456789abc', 'defghi'], 6));
    expect(t.buffer.lines[1].isWrapped, isTrue);
    expect(t.buffer.scrollBack, 0);
    expect((t.buffer.cursorX, t.buffer.cursorY), (6, 2));
  });

  // The package's clear keeps a wrapped line only up to the cursor's row;
  // the shell still holds the rest of the command and won't redraw it.
  test('a line wrapped over two rows, the cursor on its first, keeps both', () {
    final t = _shown(10, 4, '${_output(9)}\$ echo 0123456789\x1b[A');
    expect(t.buffer.cursorY, 2, reason: 'the cursor moved up into it');
    clearTerminal(t);
    expect(_rows(t), _top([r'$ echo 012', '3456789'], 4));
    expect(t.buffer.lines[1].isWrapped, isTrue);
    expect(t.buffer.scrollBack, 0);
    expect((t.buffer.cursorX, t.buffer.cursorY), (7, 0));
  });

  test('a line wrapped over three rows, the cursor on its middle row, '
      'keeps all three', () {
    final t = _shown(10, 6, '${_output(20)}\$ echo 0123456789abcdefghi\x1b[A');
    expect(t.buffer.cursorY, 4, reason: 'the cursor moved up into it');
    clearTerminal(t);
    expect(_rows(t), _top([r'$ echo 012', '3456789abc', 'defghi'], 6));
    expect(t.buffer.lines[1].isWrapped, isTrue);
    expect(t.buffer.lines[2].isWrapped, isTrue);
    expect(t.buffer.lines[3].isWrapped, isFalse);
    expect(t.buffer.scrollBack, 0);
    expect((t.buffer.cursorX, t.buffer.cursorY), (6, 1));
  });

  // The package keeps only the rows on the screen; counting the ones in
  // the scrollback too would leave the kept rows at the bottom.
  test('a line wrapped from the scrollback keeps only its rows on the screen, '
      'from the first row', () {
    const command = r'$ echo abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJ';
    final t = _shown(10, 5, '${_output(5)}$command\x1b[2A');
    expect(t.buffer.lines[t.buffer.scrollBack].isWrapped, isTrue);
    expect((t.buffer.cursorX, t.buffer.cursorY), (3, 2));
    clearTerminal(t);
    expect(_rows(t), [
      'defghijklm',
      'nopqrstuvw',
      'xyz0123456',
      '789ABCDEFG',
      'HIJ',
    ]);
    expect(t.buffer.scrollBack, 0);
    expect((t.buffer.cursorX, t.buffer.cursorY), (3, 2));
  });

  // clearTerminal moves what the package's own clear left at the bottom.
  test("the package's own clear still leaves the cursor on the last row", () {
    final t = _shown(20, 5, '${_output(30)}~/veg \$ ')..clear();
    expect(
      t.buffer.cursorY,
      t.viewHeight - 1,
      reason:
          'the package now puts the kept line at the top itself, '
          'delete the move in clearTerminal',
    );
  });

  test('the cursor in the middle of a typed command stays at its column', () {
    final t = _shown(30, 5, '${_output(12)}\$ make lettuce\x1b[7D');
    clearTerminal(t);
    expect(_rows(t), _top([r'$ make lettuce'], 5));
    expect((t.buffer.cursorX, t.buffer.cursorY), (7, 0));
  });

  test('a prompt its shell marks stays a marked prompt, on the first row', () {
    const prompt = '\x1b]133;A\x1b\\> \x1b]133;B\x1b\\';
    final t = _shown(20, 5, '$prompt${_output(10)}${prompt}ls');
    clearTerminal(t);
    expect(_rows(t), _top(['> ls'], 5));
    expect(t.isSemanticPromptLine(0), isTrue);
    expect(t.semanticPromptLineBefore(0), isNull, reason: 'older ones went');
    expect((t.buffer.cursorX, t.buffer.cursorY), (4, 0));
  });

  test('a full-screen program on the alternate screen is left alone', () {
    final t = _shown(
      20,
      5,
      '${_output(8)}\$ vi\r\n'
      '\x1b[?1049h\x1b[H~ one\r\n~ two\r\n~ three\x1b[2;3H',
    );
    expect(t.isUsingAltBuffer, isTrue);
    final main = [
      for (final line in t.mainBuffer.lines.toList())
        line.getText().trimRight(),
    ];
    expect(t.mainBuffer.scrollBack, greaterThan(0));
    clearTerminal(t);
    expect(_rows(t), ['~ one', '~ two', '~ three', '', '']);
    expect((t.buffer.cursorX, t.buffer.cursorY), (2, 1));
    t.write('\x1b[?1049l');
    expect(_rows(t), main, reason: "the shell's screen kept, scrollback too");
  });

  test(
    'output arriving after the clear continues the kept line at the top',
    () {
      final t = _shown(20, 5, '${_output(10)}\$ make\r\nbuilding 1\r\nbuild');
      clearTerminal(t);
      t.write('ing 2\r\ndone\r\n');
      expect(_rows(t), _top(['building 2', 'done'], 5));
      expect((t.buffer.cursorX, t.buffer.cursorY), (0, 2));
    },
  );

  test('a terminal one row tall keeps its one row', () {
    final t = _shown(20, 1, '${_output(3)}\$ ');
    clearTerminal(t);
    expect(_rows(t), [r'$']);
    expect((t.buffer.cursorX, t.buffer.cursorY), (2, 0));
  });

  test('after the clear, output fills down from the top and then scrolls, '
      'the scrollback in order', () {
    final t = _shown(20, 5, '${_output(40)}\$ ');
    clearTerminal(t);
    final lines = [for (var i = 1; i <= 200; i++) 'line $i'];
    t.write('\r\n${lines.take(4).join('\r\n')}');
    expect(_rows(t), [r'$', ...lines.take(4)], reason: 'the first screenful');
    expect(t.buffer.scrollBack, 0);
    t.write('\r\n${lines.skip(4).join('\r\n')}');
    expect(_rows(t), [r'$', ...lines]);
    expect(t.buffer.scrollBack, 196);
    expect((t.buffer.cursorX, t.buffer.cursorY), (8, 4));
  });

  group('⌘K in the terminal panel', () {
    Future<(FakeShells, TermSession)> open(
      WidgetTester tester, {
      Tokens tokens = Tokens.dark,
      String? replay,
    }) async {
      final fake = FakeDaemon([]);
      final info = pb.Terminal(
        id: 'a',
        chatId: 'chat',
        folder: '/tmp/veg',
        shell: 'zsh',
      );
      final shells = FakeShells(fake, terminals: [info])
        ..replay['a'] = replay ?? '${_output(80)}~/veg \$ ls';
      final terms = Terminals(NushiServiceClient(fake));
      await tester.pumpWidget(
        themed(
          TerminalPanel(
            chatId: 'chat',
            terms: terms,
            onHide: () {},
            showChange: (_) async => false,
          ),
          tokens: tokens,
        ),
      );
      await tester.pumpAndSettle();
      return (shells, terms.session(info));
    }

    testWidgets('puts the prompt on the first row and sends the shell '
        'nothing, from the view scrolled up', (tester) async {
      final (shells, s) = await open(tester);
      final t = s.terminal;
      expect(t.buffer.scrollBack, greaterThan(0));
      s.scroll.jumpTo(0); // up in the scrollback
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true);
      expect(_rows(t), _top([r'~/veg $ ls'], t.viewHeight));
      expect(t.buffer.scrollBack, 0);
      expect((t.buffer.cursorX, t.buffer.cursorY), (10, 0));
      expect(s.scroll.position.maxScrollExtent, 0);
      expect(s.scroll.offset, 0, reason: 'at the top, nothing left above');
      expect(shells.typedAll, isEmpty, reason: 'the terminal’s own action');
    });

    // The input method's caret (and its candidate window) follows the
    // cursor only when the view hears of a change; with no scrollback the
    // view does not scroll on ⌘K, so nothing else would move it.
    testWidgets("puts the input method's caret on the first row at once, "
        'with no scrollback and on a second ⌘K', (tester) async {
      final (_, s) = await open(tester, replay: '${_output(3)}~/veg \$ ls');
      final t = s.terminal;
      expect(t.buffer.scrollBack, 0);
      s.focus.requestFocus();
      await tester.pumpAndSettle();
      Rect caret() {
        final call = tester.testTextInput.log.lastWhere(
          (c) => c.method == 'TextInput.setCaretRect',
        );
        final a = (call.arguments as Map).cast<String, num>();
        return Rect.fromLTWH(
          a['x']!.toDouble(),
          a['y']!.toDouble(),
          a['width']!.toDouble(),
          a['height']!.toDouble(),
        );
      }

      for (final row in [3, 2]) {
        t.write(row == 3 ? '' : '\r\nout\r\n~/veg \$ ls');
        await tester.pumpAndSettle();
        expect(t.buffer.cursorY, row);
        final before = caret();
        await press(tester, LogicalKeyboardKey.keyK, cmd: true);
        expect(t.buffer.cursorY, 0);
        expect(t.buffer.scrollBack, 0);
        expect(
          caret().top,
          moreOrLessEquals(before.top - row * before.height),
          reason: 'the caret on the first row after ⌘K from row $row',
        );
      }
    });

    testWidgets("drops find's hits", (tester) async {
      final (shells, s) = await open(tester);
      await press(tester, LogicalKeyboardKey.keyF, cmd: true, settle: false);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'out');
      await tester.pump();
      expect(s.controller.searchHighlights, isNotEmpty);
      s.focus.requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyK, cmd: true);
      expect(
        s.controller.searchHighlights.map((h) => h.rangeFor(s.terminal.buffer)),
        everyElement(isNull),
      );
      expect(_rows(s.terminal).first, r'~/veg $ ls');
      expect(shells.typedAll, isEmpty);
    });

    renderTest('renders after ⌘K', (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(const SizedBox());
        viewport(tester, const Size(1700, 500), brightness: b);
        final (_, s) = await open(
          tester,
          tokens: b == Brightness.light ? Tokens.light : Tokens.dark,
        );
        s.focus.requestFocus();
        await tester.pump();
        await press(tester, LogicalKeyboardKey.keyK, cmd: true);
        s.terminal.write('\r\nmade-up output after the clear\r\n~/veg \$ ');
        for (final w in [1700.0, 720.0]) {
          viewport(tester, Size(w, 500), brightness: b);
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(TerminalPanel),
            'terminal_clear_${w.toInt()}_${b.name}',
          );
        }
      }
    });
  });
}
