import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/theme/theme.dart';

Field choice(
  String id,
  String title,
  List<String> options, {
  bool many = false,
}) => Field(
  id: id,
  title: title,
  description: '$title?',
  type: many ? FieldType.FIELD_TYPE_CHOICES : FieldType.FIELD_TYPE_CHOICE,
  options: [for (final o in options) Option(id: o, name: o)],
);

void main() {
  testWidgets('questions one at a time, back and forth, then Submit', (
    tester,
  ) async {
    List<FieldAnswer>? sent;
    final item = Item(
      id: 'q',
      kind: ItemKind.ITEM_KIND_QUESTION,
      status: 'pending',
      fields: [
        choice('question_0', 'Color', ['red', 'green']),
        Field(
          id: 'question_0_custom',
          title: 'Other',
          type: FieldType.FIELD_TYPE_TEXT,
        ),
        choice('question_1', 'Fruit', ['apple', 'kiwi', 'fig'], many: true),
        choice('question_2', 'Size', ['small', 'big']),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: QuestionCard(item, onAnswer: (a) async => sent = a),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Color?'), findsOneWidget); // one question at a time

    // Answer the second first: two of its options, then on.
    await tester.tap(find.text('Fruit'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Size?'), findsOneWidget);
    // Back to the first (←, ←): picking moves on to the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(find.text('Fruit?'), findsOneWidget);
    // The third, twice: the last pick counts, then the review.
    await tester.tap(find.text('Size'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    await tester.tap(find.text('Size'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(
      find.textContaining('Not answered', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('apple, fig', findRichText: true),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      {for (final a in sent!) a.fieldId: a.values},
      {
        'question_0': ['green'],
        'question_1': ['apple', 'fig'],
        'question_2': ['big'],
      },
    );
  });

  testWidgets('a single question is sent as soon as it is picked', (
    tester,
  ) async {
    List<FieldAnswer>? sent;
    final item = Item(
      id: 'q',
      kind: ItemKind.ITEM_KIND_QUESTION,
      status: 'pending',
      fields: [
        choice('question_0', 'Color', ['red', 'green']),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: QuestionCard(item, onAnswer: (a) async => sent = a),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Submit'), findsNothing); // no tabs, no review
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(sent?.single.values, ['green']);
  });
}
