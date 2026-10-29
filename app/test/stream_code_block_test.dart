import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';

/// 300 lines of Python, as an agent writes a file out for copying.
String _code() {
  final out = StringBuffer();
  for (var i = 0; out.toString().split('\n').length <= 300; i++) {
    out
      ..write('def shard_$i(files, count=2):\n')
      ..write('    """Split the files into $i even shards."""\n')
      ..write('    out = [[] for _ in range(count)]  # one list each\n')
      ..write('    for n, f in enumerate(sorted(files)):\n')
      ..write("        out[n % count].append(f'{f}.test')\n")
      ..write('    return out\n')
      ..write('\n');
  }
  return out.toString().split('\n').take(300).join('\n');
}

/// Its chunks as they stream: mostly 5 to 40 characters, some 90 to 180.
List<int> _chunkEnds(int from, int length) {
  final r = Random(3);
  final ends = <int>[];
  var at = from;
  while (at < length) {
    at = min(
      length,
      at + (r.nextInt(7) == 0 ? 90 + r.nextInt(90) : 5 + r.nextInt(36)),
    );
    ends.add(at);
  }
  return ends;
}

/// A 300-line fenced block streaming in, a chunk every two frames: the
/// code shows as fast as it comes (no pacing in a fence), and how long
/// each chunk takes to build, lay out and paint. The times print with
/// `flutter test --dart-define=MARKDOWN_BENCH=true
/// test/stream_code_block_test.dart`.
void main() {
  setUpAll(loadFonts);

  testWidgets('a 300-line code block streams in as fast as it comes', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..busy = true
      ..items.add(
        Item(id: 'u', kind: ItemKind.ITEM_KIND_USER_MESSAGE, text: 'Go'),
      );
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: chat,
            builder: (context, _) =>
                Transcript(chat: chat, daemon: d, onReply: null),
          ),
        ),
      ),
    );
    void stream(String text) {
      final it = Item(
        id: 'm',
        kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
        text: text,
      );
      final i = chat.items.indexWhere((x) => x.id == 'm');
      if (i < 0) {
        chat.items.add(it);
      } else {
        chat.items[i] = it;
      }
      chat.notifyListeners();
    }

    String? shownCode() => tester
        .widgetList<CodeBlockView>(find.byType(CodeBlockView))
        .firstOrNull
        ?.code;

    // The code block's text as drawn, its paragraphs' lines joined, and
    // each character's color.
    (String, List<Color?>) drawn() {
      final text = StringBuffer();
      final colors = <Color?>[];
      void visit(InlineSpan s, Color? color) {
        if (s is! TextSpan) return;
        final c = s.style?.color ?? color;
        text.write(s.text ?? '');
        colors.addAll(List.filled(s.text?.length ?? 0, c));
        for (final child in s.children ?? const <InlineSpan>[]) {
          visit(child, c);
        }
      }

      final paragraphs = find.descendant(
        of: find.descendant(
          of: find.byType(CodeBlockView),
          matching: find.byType(SingleChildScrollView),
        ),
        matching: find.byType(RichText),
      );
      for (final (i, r) in tester.widgetList<RichText>(paragraphs).indexed) {
        if (i > 0) {
          text.write('\n');
          colors.add(null);
        }
        visit(r.text, null);
      }
      return (text.toString(), colors);
    }

    final code = _code();
    const intro = 'Here is the file:\n\n```python\n';
    final text = '$intro$code\n```\n\nCopy it into `shards.py`.';
    // The intro shows first, paced as prose.
    stream(intro);
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final times = <double>[];
    final behind = <int>[]; // characters of code not shown a frame on
    final clock = Stopwatch();
    final ends = _chunkEnds(intro.length, intro.length + code.length);
    for (final end in ends) {
      final s = text.substring(0, end);
      clock
        ..reset()
        ..start();
      stream(s);
      await tester.pump(const Duration(milliseconds: 16));
      final shown = shownCode() ?? '';
      await tester.pump(const Duration(milliseconds: 16));
      times.add(clock.elapsedMicroseconds / 1000);
      var got = s.substring(intro.length);
      if (got.endsWith('\n')) got = got.substring(0, got.length - 1);
      behind.add(got.length - shown.length);
    }
    // Drawn in groups of lines, highlighted a run at a time: as the block
    // highlighted whole.
    final open = drawn();
    expect(open.$1, code);
    expect(
      find.descendant(
        of: find.byType(CodeBlockView),
        matching: find.byType(RichText),
      ),
      findsAtLeast(7),
    );

    // The last chunk: the closing fence and the line after.
    stream(text);
    var frames = 0;
    await tester.pump(const Duration(milliseconds: 16));
    while (shownCode() != code && frames < 200) {
      frames++;
      await tester.pump(const Duration(milliseconds: 16));
    }

    if (const bool.fromEnvironment('MARKDOWN_BENCH')) {
      times.sort();
      double p(double q) =>
          times[min(times.length - 1, (q * times.length).floor())];
      // The numbers are what this is run for.
      // ignore: avoid_print
      print(
        '${code.length} characters, ${ends.length} chunks: '
        'p50 ${p(0.5).toStringAsFixed(1)} ms, '
        'p90 ${p(0.9).toStringAsFixed(1)} ms, '
        'max ${times.last.toStringAsFixed(1)} ms a chunk (two frames); '
        'all of it shown ${frames * 16} ms after the last chunk; '
        'most code behind a frame on: ${behind.reduce(max)} characters',
      );
    }
    expect(behind.reduce(max), 0, reason: 'code shows as it comes');
    expect(frames, lessThanOrEqualTo(1));
    final whole = drawn();
    expect(whole.$1, code);
    // All but the last line, plain until it ends.
    for (var i = 0; i < code.lastIndexOf('\n'); i++) {
      if (code[i].trim().isEmpty) continue;
      expect(open.$2[i], whole.$2[i], reason: 'at $i, in ${code[i]}');
    }

    chat
      ..busy = false
      ..notifyListeners();
    await tester.pumpAndSettle();
    expect(shownCode(), code);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
    d.dispose();
  });
}
