import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/disclosure.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/items.dart';
import 'package:nushi/main.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/question_answered.dart';
import 'package:nushi/question_card.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

// An answered question opens to every option it offered (question_answered).

Field _field(
  String id,
  String title,
  String question,
  List<(String, String)> options, {
  bool many = false,
  List<String> values = const [],
}) => Field(
  id: id,
  title: title,
  description: question,
  type: many ? FieldType.FIELD_TYPE_CHOICES : FieldType.FIELD_TYPE_CHOICE,
  options: [
    for (final (name, about) in options)
      Option(id: name.toLowerCase(), name: name, description: about),
  ],
  values: values,
);

/// Claude's free-text "Other" for [of], with what was typed.
Field _other(String of, [List<String> values = const []]) => Field(
  id: '${of}_custom',
  title: 'Other',
  type: FieldType.FIELD_TYPE_TEXT,
  otherFor: of,
  values: values,
);

Field _database({List<String> values = const ['sqlite']}) => _field(
  'question_0',
  'Database',
  'Which database should the service keep its jobs in?',
  [
    ('Postgres', 'The team runs it already; one more schema'),
    ('SQLite', 'A file beside the binary, nothing to run'),
    ('Redis', 'Fast, but the jobs must survive a restart'),
  ],
  values: values,
);

List<Field> _checks() => [
  _field(
    'question_1',
    'Checks',
    'Which checks should run before every push?',
    [
      ('Lint', 'golangci-lint and flutter analyze'),
      ('Tests', 'The Go and app suites'),
      ('Build', 'flutter build macos'),
    ],
    many: true,
    values: ['lint', 'tests'],
  ),
  _other('question_1', ['the golden diff']),
];

List<Field> _deploy() => [
  _field('question_2', 'Deploy', 'Where should it deploy first?', [
    ('Staging', 'The shared staging cluster'),
    ('Production', 'Straight to users'),
  ]),
  _other('question_2', ['a Raspberry Pi on my desk']),
];

