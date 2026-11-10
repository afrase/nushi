import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agent_mark.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'theme_sets.dart';

const _agents = [
  'claude',
  'codex',
  'ante',
  'omp',
  'pi',
  'pig',
  'opencode',
  'gemini',
];

/// The WCAG contrast of [a] and [b].
double _contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = x > y ? (x, y) : (y, x);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadFonts);

  test('each agent’s color is at least 3:1 on the sidebar, a selected row '
      'and the header, in every theme', () {
    for (final (name, t) in everySet) {
      for (final a in _agents) {
        final color = agentColor(a, t);
        final colors = [?color, if (a == 'omp') t.ompPlug];
        for (final c in colors) {
          for (final (where, bg) in [
            ('base', t.base),
            ('raised', t.raised),
            ('selected', t.selected),
          ]) {
            expect(
              _contrast(c, bg),
              greaterThanOrEqualTo(3),
              reason: '$a on $where, $name',
            );
          }
        }
      }
    }
    // Codex's Blossom keeps the text's color, as OpenAI draws it, and
    // OpenCode's O as OpenCode does.
    expect(agentColor('codex', Tokens.dark), isNull);
    expect(agentColor('opencode', Tokens.dark), isNull);
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    // Each mark in its colors on the sidebar's surface, then in the
    // header's ink, then muted as an archived chat's.
    testWidgets('golden, the agents’ marks, $name', (tester) async {
      viewport(tester, const Size(220, 84), ratio: 2);
      final t = tokens;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: NushiTheme(tokens).toThemeData(),
          home: Material(
            color: t.raised,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                spacing: 8,
                children: [
                  for (final (ink, color) in [
                    (null, null),
                    (t.text, null),
                    (null, t.textMuted),
                  ])
                    Row(
                      spacing: 10,
                      children: [
                        for (final a in _agents)
                          AgentMark(a, size: 16, ink: ink, color: color),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/agent_marks_$name.png'),
      );
    });
  }
}
