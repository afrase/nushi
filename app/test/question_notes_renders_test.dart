import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/question_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A question card waiting in a chat, in each of its states (nothing
/// picked, a pick, a pick with a note, text alone), at the Mac's sizes and
/// the phone's, in both themes; QUESTION_STAGE (`before` or `after`) leads
/// each picture's name.
void main() {
  setUpAll(loadFonts);
  rendersOnly();

  for (final b in Brightness.values) {
    for (final width in [1700.0, 720.0]) {
      for (final state in _State.values) {
        renderTest('${state.name}, ${width.toInt()} (${b.name})', (
          tester,
        ) async {
          final fake = FakeDaemon([chat('c', 'claude', 'Resume the import')])
            ..chatItems['c'] = _transcript;
          final d = await openApp(
            tester,
            fake,
            size: Size(width, 760),
            brightness: b,
          );
          await state.make(tester);
          await tester.pumpAndSettle();
          expectTextInside(tester, width);
          await render(
            tester,
            find.byType(NushiApp),
            '${_stage}_${width.toInt()}_${state.name}_${b.name}',
          );
          await closeView(tester, d);
        }, variant: onMac);
      }
    }

    for (final (size, states) in [
      (const Size(390, 844), _State.values),
      (const Size(430, 932), [_State.note]),
      (const Size(844, 390), [_State.note]),
    ]) {
      for (final state in states) {
        final name = '${size.width.toInt()}x${size.height.toInt()}';
        renderTest('the phone, ${state.name}, $name (${b.name})', (
          tester,
        ) async {
          viewport(tester, size, ratio: 2, brightness: b);
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final fake = FakeDaemon([
            chat('c', 'claude', 'Resume the import', status: _waiting),
          ])..chatItems['c'] = _transcript;
          final phone = await startPhone(tester, fake);
          await tester.tap(find.text('Resume the import'));
          await tester.pumpAndSettle();
          await state.make(tester);
          await tester.pumpAndSettle();
          // The chat at its end, the card's foot in sight.
          await tester.dragFrom(
            Offset(size.width / 2, 150),
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
          await render(
            tester,
            find.byType(PhoneApp),
            '${_stage}_phone_${name}_${state.name}_${b.name}',
          );
          await endPhone(tester, phone);
        });
      }
    }
  }
}

/// `before` or `after` the change, as QUESTION_STAGE says.
final String _stage = Platform.environment['QUESTION_STAGE'] ?? 'after';

final _waiting = ChatStatus(busy: true, waiting: true);

/// A card's state, made as a user would: a note typed, then the pick, so
/// a card that sends on a pick (before the change) shows the same.
enum _State {
  none,
  pick,
  note,
  text;

  Future<void> make(WidgetTester tester) async {
    final card = find.byType(QuestionCard);
    if (this == note || this == text) {
      await tester.enterText(
        find.descendant(of: card, matching: find.byType(TextField)),
        'only if a failed run can resume',
      );
      await tester.pump();
    }
    if (this == pick || this == note) {
      final option = find.descendant(
        of: card,
        matching: find.textContaining('own table', findRichText: true),
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pump();
    }
  }
}

final List<Item> _transcript = [
  userSays('u', 'Make the importer resume where a failed run stopped.'),
  agentSays('m', 'It keeps no checkpoints yet. One thing first:'),
  Item(
    id: 'q',
    kind: ItemKind.ITEM_KIND_QUESTION,
    status: 'pending',
    text: 'Where to keep checkpoints',
    fields: [
      Field(
        id: 'question_0',
        title: 'Checkpoints',
        description: 'Where should the importer keep its checkpoints?',
        type: FieldType.FIELD_TYPE_CHOICE,
        options: [
          Option(
            id: 'table',
            name: "In the job's own table",
            description: 'One place to look, moves with the data',
          ),
          Option(
            id: 'file',
            name: 'In a file beside the export',
            description: 'Easy to inspect, easy to lose',
          ),
          Option(
            id: 'none',
            name: 'Nowhere, start over each run',
            description: 'Simplest, slow on large exports',
          ),
        ],
      ),
      Field(
        id: 'question_0_custom',
        title: 'Other',
        type: FieldType.FIELD_TYPE_TEXT,
        otherFor: 'question_0',
        note: true,
      ),
    ],
  ),
];
