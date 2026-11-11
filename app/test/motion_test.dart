import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/spinner.dart';
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
    themed(
      Padding(padding: const EdgeInsets.all(12), child: child),
      tokens: tokens,
      still: still,
    );

/// The opacity [text]'s item is drawn at, as it rises in.
double _opacity(WidgetTester tester, String text) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  setUpAll(loadFonts);

  testWidgets('a running call shines, a spinner at its row’s end (ADR '
      '0111); a finished one shows neither', (tester) async {
    await tester.pumpWidget(_app(ToolCallView(_call('in_progress'))));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(Spinner), findsOneWidget);

    await tester.pumpWidget(_app(ToolCallView(_call('completed'))));
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(Spinner), findsNothing);
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

  testWidgets('a loop ticks $pulseRate times a second while Nushi is in '
      'front, never while it is not, and stops with no one listening', (
    tester,
  ) async {
    var ticks = 0;
    void tick() => ticks++;
    pulseClock.addListener(tick);
    addTearDown(() => pulseClock.removeListener(tick));
    final from = pulseClock.phase(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, pulseRate);
    // Its time is its ticks: a second on.
    expect(
      pulseClock.phase(const Duration(seconds: 10)),
      closeTo((from + 0.1) % 1, 1e-9),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    // Once, for the rest look; then nothing.
    expect(ticks, pulseRate + 1);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, pulseRate + 1);

    // Once as it comes back, then its ticks.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 2 * pulseRate + 2);

    // Gone, it stops: a timer left running would fail the test as it ends.
    pulseClock.removeListener(tick);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 2 * pulseRate + 2);
  });

  testWidgets('while Nushi is not in front, a shine shows its text as it '
      'is, and sweeps again once it is', (tester) async {
    Shine.stopAt = null;
    addTearDown(() => Shine.stopAt = 0);
    await tester.pumpWidget(_app(const Shine(child: Text('Thinking…'))));
    await tester.pump(const Duration(milliseconds: 730));
    BlendMode blend() =>
        tester.widget<ShaderMask>(find.byType(ShaderMask)).blendMode;
    expect(blend(), BlendMode.srcIn);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    expect(loopMoving, isFalse);
    expect(loopPhase(Shine.period), 0);
    await tester.pump();
    expect(blend(), BlendMode.dst);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(blend(), BlendMode.srcIn);
    await tester.pumpWidget(const SizedBox());
  });

  // Enlarged, so the band shows; stopped mid-sweep.
  testWidgets('golden, a running call, still, dark', (tester) async {
    Shine.stopAt = 0.4;
    addTearDown(() => Shine.stopAt = 0);
    viewport(tester, const Size(360, 60), ratio: 3);
    await tester.pumpWidget(_app(ToolCallView(_call('in_progress'))));
    await expectLater(
      find.byType(ToolCallView),
      matchesGoldenFile('goldens/shine_running_dark.png'),
    );
  });
}
