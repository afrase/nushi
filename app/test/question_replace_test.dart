import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// Where the agent takes the box's text in place of a one-choice question's
// pick (Field.replaces: OpenCode's and oh-my-pi's), an answer is a pick or
// the text, never both: typing unmarks the pick, a pick greys the text and
// keeps it out of the answer, and the box's hint says which will be sent.

Field _colour({List<String> values = const []}) => Field(
  id: 'q0',
  title: 'Colour',
  description: 'Which colour should the chart use?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'Red', name: 'Red'),
    Option(id: 'Green', name: 'Green'),
  ],
  values: values,
);

Field _size() => Field(
  id: 'q1',
  title: 'Size',
  description: 'How big should it be?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'small', name: 'small'),
    Option(id: 'large', name: 'large'),
  ],
);

/// The box after [_colour]: its text in place of the pick where
/// [replaces], else one more answer.
Field _other({bool replaces = true}) => Field(
  id: 'q0_custom',
  title: 'Colour (other)',
  type: FieldType.FIELD_TYPE_TEXT,
  otherFor: 'q0',
  replaces: replaces,
);

Item _item(List<Field> fields) => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: 'pending',
  text: 'One thing about the chart',
  fields: fields,
);

/// [item]'s card on its own; [onAnswer] gets what it sends.
Widget _card(
  Item item, {
  QuestionDraft? draft,
  Tokens tokens = Tokens.dark,
  void Function(List<FieldAnswer>? answer)? onAnswer,
}) => themed(
  tokens: tokens,
  Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 560,
        child: RepaintBoundary(
          child: QuestionCard(
            item,
            agent: 'OpenCode',
            draft: draft ?? QuestionDraft(),
            onAnswer: (a) async => onAnswer?.call(a),
          ),
        ),
      ),
    ),
  ),
);

/// A draft with Red picked and [typed] in the box, on question [tab].
QuestionDraft _picked(String typed, {int tab = 0}) => QuestionDraft()
  ..picked['q0'] = ['Red']
  ..text['q0_custom'] = TextEditingController(text: typed)
  ..tab = tab;

