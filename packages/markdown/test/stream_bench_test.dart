import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_view/markdown_view.dart';

/// A reply of about 3,000 words as agents write them: headings, paragraphs
/// with inline code and bold, lists, code blocks and a table.
String reply() {
  final out = StringBuffer();
  final words =
      'the shard runner splits every second test file so both halves '
              'finish in about the same time and the goldens stay with their '
              'tests while the cache keeps the build warm between runs'
          .split(' ');
  final r = Random(7);
  String sentence() {
    final n = 10 + r.nextInt(14);
    final s = [for (var i = 0; i < n; i++) words[r.nextInt(words.length)]];
    if (r.nextBool()) s[r.nextInt(n)] = '`${s[r.nextInt(n)]}`';
    if (r.nextInt(3) == 0) s[r.nextInt(n)] = '**${s[r.nextInt(n)]}**';
    return '${s.join(' ')}.';
  }

  var section = 0;
  while (out.toString().split(RegExp(r'\s+')).length < 3000) {
    section++;
    out.write('## Part $section\n\n');
    for (var p = 0; p < 2; p++) {
      out.write('${[for (var i = 0; i < 4; i++) sentence()].join(' ')}\n\n');
    }
    out.write('- ${sentence()}\n- ${sentence()}\n- ${sentence()}\n\n');
    if (section.isEven) {
      out.write(
        '```dart\nvoid main() {\n  for (var i = 0; i < $section; i++) {\n'
        "    print('shard \$i');\n  }\n}\n```\n\n",
      );
    }
    if (section % 3 == 0) {
      out
        ..write('| Job | Before | After |\n|---|---|---|\n')
        ..write('| test-app | 12:57 | 3:13 |\n| release | 19:30 | 5:21 |\n\n');
    }
  }
  return out.toString();
}

/// Its chunks as they stream: mostly 5 to 40 characters, some of 90 to 180.
List<int> chunkEnds(int length) {
  final r = Random(3);
  final ends = <int>[];
  var at = 0;
  while (at < length) {
    at = min(
      length,
      at + (r.nextInt(7) == 0 ? 90 + r.nextInt(90) : 5 + r.nextInt(36)),
    );
    ends.add(at);
  }
  return ends;
}

const _style = MarkdownStyle(
  body: TextStyle(fontSize: 13.5, height: 1.5),
  code: TextStyle(fontSize: 12.5),
  codeBackground: Colors.black12,
  border: Colors.grey,
  muted: Colors.grey,
  link: Colors.blue,
  highlight: _plain,
);

TextSpan? _plain(String language, String code, TextStyle style) => null;

/// How long each chunk takes to build, lay out and paint, streamed into a
/// message 720 points wide, as it streams now (only the last block parsed
/// again) and as it did (the whole message healed and parsed again), chunk
/// by chunk in turn in one test so both meet the same machine: p50, p90,
/// p99 and the most. Run with MARKDOWN_BENCH=1 (`flutter test
/// test/stream_bench_test.dart`).
void main() {
  testWidgets('a 3,000-word reply streaming: frame times per chunk', (
    tester,
  ) async {
    final text = reply();
    final ends = chunkEnds(text.length);
    Widget now = const SizedBox();
    Widget whole = const SizedBox();
    Widget app() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(width: 720, child: now),
              SizedBox(width: 720, child: whole),
            ],
          ),
        ),
      ),
    );
    final times = (now: <double>[], whole: <double>[]);
    final clock = Stopwatch();
    for (final (i, end) in ends.indexed) {
      final s = text.substring(0, end);
      clock
        ..reset()
        ..start();
      now = StreamingMarkdown(s, key: const ValueKey('now'), style: _style);
      await tester.pumpWidget(app());
      if (i >= 30) times.now.add(clock.elapsedMicroseconds / 1000);
      clock
        ..reset()
        ..start();
      whole = StreamingMarkdown(
        heal(s, markOpen: true),
        key: const ValueKey('whole'),
        style: _style,
        streaming: false,
      );
      await tester.pumpWidget(app());
      if (i >= 30) times.whole.add(clock.elapsedMicroseconds / 1000);
    }
    final words = text.split(RegExp(r'\s+')).length;
    String line(String name, List<double> t) {
      t.sort();
      double p(double q) => t[min(t.length - 1, (q * t.length).floor())];
      return '$name: p50 ${p(0.5).toStringAsFixed(1)} ms, '
          'p90 ${p(0.9).toStringAsFixed(1)} ms, '
          'p99 ${p(0.99).toStringAsFixed(1)} ms, '
          'max ${t.last.toStringAsFixed(1)} ms, '
          '${t.where((v) => v > 16).length} of ${t.length} over 16 ms';
    }

    // The numbers are what this is run for.
    // ignore: avoid_print
    print(
      '$words words, ${text.length} characters, ${ends.length} chunks\n'
      '${line('whole', times.whole)}\n${line('last block', times.now)}',
    );
  }, skip: !Platform.environment.containsKey('MARKDOWN_BENCH'));
}
