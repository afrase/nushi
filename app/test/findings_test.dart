import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/findings.dart';
import 'package:nushi/findings_card.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

/// Claude Code's /code-review without ReportFindings, as it came (step
/// 258): a sentence, then the findings in a fenced block.
const _message = '''
I found 2 issues in `calc/calc.go`. I read the diff only.

```json
[
  {
    "file": "calc/calc.go",
    "line": 6,
    "summary": "Average's loop now starts at index 1, so the first element is dropped.",
    "failure_scenario": "Average([]int{10, 20}) returns 10 instead of 15."
  },
  {
    "file": "calc/calc.go",
    "line": 14,
    "summary": "Max starts the running maximum at 0 instead of xs[0].",
    "failure_scenario": "Max([]int{-3, -1}) returns 0 instead of -1."
  }
]
```

Want me to fix them?''';

Finding _f(
  String file,
  int line,
  String short, {
  String category = 'correctness',
  String summary = '',
}) => Finding(
  file: file,
  line: line,
  shortSummary: short,
  summary: summary.isEmpty ? '$short, in more words.' : summary,
  failureScenario:
      'Called with `[]int{}` it panics with integer divide by zero.',
  category: category,
);

Future<void> _pump(WidgetTester tester, Widget card, Tokens tokens) =>
    tester.pumpWidget(
      MaterialApp(
        theme: NushiTheme(tokens).toThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: card,
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadFonts);

  test('findings written as JSON are found, with the text around them', () {
    final found = findingsInText(_message)!;
    expect(
      found.before,
      'I found 2 issues in `calc/calc.go`. I read the diff only.',
    );
    expect(found.after, 'Want me to fix them?');
    expect(found.json, startsWith('```json\n['));
    expect(found.findings.items.map((f) => (f.file, f.line)), [
      ('calc/calc.go', 6),
      ('calc/calc.go', 14),
    ]);
    expect(
      found.findings.items.first.failureScenario,
      contains('instead of 15'),
    );

    final bare = findingsInText(
      'Found one:\n[{"file": "a.go", "line": null, "summary": "x"}]',
    )!;
    expect(bare.before, 'Found one:');
    expect(bare.findings.items.single.line, 0);
    expect(bare.json, startsWith('```json\n['));

    for (final not in [
      _message.substring(0, _message.length - 30), // still streaming
      '```json\n[{"file": "a.go", "summary": "no line"}]\n```',
      '```json\n[{"file": "a.go", "line": "6", "summary": "x"}]\n```',
      '```json\n[]\n```',
      '```json\n{"file": "a.go", "line": 1, "summary": "x"}\n```',
      'The keys are "file" and "summary" [1].',
    ]) {
      expect(findingsInText(not), isNull, reason: not);
    }
  });

  test('a finding’s id is its own, the same however it came', () {
    final a = _f('a.go', 1, 'x');
    final ids = findingIds([a, _f('a.go', 2, 'x'), a]);
    expect(ids[0], isNot(ids[1]));
    expect(ids[2], '${ids[0]}-2');
    expect(findingIds([_f('a.go', 1, 'x', category: 'other')]).single, ids[0]);
  });

  test('only a file inside the chat’s folder opens', () {
    final real = Directory.systemTemp
        .createTempSync('nf')
        .resolveSymbolicLinksSync();
    addTearDown(() => Directory(real).deleteSync(recursive: true));
    Directory('$real/sub').createSync();
    final link = '${Directory.systemTemp.path}/nf-link-$pid';
    Link(link).createSync(real);
    addTearDown(() => Link(link).deleteSync());
    expect(findingPath(link, 'calc/./calc.go'), 'calc/calc.go');
    expect(findingPath(link, 'calc/../go.mod'), 'go.mod');
    expect(findingPath(link, '$link/calc/calc.go'), 'calc/calc.go');
    expect(findingPath(link, '$real/calc/calc.go'), 'calc/calc.go');
    for (final out in [
      '../x.go',
      'calc/../../x.go',
      '/etc/passwd',
      '$real-2/x',
      '',
      '.',
      link,
    ]) {
      expect(findingPath(link, out), isNull, reason: out);
    }
    expect(
      shortPath('internal/features/chats/updates.go'),
      '…/chats/updates.go',
    );
    expect(shortPath('calc/calc.go'), 'calc/calc.go');
  });

  testWidgets('arrows move between rows, ⏎ opens one; a file opens the '
      'chat’s Changes', (tester) async {
    final chat = ChatState('c', '/nowhere/calc');
    await _pump(
      tester,
      FindingsCard(
        Findings(
          items: [
            _f('calc/calc.go', 6, 'Average skips the first element'),
            _f('/elsewhere/x.go', 3, 'Outside'),
          ],
        ),
        chat,
      ),
      Tokens.dark,
    );
    expect(
      find.textContaining('in more words', findRichText: true),
      findsNothing,
    );
    await tester.tap(find.text('Outside'));
    await tester.pump();
    expect(
      find.textContaining('Outside, in more words', findRichText: true),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.textContaining(
        'Average skips the first element, in more words',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.textContaining(
        'Average skips the first element, in more words',
        findRichText: true,
      ),
      findsNothing,
    );

    await tester.tap(find.text('/elsewhere/x.go'));
    expect(chat.openPath, isNull);
    await tester.tap(find.text('calc/calc.go'));
    expect(chat.openPath, 'calc/calc.go');
  });

  testWidgets('findings from text show their JSON on asking', (tester) async {
    final found = findingsInText(_message)!;
    await _pump(
      tester,
      FindingsCard(
        found.findings,
        ChatState('c', '/nowhere'),
        json: found.json,
      ),
      Tokens.dark,
    );
    expect(find.text('Review: 2 findings'), findsOneWidget);
    await tester.tap(find.text('Show JSON'));
    await tester.pump();
    expect(
      find.textContaining('"failure_scenario"', findRichText: true),
      findsWidgets,
    );
    expect(find.text('Hide JSON'), findsOneWidget);
  });

  final twelve = [
    _f(
      'internal/features/chats/updates.go',
      312,
      'A tool call update for a gone item panics',
    ),
    _f(
      'internal/claude/claude.go',
      41,
      'SessionMeta shares one map across sessions',
    ),
    _f(
      'app/lib/findings_card.dart',
      0,
      'Rows lose their state when findings stream in',
      category: 'test-coverage',
    ),
    _f(
      'a/very/long/path/that/goes/on/and/on/through/many/folders/before/it/ends/somewhere_deep_inside_the_tree_of_files.go',
      9,
      'A long path stays on one line',
    ),
    _f(
      'go.mod',
      3,
      'The toolchain line pins a patch that has a known vulnerability in '
          'its standard library',
      category: 'security',
    ),
    _f(
      'internal/git/read.go',
      22,
      'File reads past the limit by one byte',
      category: 'efficiency',
    ),
    _f(
      '/elsewhere/vendor/lib.go',
      88,
      'Outside the folder: shown, never opened',
    ),
    _f(
      'app/lib/items.dart',
      160,
      'The card loses its key when text comes before it',
      category: 'simplification',
    ),
    _f(
      'internal/api/convert.go',
      98,
      'A finding without a line is sent as line 0',
    ),
    _f(
      'proto/nushi/v1/nushi.proto',
      1180,
      'Findings has no field for the review’s target',
    ),
    _f(
      'README.md',
      0,
      'The README doesn’t say how findings open',
      category: '',
    ),
    _f(
      'docs/facts/claude.md',
      40,
      'The facts name an adapter version that has moved on',
    ),
  ];
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    for (final (what, findings, json, open) in [
      ('one', Findings(level: 'high', items: [twelve.first]), false, 0),
      ('five', Findings(level: 'medium', items: twelve.sublist(0, 5)), true, 1),
      ('twelve', Findings(items: twelve), false, -1),
    ]) {
      testWidgets('golden, $what finding(s), $name', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = Size(
            800,
            60.0 + 34 * findings.items.length + (open >= 0 ? 60 : 0),
          );
        addTearDown(tester.view.reset);
        await _pump(
          tester,
          FindingsCard(
            findings,
            ChatState('c', '/nowhere'),
            json: json ? _message : null,
          ),
          tokens,
        );
        if (open >= 0) {
          await tester.tap(find.text(findings.items[open].shortSummary));
          await tester.pump();
        }
        await expectLater(
          find.byType(FindingsCard),
          matchesGoldenFile('goldens/findings_${what}_$name.png'),
        );
      });
    }
  }
}
