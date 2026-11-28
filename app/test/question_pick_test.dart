import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/question_parts.dart';
import 'package:nushi/question_pick_bar.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// A pick and its note (agreed with the owner, 2026-11-28): a click picks
// and never sends, Return or Send does; a digit sends at once only while
// the box is empty; ↑/↓ move the pick from the card and from the box; Esc
// unpicks; a bar under the box quotes the pick, and Send never moves.

Field _format({bool many = false}) => Field(
  id: 'q0',
  title: 'Format',
  description: 'Which format should the weekly report use?',
  type: many ? FieldType.FIELD_TYPE_CHOICES : FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'PDF', name: 'PDF', description: 'Pages to print'),
    Option(id: 'CSV', name: 'CSV', description: 'Rows for a spreadsheet'),
    Option(id: 'HTML', name: 'HTML', description: 'A page to share'),
  ],
);

/// The box after [_format]: a note on the pick (Claude's), or its text in
/// the pick's place where [replaces] (OpenCode's).
Field _other({bool replaces = false}) => Field(
  id: 'q0_custom',
  title: 'Other',
  type: FieldType.FIELD_TYPE_TEXT,
  otherFor: 'q0',
  note: !replaces,
  replaces: replaces,
);

Field _size() => Field(
  id: 'q1',
  title: 'Size',
  description: 'How long should it be?',
  type: FieldType.FIELD_TYPE_CHOICE,
  options: [
    Option(id: 'short', name: 'short'),
    Option(id: 'long', name: 'long'),
  ],
);

/// A question card and what it sent.
final class _Card {
  new(List<Field> fields)
    : item = Item(
        id: 'q',
        kind: ItemKind.ITEM_KIND_QUESTION,
        status: 'pending',
        text: 'One thing about the report',
        fields: fields,
      );

  final Item item;
  final draft = QuestionDraft();
  final sent = <Map<String, List<String>>>[];

  Map<String, List<String>>? get last => sent.lastOrNull;
  List<String> get picked => draft.picked['q0'] ?? const [];
  TextEditingController get box => draft.text['q0_custom']!;