TextField _box(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

Map<String, List<String>> _byField(List<FieldAnswer> a) => {
  for (final f in a) f.fieldId: f.values,
};

void main() {
  setUpAll(loadFonts);

  testWidgets("the hint says the text takes the pick's place", (tester) async {
    await tester.pumpWidget(_card(_item([_colour(), _other(), _size()])));
    await tester.pump();
    expect(_box(tester).decoration?.hintText, 'Type your own answer…');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1); // Red, then on
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      _box(tester).decoration?.hintText,
      'Type your own answer in place of your pick…',
    );
  });

  testWidgets('typing in the box unmarks the pick', (tester) async {
    final draft = _picked('');
    await tester.pumpWidget(
      _card(_item([_colour(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'teal');
    await tester.pump();
    expect(draft.picked['q0'], isEmpty);
    expect(_box(tester).decoration?.prefixText, isNull, reason: 'it is sent');
    expect(_box(tester).style?.color, Tokens.dark.text);
  });

  testWidgets('moving into the box keeps the pick', (tester) async {
    final draft = _picked('');
    await tester.pumpWidget(
      _card(_item([_colour(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // into the box
    await tester.pump();
    expect(draft.picked['q0'], ['Red']);
  });

  testWidgets('a pick greys the text and leaves it out', (tester) async {
    List<FieldAnswer>? sent;
    await tester.pumpWidget(
      _card(_item([_colour(), _other()]), onAnswer: (a) => sent = a),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'teal');
    await tester.pump();
    await tester.tap(find.textContaining('Red', findRichText: true));
    await tester.pump();
    expect(_byField(sent!), {
      'q0': ['Red'],
    });
  });

  testWidgets('greyed, the text says it is not sent; typing brings it back', (
    tester,
  ) async {
    final draft = _picked('teal');
    await tester.pumpWidget(
      _card(_item([_colour(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    expect(_box(tester).decoration?.prefixText, 'Not sent: ');
    expect(_box(tester).style?.color, Tokens.dark.textMuted);
    expect(draft.text['q0_custom']!.text, 'teal', reason: 'kept');
    await tester.enterText(find.byType(TextField), 'teal blue');
    await tester.pump();
    expect(draft.picked['q0'], isEmpty);
    expect(_box(tester).decoration?.prefixText, isNull);
    expect(_box(tester).style?.color, Tokens.dark.text);
  });

  testWidgets('deleting the greyed text keeps the pick; typing over it '
      'sends the text', (tester) async {
    final draft = _picked('teal');
    await tester.pumpWidget(
      _card(_item([_colour(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    for (final left in ['tea', 'ta', '']) {
      await tester.enterText(find.byType(TextField), left);
      await tester.pump();
      expect(draft.picked['q0'], ['Red'], reason: 'deleted to "$left"');
    }
    await tester.enterText(find.byType(TextField), 't');
    await tester.pump();
    expect(draft.picked['q0'], isEmpty, reason: 'typed');
  });

  testWidgets('a key typed over the selected greyed text sends the text', (
    tester,
  ) async {
    final draft = _picked('teal');
    await tester.pumpWidget(
      _card(_item([_colour(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(draft.picked['q0'], isEmpty);
  });

  testWidgets('the review and the sent answer hold only the pick', (
    tester,
  ) async {
    List<FieldAnswer>? sent;
    await tester.pumpWidget(
      _card(
        _item([_colour(), _other(), _size()]),
        draft: _picked('teal', tab: 2),
        onAnswer: (a) => sent = a,
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('teal', findRichText: true),
      findsNothing,
      reason: 'not in the review',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_byField(sent!), {
      'q0': ['Red'],
    });
  });

  testWidgets('the text alone is sent once the pick is gone', (tester) async {
    List<FieldAnswer>? sent;
    await tester.pumpWidget(
      _card(
        _item([_colour(), _other()]),
        draft: _picked(''),
        onAnswer: (a) => sent = a,
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'teal');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_byField(sent!), {
      'q0_custom': ['teal'],
    });
  });

  testWidgets('where the text is one more answer, both are sent as before', (
    tester,
  ) async {
    List<FieldAnswer>? sent;
    final draft = _picked('teal');
    await tester.pumpWidget(
      _card(
        _item([_colour(), _other(replaces: false)]),
        draft: draft,
        onAnswer: (a) => sent = a,
      ),
    );
    await tester.pump();
    expect(_box(tester).decoration?.prefixText, isNull);
    await tester.enterText(find.byType(TextField), 'teal blue');
    await tester.pump();
    expect(draft.picked['q0'], ['Red'], reason: 'typing keeps the pick');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_byField(sent!), {
      'q0': ['Red'],
      'q0_custom': ['teal blue'],
    });
  });

  for (final b in renderThemes) {
    for (final width in [1700.0, 720.0]) {
      renderTest('a pick with text not sent, ${width.toInt()} (${b.name})', (
        tester,
      ) async {
        final fake = FakeDaemon([chat('c', 'opencode', 'Draw the chart')])
          ..chatItems['c'] = [
            userSays('u', 'Draw the weekly chart.'),
            _item([_colour(), _other(), _size()]),
          ];
        final d = await openApp(
          tester,
          fake,
          size: Size(width, 700),
          brightness: b,
        );
        await tester.enterText(
          find.descendant(
            of: find.byType(QuestionCard),
            matching: find.byType(TextField),
          ),
          'teal',
        );
        await tester.pump();
        await tester.tap(find.textContaining('Red', findRichText: true).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Colour').last);
        await tester.pumpAndSettle();
        expectTextInside(tester, width);
        await render(
          tester,
          find.byType(NushiApp),
          'question_replace_${width.toInt()}_${b.name}',
        );
        await closeView(tester, d);
      }, variant: onMac);
    }
  }

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a pick with text not sent ($name)', (tester) async {
      viewport(tester, const Size(600, 400));
      await tester.pumpWidget(
        _card(
          _item([_colour(), _other(), _size()]),
          draft: _picked('teal'),
          tokens: tokens,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_replace_pending_$name.png'),
      );
    });
  }
}
