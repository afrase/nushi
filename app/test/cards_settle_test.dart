import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cards.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/theme/theme.dart';

// An answered permission or question settles into its answered line: the
// height eases, the border and fill crossfade (the fluidity review's
// idea 4).

Item _permission(String status) => Item(
  id: 'p',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  status: status,
  title: 'npm install csv-stringify@6',
  answer: status == 'pending' ? '' : 'y',
  options: [
    Option(id: 'y', name: 'Allow once'),
    Option(id: 'a', name: 'Always allow'),
    Option(id: 'n', name: 'Reject'),
  ],
);

Item _question(String status) => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: status,
  text: 'Which format?',
  fields: [
    Field(
      id: 'f',
      title: 'Format',
      description: 'Which format?',
      type: FieldType.FIELD_TYPE_CHOICE,
      options: [
        Option(id: 'csv', name: 'CSV'),
        Option(id: 'tsv', name: 'TSV'),
      ],
      values: status == 'answered' ? ['csv'] : const [],
    ),
  ],
);

Widget _card(Item item) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: Scaffold(
    // In a scroll, as in a transcript: the card takes its own height.
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 560,
          child: item.kind == ItemKind.ITEM_KIND_PERMISSION
              ? PermissionCard(item, onAnswer: (_) async {})
              : QuestionCard(
                  item,
                  agent: 'Claude',
                  draft: QuestionDraft(),
                  onAnswer: (_) async {},
                ),
        ),
      ),
    ),
  ),
);

/// The card's outline: its box's border color.
Color? _border(WidgetTester tester, Finder card) {
  final box = tester
      .widgetList<Container>(
        find.descendant(of: card, matching: find.byType(Container)),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.border != null);
  return (box.border! as Border).top.color;
}

void main() {
  for (final (name, pending, answered, type) in [
    (
      'permission',
      _permission('pending'),
      _permission('answered'),
      PermissionCard,
    ),
    ('question', _question('pending'), _question('answered'), QuestionCard),
  ]) {
    testWidgets('an answered $name settles: its height eases, its colors '
        'crossfade', (tester) async {
      await tester.pumpWidget(_card(pending));
      await tester.pumpAndSettle();
      final card = find.byType(type);
      final tall = tester.getSize(card).height;
      final waiting = _border(tester, card);

      await tester.pumpWidget(_card(answered));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final mid = tester.getSize(card).height;
      final midBorder = _border(tester, card);
      await tester.pumpAndSettle();
      final short = tester.getSize(card).height;
      final settled = _border(tester, card);
      expect(short, lessThan(tall));
      expect(mid, inExclusiveRange(short, tall));
      expect(midBorder, isNot(anyOf(waiting, settled)));
      expect(settled, Tokens.dark.borderSubtle);
    });

    testWidgets('with Reduce Motion an answered $name changes at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_card(pending));
      await tester.pumpAndSettle();
      final card = find.byType(type);
      await tester.pumpWidget(_card(answered));
      await tester.pump();
      final at = tester.getSize(card).height;
      expect(_border(tester, card), Tokens.dark.borderSubtle);
      await tester.pump(Motion.standard);
      expect(tester.getSize(card).height, at);
    });
  }
}
