import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A pick with text in the box is a pick with a note, where the agent reads
// it so (Field.note: Claude's one-choice question): the box asks for a
// note, and the answered card shows the note after the pick.

Field _format({List<String> values = const []}) => Field(
  id: 'question_0',
  title: 'Format',
  description: 'Which format should the weekly report use?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'PDF', name: 'PDF', description: 'Pages to print'),
    Option(id: 'CSV', name: 'CSV', description: 'Rows for a spreadsheet'),
  ],
  values: values,
);

Field _size() => Field(
  id: 'question_1',
  title: 'Size',
  description: 'How long should it be?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'short', name: 'short'),
    Option(id: 'long', name: 'long'),
  ],
);

/// The box after [_format]: a note where [note], else an answer.
Field _other({bool note = true, List<String> values = const []}) => Field(
  id: 'question_0_custom',
  title: 'Other',
  type: FieldType.FIELD_TYPE_TEXT,
  otherFor: 'question_0',
  note: note,
  values: values,
);

Item _item(
  List<Field> fields, {
  String status = 'pending',
  String text = 'One thing about the report',
}) => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: status,
  text: text,
  fields: fields,
);

/// [item]'s card on its own, [width] wide; [onAnswer] gets what it sends.
Widget _card(
  Item item, {
  QuestionDraft? draft,
  Tokens tokens = Tokens.dark,
  double width = 560,
  void Function(List<FieldAnswer>? answer)? onAnswer,
}) => themed(
  tokens: tokens,
  Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(16),
      // Its height its own, as in the transcript's list.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: RepaintBoundary(
              child: QuestionCard(
                item,
                agent: 'Claude',
                draft: draft ?? QuestionDraft(),
                onAnswer: (a) async => onAnswer?.call(a),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

/// A draft with PDF picked and [typed] in the box.
QuestionDraft _picked([String typed = '']) => QuestionDraft()
  ..picked['question_0'] = ['PDF']
  ..text['question_0_custom'] = TextEditingController(text: typed);

String? _hint(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration?.hintText;

String? _label(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration?.prefixText;

/// The style of the span saying [text] in the rich text holding it.
TextStyle? _styleOf(WidgetTester tester, String text) {
  for (final r in tester.widgetList<RichText>(
    find.textContaining(text, findRichText: true),
  )) {
    TextStyle? found;
    r.text.visitChildren((s) {
      if (s is TextSpan && s.text?.trim() == text) found = s.style;
      return found == null;
    });
    if (found != null) return found;
  }
  return null;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('the box asks for a note once an option is picked', (
    tester,
  ) async {
    final item = _item([_format(), _other(), _size()]);
    await tester.pumpWidget(_card(item));
    await tester.pump();
    expect(_hint(tester), 'Other…', reason: 'nothing picked');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1); // PDF, then on
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_hint(tester), 'Add a note…');
  });

  testWidgets('a note being written says so in the box', (tester) async {
    await tester.pumpWidget(
      _card(_item([_format(), _other()]), draft: _picked()),
    );
    await tester.pump();
    expect(_label(tester), isNull, reason: 'empty: the placeholder says it');
    await tester.enterText(find.byType(TextField), 'landscape pages');
    await tester.pump();
    expect(_label(tester), 'Note: ');
    expect(find.text('Note: '), findsOneWidget, reason: 'shown, typing on');
  });

  testWidgets('text with nothing picked, or no note field, has no label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        _item([_format(), _other()]),
        draft: QuestionDraft()
          ..text['question_0_custom'] = TextEditingController(text: 'x'),
      ),
    );
    await tester.pump();
    expect(_label(tester), isNull);
    await tester.pumpWidget(
      _card(_item([_format(), _other(note: false)]), draft: _picked('x')),
    );
    await tester.pump();
    expect(_label(tester), isNull);
  });

  testWidgets('where the agent takes no note, the box is as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(_item([_format(), _other(note: false)]), draft: _picked()),
    );
    await tester.pump();
    expect(_hint(tester), 'Other…');
  });

  testWidgets('a pick after the note keeps it: both fields are sent', (
    tester,
  ) async {
    List<FieldAnswer>? sent;
    await tester.pumpWidget(
      _card(_item([_format(), _other()]), onAnswer: (a) => sent = a),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'landscape pages');
    await tester.pump();
    await tester.tap(find.textContaining('PDF', findRichText: true));
    await tester.pump();
    expect(
      {for (final a in sent!) a.fieldId: a.values},
      {
        'question_0': ['PDF'],
        'question_0_custom': ['landscape pages'],
      },
    );
  });

  testWidgets('the review shows the pick, then the note, muted', (
    tester,
  ) async {
    final draft = _picked('landscape pages')..tab = 2; // the review
    await tester.pumpWidget(
      _card(_item([_format(), _other(), _size()]), draft: draft),
    );
    await tester.pump();
    const t = Tokens.dark;
    expect(_styleOf(tester, 'PDF')?.color, t.text);
    expect(_styleOf(tester, 'landscape pages')?.color, t.textSecondary);
    expect(_styleOf(tester, 'Note:')?.color, t.textMuted);
    expect(
      find.textContaining('PDF  Note: landscape pages', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('answered: the note follows the pick, in the summary and open', (
    tester,
  ) async {
    final item = _item(status: 'answered', [
      _format(values: ['PDF']),
      _other(values: ['landscape pages']),
    ]);
    await tester.pumpWidget(_card(item));
    await tester.pumpAndSettle();
    const t = Tokens.dark;
    expect(_styleOf(tester, 'PDF')?.color, t.text);
    expect(_styleOf(tester, 'landscape pages')?.color, t.textSecondary);
    expect(
      find.textContaining('PDF  Note: landscape pages', findRichText: true),
      findsOneWidget,
      reason: 'labelled, not a second answer',
    );
    expect(
      find.textContaining('Other', findRichText: true),
      findsNothing,
      reason: 'not an answer of its own',
    );
    await tester.tap(find.byType(TurnChevron));
    await tester.pumpAndSettle();
    final pdf = tester.getRect(
      find.textContaining('PDF  Pages to print', findRichText: true).last,
    );
    final note = tester.getRect(
      find.textContaining('Note: landscape pages', findRichText: true).last,
    );
    expect(note.left, pdf.left, reason: 'under the option picked');
    expect(note.top, greaterThanOrEqualTo(pdf.bottom));
  });

  testWidgets('answered without a note field: Other is its own line', (
    tester,
  ) async {
    final item = _item(status: 'answered', [
      _format(values: ['PDF']),
      _other(note: false, values: ['landscape pages']),
    ]);
    await tester.pumpWidget(_card(item));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Other  landscape pages', findRichText: true),
      findsOneWidget,
    );
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('a pick with a note, pending and answered ($name)', (
      tester,
    ) async {
      viewport(tester, const Size(600, 400));
      await tester.pumpWidget(
        _card(
          _item([_format(), _other()]),
          draft: _picked('landscape pages'),
          tokens: tokens,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_note_pending_$name.png'),
      );
      final answered = _item(status: 'answered', [
        _format(values: ['PDF']),
        _other(values: ['landscape pages']),
      ]);
      await tester.pumpWidget(_card(answered, tokens: tokens));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_note_answered_$name.png'),
      );
      await tester.tap(find.byType(TurnChevron));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_note_open_$name.png'),
      );
    });
  }
}
