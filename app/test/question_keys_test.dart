import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/question_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A question card from the keyboard: ↑/↓ move through the options and the
// box under them as one list, a character typed on the card goes into
// the box, and Esc in the box gives the keys back to the card.

Field _format() => Field(
  id: 'question_0',
  title: 'Format',
  description: 'Which format should the weekly report use?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'PDF', name: 'PDF', description: 'Pages to print'),
    Option(id: 'CSV', name: 'CSV', description: 'Rows for a spreadsheet'),
  ],
);

Field _other() => Field(
  id: 'question_0_custom',
  title: 'Other',
  type: FieldType.FIELD_TYPE_TEXT,
  otherFor: 'question_0',
  note: true,
);

Field _colour() => Field(
  id: 'question_1',
  title: 'Colour',
  description: 'Which colour for its charts?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'teal', name: 'teal'),
    Option(id: 'plum', name: 'plum'),
  ],
);

Item _item(List<Field> fields, {String status = 'pending'}) => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: status,
  text: 'One thing about the report',
  fields: fields,
);

/// The card's state while [item]'s card shows: what it sent, its draft.
final class _Card {
  new(this.item);

  final Item item;
  final draft = QuestionDraft();
  List<FieldAnswer>? sent;
  int sends = 0;

  Map<String, List<String>> get answers => {
    for (final a in sent ?? const <FieldAnswer>[]) a.fieldId: a.values,
  };

