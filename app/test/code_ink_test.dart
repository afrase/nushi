// Inline code is orange, as Slack draws it, wherever it shows: the agent's
// text, the user's band, a finding and the composer (composer_code_test has
// the composer's own rules), on the Mac and the phone. Its ink holds AA on
// every fill its chip can sit on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';
import 'theme_sets.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// The WCAG contrast of [a] and [b].
double _contrast(Color a, Color b) {
  double lum(Color c) => c.computeLuminance();
  final (hi, lo) = lum(a) > lum(b) ? (lum(a), lum(b)) : (lum(b), lum(a));
  return (hi + 0.05) / (lo + 0.05);
}

Color _on(Color tint, Color surface) => Color.alphaBlend(tint, surface);

final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'Why does `make check` run `go vet` twice?',
  ),
  Item(
    id: 'm',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        'Because `lint` and `test` both depend on `vet`: the Makefile lists '
        'it under each. Drop it from `test` (it runs in `lint` anyway), or '
        'make `check` run `vet` once and the other two without it.\n\n'
        '```make\ncheck: vet lint test\n```\n\n'
        'With that, `make check` vets once.',
  ),
];

/// The span drawn with [text] under [root], its style merged down.
TextStyle? _styleOf(WidgetTester tester, Finder root, String text) {
  for (final r in tester.widgetList<RichText>(
    find.descendant(of: root, matching: find.byType(RichText)),
  )) {
    TextStyle? found;
    void visit(InlineSpan span, TextStyle? above) {
      final style = above?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        if (span.text == text) found = style;
        for (final c in span.children ?? const <InlineSpan>[]) {
          visit(c, style);
        }
      }
    }

    visit(r.text, null);
    if (found != null) return found;
  }
  return null;
}

void main() {
  setUpAll(loadFonts);

  for (final (name, t) in everySet) {
    test('inline code holds AA on every fill it sits on ($name)', () {
      // The agent's (and a finding's, and the composer's) chip on what's
      // under it: the page, a raised panel, a code block, the findings
      // card, a row under the pointer or selected (as `chat_colors_test`
      // has a row); the band's chip on the band, which has no hover.
      final under = {
        'base': t.base,
        'raised': t.raised,
        'code block': t.codeBlock,
        'findings': _on(t.findingsTint, t.base),
        'hovered': _on(t.hover, t.raised),
        'hovered on base': _on(t.hover, t.base),
        'findings, hovered': _on(t.hover, _on(t.findingsTint, t.base)),
        'selected': t.selected,
      };
      final fills = {
        for (final MapEntry(key: n, value: c) in under.entries)
          n: _on(t.inlineCode, c),
        'the band': _on(t.userBandCode, t.userBand),
      };
      for (final MapEntry(key: fill, value: c) in fills.entries) {
        expect(
          _contrast(t.inlineCodeText, c),
          greaterThanOrEqualTo(4.5),
          reason: 'on $fill',
        );
      }
    });

    test('the chips are tints: a selection under them shows ($name)', () {
      expect(t.inlineCode.a, lessThan(0.2));
      expect(t.userBandCode.a, lessThan(0.2));
    });

    testWidgets('the agent and the band draw it in its ink on its chip '
        '($name)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NushiTheme(t).toThemeData(),
          home: const Column(
            children: [
              AgentMarkdown('a `b` c', key: Key('agent')),
              AgentMarkdown('d `e` f', key: Key('band'), typed: true),
            ],
          ),
        ),
      );
      final agent = _styleOf(tester, find.byKey(const Key('agent')), 'b')!;
      expect(agent.color, t.inlineCodeText);
      expect(agent.backgroundColor, t.inlineCode);
      expect(agent.fontFamily, NushiTheme.codeFont);
      final band = _styleOf(tester, find.byKey(const Key('band')), 'e')!;
      expect(band.color, t.inlineCodeText);
      expect(band.backgroundColor, t.userBandCode);
      expect(
        _styleOf(tester, find.byKey(const Key('agent')), 'a ')?.color,
        t.agentText,
      );
    });
  }

  for (final (width, b) in [
    (1700.0, Brightness.dark),
    (1700.0, Brightness.light),
    (720.0, Brightness.dark),
    (720.0, Brightness.light),
  ]) {
    for (final (where, caret) in [('outside', 33), ('inside', 13)]) {
      testWidgets('the window, $width wide, ${b.name}: caret $where the '
          "composer's code", (tester) async {
        viewport(tester, Size(width, 900), brightness: b);
        showDetails.value = false;
        paneWidths.value = {};
        final c = chat('c', 'claude', 'Why make check vets twice');
        final fake = FakeDaemon([c])
          ..answer = ((input) => input is GetChatRequest
              ? GetChatResponse(chat: c, items: _items)
              : null);
        final d = await fake.connect(tester);
        d.select('c');
        await tester.pumpWidget(NushiApp(daemon: d));
        await tester.pumpAndSettle();
        d.chats['c']!.draft.text.value = TextEditingValue(
          text: 'Then make `check` run `vet` once.',
          selection: TextSelection.collapsed(offset: caret),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await render(
          tester,
          find.byType(NushiApp),
          'code_ink_${width.toInt()}_${b.name}_$where',
        );
        await closeView(tester, d);
      }, variant: _mac);
    }
  }

  for (final b in Brightness.values) {
    testWidgets('the phone’s chat, 390×844 (${b.name})', (tester) async {
      viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
      final c = chat('c', 'claude', 'Why make check vets twice');
      final fake = FakeDaemon([c])
        ..answer = ((input) => input is GetChatRequest
            ? GetChatResponse(chat: c, items: _items)
            : null);
      final phone = await startPhone(tester, fake);
      await tester.tap(find.text('Why make check vets twice'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final t = b == Brightness.dark ? Tokens.dark : Tokens.light;
      final vet = _styleOf(tester, find.byType(PhoneApp), 'vet');
      expect(vet?.color, t.inlineCodeText);
      expect(tester.takeException(), isNull);
      await render(tester, find.byType(PhoneApp), 'code_ink_phone_${b.name}');
      await endPhone(tester, phone);
    });
  }
}
