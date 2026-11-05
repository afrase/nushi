import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/attached_files.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_text.dart';

import 'fake_daemon.dart';
import 'harness.dart';

ImageData _image(int b) =>
    ImageData(mimeType: 'image/png', data: Uint8List.fromList([b]));

AttachedFile _file(String name) =>
    AttachedFile(name: name, size: 1, path: '/tmp/$name');

RunOutput _output(String key, String text) =>
    (key: key, command: 'ls', exit: 0, lines: 1, text: text);

/// A draft with something in every field of a message.
Draft _full() {
  final d = Draft()
    ..text.text = '  Look at @lib/a.dart  '
    ..mentions.add('lib/a.dart')
    ..replies.value = [(quote: 'q1', text: 'r1', from: 'Changes')]
    ..images.value = [_image(1)]
    ..files.value = [_file('a.txt')]
    ..outputs.value = [_output('k1', 'one')]
    ..toSubagent.value = ('call1', 'Explore');
  return d;
}

void main() {
  testWidgets('what is written outlives the box, and a take-back lands in it', (
    tester,
  ) async {
    final daemon = Daemon();
    final chat = ChatState('c', '/tmp');
    Future<void> show({required bool box}) => tester.pumpWidget(
      themed(
        box ? Composer(chat: chat, daemon: daemon) : const Text('Changes'),
      ),
    );
    await show(box: true);
    await tester.enterText(find.byType(TextField), 'half a thought');
    await show(box: false); // a peek at Changes, or another chat
    chat.takeBack.value = QueuedMessage(text: 'taken back');
    await show(box: true);
    expect(chat.draft.text.text, 'half a thought\n\ntaken back');
    expect(find.text('half a thought\n\ntaken back'), findsOneWidget);
    await show(box: false);
    daemon.dispose(); // its ping timer
    await tester.pump(const Duration(seconds: 4)); // and the ping's timeout
  });

  testWidgets('a message for a subagent taken back while the box was away '
      'lands in it with its note', (tester) async {
    final daemon = Daemon();
    // Stop took back a replayed message (which subagent isn't known) while
    // the user was on Changes: the box isn't built.
    final chat = ChatState('c', '/tmp')
      ..takeBack.value = QueuedMessage(
        text: 'Look at the tests too',
        toSubagentName: 'Explore',
      );
    await tester.pumpWidget(themed(Composer(chat: chat, daemon: daemon)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(chat.draft.text.text, 'Look at the tests too');
    expect(
      find.text('This message was for Explore: send it from its pane.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    daemon.dispose(); // its ping timer
    await tester.pump(const Duration(seconds: 4)); // and the ping's timeout
  });

  test(
    "a message to a subagent is kept under the draft's older key, relay",
    () {
      final saved = (Draft()..toSubagent.value = ('call1', 'Explore')).toJson();
      expect(saved['relay'], ['call1', 'Explore']);
      final back = Draft()
        ..restore({
          'relay': ['call1', 'Explore'],
        });
      expect(back.toSubagent.value, ('call1', 'Explore'));
    },
  );

  group("a draft's message", () {
    test('is there with any one of its fields, not a quote or a '
        "subagent's box", () {
      expect(Draft().hasMessage, isFalse);
      expect((Draft()..text.text = '  \n').hasMessage, isFalse);
      expect((Draft()..text.text = 'hi').hasMessage, isTrue);
      expect((Draft()..images.value = [_image(1)]).hasMessage, isTrue);
      expect((Draft()..files.value = [_file('a.txt')]).hasMessage, isTrue);
      expect(
        (Draft()..replies.value = [(quote: 'q', text: 't', from: 'f')])
            .hasMessage,
        isTrue,
      );
      expect((Draft()..outputs.value = [_output('k', 'x')]).hasMessage, isTrue);
      expect((Draft()..quote.value = 'quoted').hasMessage, isFalse);
      final sub = Draft()..subagentBox('call1').text = 'for it';
      expect(sub.hasMessage, isFalse);
      expect(sub.isEmpty, isFalse);
    });

    test('taken, it is all of it, and the box is empty', () {
      final d = _full();
      final m = d.take();
      expect(m.text, 'Look at @lib/a.dart');
      expect(m.mentions, {'lib/a.dart'});
      expect(m.replies, [(quote: 'q1', text: 'r1', from: 'Changes')]);
      expect(m.images, [_image(1)]);
      expect(m.files, [_file('a.txt')]);
      expect(m.outputs, [_output('k1', 'one')]);
      expect(m.toSubagent, ('call1', 'Explore'));
      expect(d.text.text, '');
      expect(d.mentions, isEmpty);
      expect(d.replies.value, isEmpty);
      expect(d.images.value, isEmpty);
      expect(d.files.value, isEmpty);
      expect(d.outputs.value, isEmpty);
      expect(d.toSubagent.value, isNull);
      expect(d.hasMessage, isFalse);
    });

    test('put back into an empty box, it is as it was', () {
      final d = _full();
      d.putBack(d.take());
      expect(d.text.text, 'Look at @lib/a.dart');
      expect(d.mentions, {'lib/a.dart'});
      expect(d.replies.value, [(quote: 'q1', text: 'r1', from: 'Changes')]);
      expect(d.images.value, [_image(1)]);
      expect(d.files.value, [_file('a.txt')]);
      expect(d.outputs.value, [_output('k1', 'one')]);
      expect(d.toSubagent.value, ('call1', 'Explore'));
    });

    test('put back, it goes before what was written since', () {
      final d = _full();
      final m = d.take();
      d
        ..text.text = ' typed since '
        ..mentions.add('lib/b.dart')
        ..replies.value = [(quote: 'q2', text: 'r2', from: 'Changes')]
        ..images.value = [_image(2)]
        // The same file again, and another.
        ..files.value = [_file('b.txt'), _file('a.txt')]
        // The same run's output again (newer), and another's.
        ..outputs.value = [_output('k1', 'newer'), _output('k2', 'two')]
        ..toSubagent.value = ('call2', 'Plan')
        ..putBack(m);
      expect(d.text.text, 'Look at @lib/a.dart\n\ntyped since');
      expect(d.mentions, {'lib/a.dart', 'lib/b.dart'});
      expect(d.replies.value, [
        (quote: 'q1', text: 'r1', from: 'Changes'),
        (quote: 'q2', text: 'r2', from: 'Changes'),
      ]);
      expect(d.images.value, [_image(1), _image(2)]);
      expect(d.files.value, [_file('a.txt'), _file('b.txt')]);
      expect(d.outputs.value, [_output('k1', 'newer'), _output('k2', 'two')]);
      // A subagent picked since stays.
      expect(d.toSubagent.value, ('call2', 'Plan'));
    });
  });

  testWidgets('a send that fails puts every field back in the box', (
    tester,
  ) async {
    viewport(tester, const Size(640, 260));
    final send = Completer<SendPromptResponse>();
    final sent = <SendPromptRequest>[];
    final fake = FakeDaemon([])
      ..answer = (input) {
        if (input is! SendPromptRequest) return null;
        sent.add(input);
        return send.future;
      };
    final d = await fake.connect(tester);
    final chat = ChatState('c', '/tmp')
      ..agent = 'claude'
      ..loaded = true;
    d.chats['c'] = chat;
    final draft = chat.draft
      ..text.text = 'Look at @lib/a.dart'
      ..mentions.add('lib/a.dart')
      ..replies.value = [(quote: 'q1', text: 'r1', from: 'Changes')]
      ..images.value = [_image(1)]
      ..files.value = [_file('a.txt')]
      ..outputs.value = [_output('k1', 'one')]
      ..toSubagent.value = ('call1', 'Explore');
    await tester.pumpWidget(themed(Composer(chat: chat, daemon: d)));
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent.single.toSubagent, 'call1');
    // The file in the chat's folder goes by its path in it.
    expect(sent.single.files, ['lib/a.dart', 'a.txt']);
    expect(draft.hasMessage, isFalse);
    send.completeError(ConnectException(Code.internal, 'no agent'));
    await tester.pump();
    await tester.pump();
    expect(draft.text.text, 'Look at @lib/a.dart');
    expect(draft.mentions, {'lib/a.dart'});
    expect(draft.replies.value, [(quote: 'q1', text: 'r1', from: 'Changes')]);
    expect(draft.images.value, [_image(1)]);
    expect(draft.files.value, [_file('a.txt')]);
    expect(draft.outputs.value, [_output('k1', 'one')]);
    expect(draft.toSubagent.value, ('call1', 'Explore'));
    await closeView(tester, d);
  });
}