  Widget build({
    Tokens tokens = Tokens.dark,
    double width = 560,
    bool phone = false,
    double textScale = 1,
  }) {
    Widget card = SizedBox(
      width: width,
      child: RepaintBoundary(
        child: QuestionCard(
          item,
          key: ObjectKey(this), // a new card, a new state
          agent: 'Claude',
          draft: draft,
          onAnswer: (a) async =>
              sent.add({for (final f in a!) f.fieldId: f.values}),
        ),
      ),
    );
    if (phone) card = TouchTargets(child: card);
    return themed(
      tokens: tokens,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [card],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<_Card> _show(
  WidgetTester tester,
  List<Field> fields, {
  void Function(QuestionDraft draft)? given,
  bool phone = false,
}) async {
  final card = _Card(fields);
  given?.call(card.draft);
  await tester.pumpWidget(card.build(phone: phone));
  await tester.pump();
  return card;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

Finder _option(String name) =>
    find.textContaining('$name  ', findRichText: true);

bool _inBox(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

String? _hint(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration?.hintText;

/// Whether [name]'s option stands back (dimmed).
bool _dimmed(WidgetTester tester, String name) => tester
    .widget<QuestionOption>(
      find.ancestor(of: _option(name), matching: find.byType(QuestionOption)),
    )
    .dimmed;

void main() {
  setUpAll(loadFonts);

  testWidgets('a click picks and never sends; a click on the pick unpicks', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other()]);
    await _tap(tester, _option('PDF'));
    expect(card.picked, ['PDF']);
    expect(card.sent, isEmpty);
    expect(find.text('“PDF”'), findsOneWidget, reason: 'the bar quotes it');
    await _tap(tester, _option('CSV'));
    expect(card.picked, ['CSV']);
    await _tap(tester, _option('CSV'));
    expect(card.picked, isEmpty);
    expect(find.byType(PickBar).hitTestable(), findsNothing);
    expect(card.sent, isEmpty);
  });

  testWidgets('a click on a question without a box only picks too', (
    tester,
  ) async {
    final card = await _show(tester, [_format()]);
    await _tap(tester, _option('CSV'));
    expect(card.sent, isEmpty);
    expect(find.byType(PickBar), findsNothing, reason: 'no box to quote for');
    await _tap(tester, find.text('Send'));
    expect(card.last, {
      'q0': ['CSV'],
    });
  });

  testWidgets('Return sends from the card and from the box', (tester) async {
    var card = await _show(tester, [_format(), _other()]);
    await _tap(tester, _option('PDF'));
    await _key(tester, LogicalKeyboardKey.enter);
    expect(card.last, {
      'q0': ['PDF'],
    });

    card = await _show(tester, [_format(), _other()]);
    await _tap(tester, _option('PDF'));
    await tester.enterText(find.byType(TextField), 'landscape');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(card.last, {
      'q0': ['PDF'],
      'q0_custom': ['landscape'],
    });
  });

  testWidgets('a digit sends at once with the box empty, picks with text', (
    tester,
  ) async {
    var card = await _show(tester, [_format(), _other()]);
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(card.last, {
      'q0': ['CSV'],
    });

    card = await _show(tester, [
      _format(),
      _other(),
    ], given: (d) => d.text['q0_custom'] = TextEditingController(text: 'wide'));
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(card.picked, ['CSV']);
    expect(card.sent, isEmpty);
    expect(find.text('With note'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.digit3);
    expect(card.picked, ['HTML'], reason: 'another digit moves the pick');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(card.last, {
      'q0': ['HTML'],
      'q0_custom': ['wide'],
    });
  });

  testWidgets('↑/↓ in the box move the pick, the keys staying there', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other()]);
    await _key(tester, LogicalKeyboardKey.keyW); // into the box
    expect(_inBox(tester), isTrue);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(card.picked, ['PDF']);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(card.picked, ['CSV']);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(card.picked, ['PDF']);
    expect(_inBox(tester), isTrue);
    expect(card.box.text, 'w');
    expect(card.sent, isEmpty);
    // A line above the caret: ↑ is the text's, the pick stays.
    card.box.value = const TextEditingValue(
      text: 'one\ntwo',
      selection: TextSelection.collapsed(offset: 7),
    );
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(card.picked, ['PDF']);
    await _key(tester, LogicalKeyboardKey.arrowDown); // the last line: picks
    expect(card.picked, ['CSV']);
  });

  testWidgets('Esc unpicks, and the text is the answer itself', (tester) async {
    final passed = <LogicalKeyboardKey>[];
    final card = _Card([_format(), _other()]);
    await tester.pumpWidget(
      Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent) passed.add(e.logicalKey);
          return KeyEventResult.handled;
        },
        child: card.build(),
      ),
    );
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.digit1);
    // Sent at once (an empty box); start again with a note.
    card.sent.clear();
    await _key(tester, LogicalKeyboardKey.keyW);
    await _key(tester, LogicalKeyboardKey.escape); // in the box: unpicks
    expect(card.picked, isEmpty);
    expect(_inBox(tester), isTrue, reason: 'the keys stay in the box');
    expect(_hint(tester), 'Other…');
    await _key(tester, LogicalKeyboardKey.escape); // nothing picked: out
    expect(_inBox(tester), isFalse);
    expect(passed, isEmpty);
    await _key(tester, LogicalKeyboardKey.digit2); // text: only picks
    await _key(tester, LogicalKeyboardKey.escape); // on the card: unpicks
    expect(card.picked, isEmpty);
    expect(passed, isEmpty);
    await _key(tester, LogicalKeyboardKey.escape); // nothing: not the card's
    expect(passed, [LogicalKeyboardKey.escape]);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(card.last, {
      'q0_custom': ['w'],
    });
  });

  testWidgets('the bar: the pick quoted, With note, × unpicks', (tester) async {
    final card = await _show(tester, [_format(), _other()]);
    expect(_hint(tester), 'Other…');
    await _tap(tester, _option('CSV'));
    expect(_hint(tester), 'Add context for this pick…');
    expect(find.text('“CSV”'), findsOneWidget);
    expect(find.text('With note'), findsNothing);
    await tester.enterText(find.byType(TextField), 'semicolons');
    await tester.pump();
    expect(find.text('With note'), findsOneWidget);
    for (final o in ['PDF', 'CSV', 'HTML']) {
      expect(_dimmed(tester, o), isFalse, reason: 'picked: nothing dims');
    }
    final unpick = find.descendant(
      of: find.byType(PickBar),
      matching: find.byType(IconTap),
    );
    expect(tester.widget<IconTap>(unpick).tooltip, withKey('Unpick', 'Esc'));
    await _tap(tester, unpick);
    expect(card.picked, isEmpty);
    expect(card.box.text, 'semicolons', reason: 'the text kept');
    for (final o in ['PDF', 'CSV', 'HTML']) {
      expect(_dimmed(tester, o), isTrue, reason: 'the text is the answer');
    }
  });

  group('what is sent is what was sent before', () {
    // For each pick and text, what the card sent before the change (its
    // `_answer`, unchanged): a note goes beside its pick where the agent
    // reads one; where its text replaces the pick, one or the other.
    for (final replaces in [false, true]) {
      final who = replaces ? 'replaces' : 'a note';
      for (final (pick, text, want) in [
        (
          'PDF',
          '',
          {
            'q0': ['PDF'],
          },
        ),
        (
          'PDF',
          'landscape',
          replaces
              ? {
                  'q0': ['PDF'],
                }
              : {
                  'q0': ['PDF'],
                  'q0_custom': ['landscape'],
                },
        ),
        (
          '',
          'landscape',
          {
            'q0_custom': ['landscape'],
          },
        ),
      ]) {
        testWidgets('$who: "$pick" and "$text"', (tester) async {
          final card = await _show(
            tester,
            [_format(), _other(replaces: replaces)],
            given: (d) {
              d.text['q0_custom'] = TextEditingController(text: text);
              if (pick.isNotEmpty) d.picked['q0'] = [pick];
            },
          );
          await _tap(tester, find.text('Send'));
          expect(card.sent, [want]);
        });
      }
    }
  });

  group('Send stays put', () {
    for (final (name, width, phone, scale) in [
      ('wide', 560.0, false, 1.0),
      ('narrow', 340.0, false, 1.0),
      ('larger text', 560.0, false, 1.4),
      ('the phone', 358.0, true, 1.0),
    ]) {
      testWidgets('with and without a pick and text ($name)', (tester) async {
        viewport(tester, const Size(800, 900));
        final card = _Card([_format(), _other()]);
        Future<List<Rect>> places() async {
          await tester.pumpWidget(
            card.build(width: width, phone: phone, textScale: scale),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          return [
            tester.getRect(find.text('Send')),
            tester.getRect(find.widgetWithText(Button, 'Send')),
            tester.getRect(find.byType(TextField)),
            tester.getRect(find.widgetWithText(Button, 'Skip')),
            tester.getRect(find.byType(QuestionCard)),
          ];
        }

        final none = await places();
        card.draft.picked['q0'] = ['CSV'];
        expect(await places(), none, reason: 'picked');
        card.box.text = 'semicolons, not commas, between its fields';
        expect(await places(), none, reason: 'picked, with a note');
        card.draft.picked['q0']!.clear();
        expect(await places(), none, reason: 'text alone');
        expect(find.text('Send'), findsOneWidget, reason: 'its one label');
      });
    }
  });

  testWidgets('several choices: a click toggles, never sends; × clears', (
    tester,
  ) async {
    final card = await _show(tester, [_format(many: true), _other()]);
    await _tap(tester, _option('PDF'));
    expect(find.text('“PDF”'), findsOneWidget);
    await _tap(tester, _option('HTML'));
    expect(card.picked, ['PDF', 'HTML']);
    expect(find.text('2 picked'), findsOneWidget);
    expect(_hint(tester), 'Add context for these picks…');
    expect(card.sent, isEmpty);
    await _key(tester, LogicalKeyboardKey.digit2); // toggles, never sends
    expect(card.picked, ['PDF', 'HTML', 'CSV']);
    expect(card.sent, isEmpty);
    await _tap(
      tester,
      find.descendant(of: find.byType(PickBar), matching: find.byType(IconTap)),
    );
    expect(card.picked, isEmpty);
    await _tap(tester, _option('CSV'));
    await tester.enterText(find.byType(TextField), 'and XML');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(card.last, {
      'q0': ['CSV'],
      'q0_custom': ['and XML'],
    });
  });

  testWidgets('several questions: each its bar, Return on, then Submit', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other(), _size()]);
    expect(find.text('Send'), findsNothing, reason: 'the review submits');
    await _tap(tester, _option('CSV'));
    expect(find.text('Which format should the weekly report use?'), findsOne);
    expect(find.text('“CSV”'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'semicolons');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('How long should it be?'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.digit2); // empty: on, at once
    expect(
      find.textContaining('CSV, semicolons', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('CSV  Note: semicolons', findRichText: true),
      findsOneWidget,
      reason: 'the review: the pick and its note',
    );
    expect(card.sent, isEmpty);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(card.last, {
      'q0': ['CSV'],
      'q0_custom': ['semicolons'],
      'q1': ['long'],
    });
  });

  testWidgets('several questions: a digit with text only picks', (
    tester,
  ) async {
    final card = await _show(tester, [
      _format(),
      _other(),
      _size(),
    ], given: (d) => d.text['q0_custom'] = TextEditingController(text: 'wide'));
    await _key(tester, LogicalKeyboardKey.digit1);
    expect(card.picked, ['PDF']);
    expect(find.text('Which format should the weekly report use?'), findsOne);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.text('How long should it be?'), findsOneWidget);
  });

  testWidgets('the phone: a tap picks, the bar shows, Send sends', (
    tester,
  ) async {
    final card = await _show(tester, [_format(), _other()], phone: true);
    await _tap(tester, _option('HTML'));
    expect(card.sent, isEmpty);
    expect(find.text('“HTML”'), findsOneWidget);
    final unpick = find.descendant(
      of: find.byType(PickBar),
      matching: find.byType(IconTap),
    );
    expect(tester.widget<IconTap>(unpick).tooltip, 'Unpick', reason: 'no key');
    expect(find.text(enterLabel), findsNothing, reason: 'no key hints');
    expect(tester.getSize(unpick).height, greaterThanOrEqualTo(44));
    await _tap(tester, find.text('Send'));
    expect(card.last, {
      'q0': ['HTML'],
    });
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the card: none, a pick, a note, text alone ($name)', (
      tester,
    ) async {
      viewport(tester, const Size(600, 420));
      final card = _Card([_format(), _other()]);
      for (final (state, pick, text) in [
        ('none', false, ''),
        ('pick', true, ''),
        ('note', true, 'landscape pages'),
        ('text', false, 'landscape pages'),
      ]) {
        card.draft
          ..picked['q0'] = [if (pick) 'PDF']
          ..text['q0_custom'] = TextEditingController(text: text);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(card.build(tokens: tokens));
        await tester.pump();
        await expectLater(
          find.byType(QuestionCard),
          matchesGoldenFile('goldens/question_pick_${state}_$name.png'),
        );
      }
    });
  }
}
