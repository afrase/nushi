import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_calls.dart';
import 'package:nushi/transcript.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Item _call(String status) => Item(
  id: 'x',
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: 'execute',
  title: 'make test-app SHARD=1/2',
  status: status,
);

Widget _app(Widget child, {Tokens tokens = Tokens.dark, bool still = false}) =>
    MaterialApp(
      theme: NushiTheme(tokens).toThemeData(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    );

/// The opacity [text]'s item is drawn at, as it rises in.
double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  setUpAll(loadFonts);

  testWidgets('a running call shines, without a spinner; a finished one '
      'shows neither', (tester) async {
    await tester.pumpWidget(_app(ToolCallView(_call('in_progress'))));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(_app(ToolCallView(_call('completed'))));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('with Reduce Motion a running call is plain text', (
    tester,
  ) async {
    Shine.stopAt = null; // as in the app: it would tick
    addTearDown(() => Shine.stopAt = 0);
    await tester.pumpWidget(
      _app(ToolCallView(_call('in_progress')), still: true),
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text(r'$ make test-app SHARD=1/2'), findsOneWidget);
    // Nothing ticks: it settles.
    await tester.pumpAndSettle();
  });

  testWidgets('a new item rises in; what the chat loaded with is there at '
      'once', (tester) async {
    final d = await FakeDaemon([]).connect(tester);
    final chat = ChatState('c', '/x')
      ..loaded = true
      ..items.add(
        Item(id: 'a1', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'Loaded'),
      );
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: chat,
          builder: (context, _) =>
              Transcript(chat: chat, daemon: d, onReply: null),
        ),
      ),
    );
    expect(_opacity(tester, 'Loaded'), 1);

    chat
      ..items.add(
        Item(id: 'a2', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: 'New'),
      )
      ..notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_opacity(tester, 'New'), inExclusiveRange(0, 1));
    expect(_opacity(tester, 'Loaded'), 1);
    await tester.pumpAndSettle();
    expect(_opacity(tester, 'New'), 1);

    await closeView(tester, d);
  });

  // Enlarged, so the band shows; stopped mid-sweep.
  testWidgets('golden, a running call, still, dark', (tester) async {
    Shine.stopAt = 0.4;
    addTearDown(() => Shine.stopAt = 0);
    viewport(tester, const Size(360, 52), ratio: 3);
    await tester.pumpWidget(_app(ToolCallView(_call('in_progress'))));
    await expectLater(
      find.byType(ToolCallView),
      matchesGoldenFile('goldens/shine_running_dark.png'),
    );
  });
}
