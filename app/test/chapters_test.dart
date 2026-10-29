import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat_view.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// A small screenshot, as a message's image.
final Uint8List _shot = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAGAAAAA8CAIAAAAWtijjAAAAh0lEQVR42u3XsQ2AIABEUTayJ1'
  'aMw0AUlk7mAMSCCVyA0GmCvORP8IpLLsQ9aVBAAAgQIECAAAECpC5QvZsGAQIECBAgQIDWBirH'
  '+csAAQI0B5CRFiBAgAABAgQIkAABmgVoy9dnAQIECBAgQIAAAQIECBAgZxWQAAECBAgQIECAAF'
  'EABOjFHhjA0K5ShWj9AAAAAElFTkSuQmCC',
);

/// Three exchanges: text, a list, inline code, tool rows (one failed), a
/// subagent, an image in a message, a message passed to the subagent, the
/// agent going on by itself; and a message waiting in the queue.
final _items = [
  Item(
    id: 'u1',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        'Why does the login page loop after the session expires? It does '
        'this on the button in the screenshot.',
    images: [ImageData(mimeType: 'image/png', data: _shot)],
  ),
  Item(
    id: 'r1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'read',
    title: 'Read auth/redirect.go',
    paths: ['auth/redirect.go'],
    status: 'completed',
  ),
  Item(
    id: 'r2',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'read',
    title: 'Read auth/session.go',
    paths: ['auth/session.go'],
    status: 'completed',
  ),
  Item(
    id: 'a1',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        'It loops because two things meet:\n\n'
        '1. **The cookie stays**: `Session.Valid` is false, but the expired '
        'cookie is still sent.\n'
        '2. **The order**: `RequireLogin` runs before `LoadSession`, so it '
        'redirects before the session is cleared.\n\n'
        'I’d swap the two middlewares. Should I?',
  ),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'yes, and add a test for it',
  ),
  Item(
    id: 'sa',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    agentId: 'ab59',
    title: 'Find the session tests',
    status: 'completed',
    subagent: Subagent(state: 'done'),
  ),
  Item(
    id: 'u4',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'look at the cookie tests too',
    toSubagentName: 'Explore',
    toSubagent: 'sa',
    toSubagentState: 'relayed',
  ),
  Item(
    id: 'e1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'edit',
    title: 'Edit auth/middleware.go',
    paths: ['auth/middleware.go'],
    status: 'completed',
    diffs: [
      FileChange(
        path: 'auth/middleware.go',
        oldText: 'RequireLogin,\nLoadSession,\n',
        newText: 'LoadSession,\nRequireLogin,\n',
      ),
    ],
  ),
  Item(
    id: 'x1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'execute',
    title: 'go test ./auth/...',
    status: 'completed',
  ),
  Item(
    id: 'a2',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text:
        'Done: the session loads first, and `TestExpiredRedirect` covers '
        'it. All 14 tests pass.',
  ),
  Item(
    id: 'u3',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text: 'thanks. what about the logout path?',
  ),
  Item(
    id: 'f1',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'execute',
    title: 'grep -rn Logout web/',
    status: 'failed',
  ),
  Item(
    id: 'a3',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Logout clears the cookie itself, so it can’t loop.',
  ),
  Item(
    id: 'n1',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'own_turn',
    text: 'On its own, after a background task',
  ),
  Item(
    id: 'a4',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The full test suite finished in the background: all 212 pass.',
  ),
];

void main() {
  setUpAll(loadFonts);
  for (final (name, brightness) in [
    ('dark', Brightness.dark),
    ('light', Brightness.light),
  ]) {
    testWidgets('the transcript as chapters ($name)', (tester) async {
      viewport(tester, const Size(1000, 1080), brightness: brightness);
      showDetails.value = false;
      final c = chat('c', 'claude', 'Fix the login redirect');
      final fake = FakeDaemon([c])
        ..answer = (input) => input is GetChatRequest
            ? GetChatResponse(
                chat: c,
                items: _items,
                queue: ChatQueue(
                  messages: [
                    QueuedMessage(id: 'q1', text: 'and the password reset'),
                  ],
                ),
              )
            : null;
      final d = await fake.connect(tester);
      d.select('c');
      await tester.pumpWidget(NushiApp(daemon: d));
      await tester.pumpAndSettle();
      // The image decodes outside the test's fake clock.
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      // No caret blinking in the composer.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // No speaker labels: the bands are the user's.
      for (final who in ['You', 'Claude']) {
        expect(
          find.descendant(
            of: find.byType(Transcript),
            matching: find.text(who),
          ),
          findsNothing,
        );
      }
      await expectLater(
        find.byType(ChatView),
        matchesGoldenFile('goldens/chapters_$name.png'),
      );
      await closeView(tester, d);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  testWidgets('a band goes edge to edge; the agent’s text keeps its '
      'margins', (tester) async {
    viewport(tester, const Size(1000, 860));
    showDetails.value = false;
    final c = chat('c', 'claude', 'Fix the login redirect');
    final fake = FakeDaemon([c])
      ..answer = (input) => input is GetChatRequest
          ? GetChatResponse(chat: c, items: _items)
          : null;
    final d = await fake.connect(tester);
    d.select('c');
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    final view = tester.getRect(find.byType(ChatView));
    final band = tester.getRect(
      find
          .ancestor(
            of: find.textContaining('yes, and add a test', findRichText: true),
            matching: find.byType(Container),
          )
          .last,
    );
    expect(band.left, view.left);
    expect(band.right, view.right);
    final prose = tester.getRect(
      find.textContaining('Logout clears', findRichText: true),
    );
    expect(prose.left, view.left + 20);
    await closeView(tester, d);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