Item _item(
  List<Field> fields, {
  String id = 'q',
  String status = 'answered',
  String text = 'A few things before I start',
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: status,
  text: text,
  fields: fields,
);

Item _single() => _item([_database()], text: 'Where should the jobs live?');
Item _many() => _item(_checks(), id: 'q2', text: 'What should guard a push?');
Item _three() => _item([_database(), ..._checks(), ..._deploy()], id: 'q3');
Item _skipped() => _item(
  [_database(values: const []), _other('question_0')],
  id: 'q4',
  status: 'declined',
  text: 'Which database?',
);

/// [item]'s card on its own, [width] wide.
Widget _card(
  Item item, {
  Tokens tokens = Tokens.dark,
  double width = 560,
  bool? still,
}) => themed(
  tokens: tokens,
  still: still,
  Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        // Its own layer, so a golden is the card alone.
        child: RepaintBoundary(
          child: QuestionCard(
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

Finder _rich(String text) => find.textContaining(text, findRichText: true);

/// The chevron of the card titled [title].
Finder _chevronOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(QuestionCard)),
  matching: find.byType(TurnChevron),
);

Future<void> _toggle(WidgetTester tester, [String? title]) async {
  await tester.tap(
    title == null ? find.byType(TurnChevron) : _chevronOf(title),
  );
  await tester.pumpAndSettle();
}

/// The app on a chat holding [items], [width] wide.
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester,
  List<Item> items, {
  double width = 1700,
  double height = 1000,
  Brightness brightness = Brightness.dark,
}) async {
  showDetails.value = false;
  final c = chat('c', 'claude', 'Set up the job runner');
  final fake = FakeDaemon([c])
    ..chatItems['c'] = [
      Item(
        id: 'u',
        kind: ItemKind.ITEM_KIND_USER_MESSAGE,
        text: 'Set up the job runner, and ask me what you need',
      ),
      ...items,
    ];
  final d = await openApp(
    tester,
    fake,
    size: Size(width, height),
    brightness: brightness,
  );
  return (d, fake);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('closed it is the answers; open, every option, the pick '
      'marked', (tester) async {
    await tester.pumpWidget(_card(_single()));
    await tester.pumpAndSettle();
    expect(_rich('SQLite'), findsOneWidget); // the answered line
    expect(find.text('Postgres', findRichText: true), findsNothing);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);

    await _toggle(tester);
    for (final o in ['Postgres', 'SQLite', 'Redis']) {
      expect(_rich(o), findsOneWidget, reason: '$o, offered');
    }
    expect(_rich('A file beside the binary'), findsOneWidget);
    expect(_rich('Which database should the service'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    // The pick in the text's ink; the rest muted, but there.
    const t = Tokens.dark;
    Color ink(String name) =>
        ((tester.widget<RichText>(_rich(name)).text as TextSpan).children!.first
                as TextSpan)
            .style!
            .color!;
    expect(ink('SQLite'), t.text);
    expect(ink('Postgres'), t.textMuted);
    // In the order offered.
    expect(
      tester.getTopLeft(_rich('Postgres')).dy,
      lessThan(tester.getTopLeft(_rich('SQLite')).dy),
    );
    expect(
      tester.getTopLeft(_rich('SQLite')).dy,
      lessThan(tester.getTopLeft(_rich('Redis')).dy),
    );

    await _toggle(tester);
    expect(find.text('Postgres', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many choices and an Other answer: each pick checked, what '
      'was typed beside Other', (tester) async {
    await tester.pumpWidget(_card(_many()));
    await tester.pumpAndSettle();
    await _toggle(tester);
    // Lint, Tests and Other checked; Build not.
    expect(find.byIcon(Icons.check_box), findsNWidgets(3));
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    final other = _rich('the golden diff');
    expect(other, findsOneWidget);
    expect(
      (tester.widget<RichText>(other).text as TextSpan).toPlainText(),
      startsWith('Other  the golden diff'),
    );
  });

  testWidgets('several questions, one under another, each with its header, '
      'no tabs', (tester) async {
    await tester.pumpWidget(_card(_three()));
    await tester.pumpAndSettle();
    await _toggle(tester);
    final tops = [
      for (final h in ['Database', 'Checks', 'Deploy'])
        tester.getTopLeft(find.text(h)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('Submit'), findsNothing);
    expect(_rich('a Raspberry Pi on my desk'), findsOneWidget);
    // Database's SQLite, Deploy's Other; Checks' three.
    expect(find.byIcon(Icons.radio_button_checked), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box), findsNWidgets(3));
  });

  for (final (status, words) in [
    ('declined', 'Skipped'),
    ('cancelled', 'Cancelled'),
  ]) {
    testWidgets('$words: it still says so, and opens to what was offered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          _item([
            _database(values: const []),
            _other('question_0'),
          ], status: status),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(words), findsOneWidget);
      await _toggle(tester);
      expect(find.text(words), findsOneWidget);
      for (final o in ['Postgres', 'SQLite', 'Redis', 'Other']) {
        expect(_rich(o), findsOneWidget, reason: '$o, offered');
      }
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    });
  }

  testWidgets('an item that kept no options has nothing to open', (
    tester,
  ) async {
    final item = _item([
      Field(
        id: 'question_0',
        title: 'Name',
        type: FieldType.FIELD_TYPE_TEXT,
        values: ['jobs'],
      ),
    ]);
    expect(AnsweredQuestion.opens(item), isFalse);
    await tester.pumpWidget(_card(item));
    await tester.pumpAndSettle();
    expect(find.byType(TurnChevron), findsNothing);
    expect(find.byType(Tap), findsNothing, reason: 'nothing to press');
    expect(_rich('jobs'), findsOneWidget);
  });

  testWidgets('the chevron stays put as the card opens and closes', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_three()));
    await tester.pumpAndSettle();
    final closed = tester.getRect(find.byType(TurnChevron));
    await tester.tap(find.text('A few things before I start'));
    await tester.pump();
    await tester.pump(Motion.standard ~/ 2);
    expect(tester.getRect(find.byType(TurnChevron)).center, closed.center);
    await tester.pumpAndSettle();
    expect(find.text('Deploy'), findsOneWidget, reason: 'the title opens it');
    expect(tester.getRect(find.byType(TurnChevron)), closed);
    await _toggle(tester);
    expect(tester.getRect(find.byType(TurnChevron)), closed);
  });

  testWidgets('Enter and Space on the header open and close it', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_single()));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_rich('Postgres'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Postgres', findRichText: true), findsNothing);
  });

  testWidgets('with Reduce Motion it opens at once', (tester) async {
    await tester.pumpWidget(_card(_single(), still: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TurnChevron));
    await tester.pump();
    expect(_rich('Postgres'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('open, its options answer nothing: no request, no change', (
    tester,
  ) async {
    final (d, fake) = await _app(tester, [_three()]);
    await _toggle(tester, 'A few things before I start');
    final marks = tester.widgetList<Icon>(find.byType(Icon)).toList();
    for (final o in ['Postgres', 'Redis', 'Build', 'Staging', 'Other']) {
      final at = _rich(o).first;
      // Not a control: no row to press, no hand, no tint.
      expect(
        find.ancestor(of: at, matching: find.byType(Tap)),
        findsNothing,
        reason: o,
      );
      await tester.tap(at, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    expect(fake.calls.whereType<AnswerQuestionRequest>(), isEmpty);
    expect(
      tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon),
      marks.map((i) => i.icon),
    );
    expect(_rich('Postgres'), findsOneWidget, reason: 'still open');
    await closeView(tester, d);
  }, variant: onMac);

  testWidgets('open in a 360-wide card, nothing overflows', (tester) async {
    await tester.pumpWidget(_card(_three(), width: 360));
    await tester.pumpAndSettle();
    await _toggle(tester);
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(QuestionCard));
    for (final text in tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(QuestionCard),
        matching: find.byType(RichText),
      ),
    )) {
      final rect = tester.getRect(find.byWidget(text));
      expect(rect.right, lessThanOrEqualTo(card.right), reason: '$text');
    }
  });

  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('the answered card, closed and open ($name)', (tester) async {
      viewport(tester, const Size(600, 640));
      await tester.pumpWidget(_card(_three(), tokens: tokens));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_answered_closed_$name.png'),
      );
      await _toggle(tester);
      await expectLater(
        find.byType(QuestionCard),
        matchesGoldenFile('goldens/question_answered_open_$name.png'),
      );
    });

    final brightness = name == 'dark' ? Brightness.dark : Brightness.light;
    for (final width in [1700.0, 720.0]) {
      final w = width.toInt();
      if (!lightCopy(tokens.brightness)) {
        testWidgets('renders at $w ($name)', (tester) async {
          final (d, _) = await _app(
            tester,
            [_single(), _many(), _three(), _skipped()],
            width: width,
            height: 1100,
            brightness: brightness,
          );
          await render(
            tester,
            find.byType(NushiApp),
            'question_closed_${w}_$name',
          );
          // Each opened alone, scrolled to.
          for (final (what, title) in [
            ('single', 'Where should the jobs live?'),
            ('many', 'What should guard a push?'),
            ('three', 'A few things before I start'),
            ('skipped', 'Which database?'),
          ]) {
            final chevron = _chevronOf(title);
            await tester.ensureVisible(chevron);
            await tester.pumpAndSettle();
            await tester.tap(chevron);
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.ancestor(of: chevron, matching: find.byType(QuestionCard)),
            );
            await tester.pumpAndSettle();
            expectTextInside(tester, width);
            await render(
              tester,
              find.byType(NushiApp),
              'question_open_${what}_${w}_$name',
            );
            await tester.tap(chevron);
            await tester.pumpAndSettle();
          }
          await closeView(tester, d);
        }, variant: onMac);
      }
    }
  }

  testWidgets('the phone: the header is a finger’s target, and it opens', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), ratio: 2);
    final c = chat('c', 'claude', 'Set up the job runner');
    final fake = FakeDaemon([c])..chatItems['c'] = [_three()];
    final phone = await startPhone(tester, fake);
    await tester.tap(find.text('Set up the job runner'));
    await tester.pumpAndSettle();
    final header = find.ancestor(
      of: _chevronOf('A few things before I start'),
      matching: find.byType(GestureDetector),
    );
    expect(tester.getSize(header.first).height, greaterThanOrEqualTo(44));
    await render(tester, find.byType(PhoneApp), 'question_phone_closed');
    await _toggle(tester, 'A few things before I start');
    expect(_rich('a Raspberry Pi on my desk'), findsOneWidget);
    expectTextInside(tester, 390);
    await render(tester, find.byType(PhoneApp), 'question_phone_open');
    expect(fake.calls.whereType<AnswerQuestionRequest>(), isEmpty);
    await endPhone(tester, phone);
  });

  testWidgets('a question keeps a draft in its chat only while it waits', (
    tester,
  ) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')..agent = 'claude';
    Item asked(String status) => Item(
      id: 'q',
      kind: ItemKind.ITEM_KIND_QUESTION,
      status: status,
      fields: [
        if (status == 'pending') _database(values: const []) else _database(),
      ],
    );
    Future<void> show(String status) async {
      await tester.pumpWidget(
        themed(ItemView(asked(status), chat, d, live: false, still: true)),
      );
      await tester.pumpAndSettle();
    }

    await show('answered'); // from the chat's history
    expect(chat.answers, isEmpty);
    await show('pending');
    expect(chat.answers.keys, ['q']);
    await show('cancelled'); // ended with its turn: nothing to keep
    expect(chat.answers, isEmpty);
    await closeView(tester, d);
  });
}