  Widget build({double width = 560}) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: RepaintBoundary(
              child: QuestionCard(
                item,
                key: ObjectKey(this), // a new card, a new state
                agent: 'Claude',
                draft: draft,
                onAnswer: (a) async {
                  sends++;
                  sent = a;
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<_Card> _show(WidgetTester tester, List<Field> fields) async {
  final card = _Card(_item(fields));
  await tester.pumpWidget(themed(card.build()));
  await tester.pump();
  return card;
}

/// The box's editable text, and whether it has the keys.
EditableText _box(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

bool _inBox(WidgetTester tester) => _box(tester).focusNode.hasPrimaryFocus;

/// Sends [k] and lets the card answer it.
Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

void main() {
  setUpAll(loadFonts);

  for (final several in [false, true]) {
    final what = several ? 'several questions' : 'one question';
    testWidgets('↑/↓ go round the options and the box ($what)', (tester) async {
      final card = await _show(tester, [
        _format(),
        _other(),
        if (several) _colour(),
      ]);
      card.draft.text['question_0_custom']!.text = 'landscape';
      await _key(tester, LogicalKeyboardKey.arrowDown); // on CSV
      expect(_inBox(tester), isFalse);
      await _key(tester, LogicalKeyboardKey.arrowDown); // past the last
      expect(_inBox(tester), isTrue);
      expect(
        _box(tester).controller.selection,
        const TextSelection.collapsed(offset: 9),
        reason: 'the caret at its end',
      );
      await _key(tester, LogicalKeyboardKey.arrowUp); // back to CSV
      expect(_inBox(tester), isFalse);
      await _key(tester, LogicalKeyboardKey.space);
      if (several) {
        expect(find.text('Which colour for its charts?'), findsOneWidget);
        expect(card.draft.picked['question_0'], ['CSV']);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
      } else {
        expect(card.answers['question_0'], ['CSV']);
        expect(card.answers['question_0_custom'], ['landscape']);
        return;
      }
      // Back on the first option: ↑ from it to the box, ↓ there to it.
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(_inBox(tester), isTrue);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(_inBox(tester), isFalse);
      await _key(tester, LogicalKeyboardKey.space); // the first: PDF
      expect(card.draft.picked['question_0'], ['PDF']);
    });

    testWidgets('without a box, ↓ wraps among the options ($what)', (
      tester,
    ) async {
      final card = await _show(tester, [_format(), if (several) _colour()]);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown); // round to PDF
      await _key(tester, LogicalKeyboardKey.keyL); // no box: nothing
      expect(find.byType(EditableText), findsNothing);
      await _key(tester, LogicalKeyboardKey.space);
      expect(
        several ? card.draft.picked['question_0'] : card.answers['question_0'],
        ['PDF'],
      );
    });

    testWidgets('a character typed on the card starts the box ($what)', (
      tester,
    ) async {
      final card = await _show(tester, [
        _format(),
        _other(),
        if (several) _colour(),
      ]);
      await _key(tester, LogicalKeyboardKey.keyL);
      expect(_inBox(tester), isTrue);
      expect(_box(tester).controller.text, 'l');
      expect(
        _box(tester).controller.selection,
        const TextSelection.collapsed(offset: 1),
      );
      // In the box a digit and Space are text, not the card's.
      await _key(tester, LogicalKeyboardKey.digit1);
      await _key(tester, LogicalKeyboardKey.space);
      expect(_inBox(tester), isTrue);
      expect(card.sends, 0);
      expect(card.draft.picked['question_0'] ?? const [], isEmpty);
    });
  }

  testWidgets('a digit no option has starts the box with it', (tester) async {
    final card = await _show(tester, [_format(), _other()]);
    await _key(tester, LogicalKeyboardKey.digit7);
    expect(_inBox(tester), isTrue);
    expect(_box(tester).controller.text, '7');
    expect(card.sends, 0);
  });

  testWidgets('a key with ⌘, Control or Option held types nothing', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other()]);
    for (final (cmd, ctrl, alt) in [
      (true, false, false),
      (false, true, false),
      (false, false, true),
    ]) {
      await press(
        tester,
        LogicalKeyboardKey.keyL,
        cmd: cmd,
        ctrl: ctrl,
        alt: alt,
        settle: false,
      );
      expect(_inBox(tester), isFalse);
      expect(_box(tester).controller.text, isEmpty);
    }
    expect(card.sends, 0);
  }, variant: macAndLinux);

  testWidgets('Esc in the box gives the keys back, the text kept', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other()]);
    await _key(tester, LogicalKeyboardKey.keyL);
    expect(_inBox(tester), isTrue);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_inBox(tester), isFalse);
    expect(_box(tester).controller.text, 'l');
    await _key(tester, LogicalKeyboardKey.digit1); // the card's again
    expect(card.answers, {
      'question_0': ['PDF'],
      'question_0_custom': ['l'],
    });
  });

  testWidgets('a text question: typing on the card goes into its field', (
    tester,
  ) async {
    await _show(tester, [
      Field(
        id: 'question_0',
        title: 'Title',
        description: 'What should the report be called?',
        type: FieldType.FIELD_TYPE_TEXT,
      ),
    ]);
    await _key(tester, LogicalKeyboardKey.keyW);
    expect(_inBox(tester), isTrue);
    expect(_box(tester).controller.text, 'w');
  });

  testWidgets('renders: the box reached and the note, at the chat’s width', (
    tester,
  ) async {
    viewport(tester, const Size(752, 260));
    var card = _Card(_item([_format(), _other()]));
    await tester.pumpWidget(themed(card.build(width: 720)));
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_inBox(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 300)); // its ring's fade
    await render(tester, find.byType(QuestionCard), 'after-box-focused');

    card = _Card(_item([_format(), _other()]));
    card.draft
      ..picked['question_0'] = ['PDF']
      ..text['question_0_custom'] = TextEditingController();
    await tester.pumpWidget(themed(card.build(width: 720)));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Add a note…',
    );
    await render(tester, find.byType(QuestionCard), 'after-picked-placeholder');
    card.draft.text['question_0_custom']!.text = 'landscape pages';
    await tester.pump();
    await render(tester, find.byType(QuestionCard), 'after-picked-note');

    final answered = _item(status: 'answered', [
      _format()..values.add('PDF'),
      _other()..values.add('landscape pages'),
    ]);
    await tester.pumpWidget(themed(_Card(answered).build(width: 720)));
    await tester.pumpAndSettle();
    await render(tester, find.byType(QuestionCard), 'after-answered');
  });
}
