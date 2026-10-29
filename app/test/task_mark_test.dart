import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/drawn.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/shells.dart';
import 'package:nushi/subagents.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: const NushiTheme(Tokens.dark).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: child),
  ),
);

SubagentRun _run(String state) => (
  call: Item(
    id: 'a',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    agent: 'Explore',
    title: 'find the scroll handling',
    status: state == 'running' ? 'in_progress' : 'completed',
    subagent: Subagent(state: state),
  ),
  items: <Item>[],
);

/// How far the check is drawn, or null without one.
double? _drawn(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<CheckPainter>()
    .firstOrNull
    ?.drawn;

void main() {
  setUpAll(loadFonts);

  testWidgets('a running subagent shines, with no spinner; as it finishes '
      'its check draws itself', (tester) async {
    final chat = ChatState('c', '/x');
    await tester.pumpWidget(_app(SubagentLine(_run('running'), chat)));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(_drawn(tester), isNull);

    await tester.pumpWidget(_app(SubagentLine(_run('done'), chat)));
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_drawn(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_drawn(tester), 1);
  });

  testWidgets('one done before shows its check whole; Reduce Motion too; a '
      'failed one its red mark', (tester) async {
    final chat = ChatState('c', '/x');
    await tester.pumpWidget(_app(SubagentLine(_run('done'), chat)));
    expect(_drawn(tester), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _app(SubagentLine(_run('running'), chat), still: true),
    );
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpWidget(
      _app(SubagentLine(_run('done'), chat), still: true),
    );
    expect(_drawn(tester), 1);

    await tester.pumpWidget(_app(SubagentLine(_run('failed'), chat)));
    expect(find.byIcon(Icons.error_outline), findsWidgets);
  });

  testWidgets("a background command's words shine while it runs, and its "
      'check draws as it ends', (tester) async {
    Item shell(String state) => Item(
      id: 's',
      kind: ItemKind.ITEM_KIND_TOOL_CALL,
      title: 'go test ./...',
      shell: Shell(state: state),
    );
    Widget row(Item it) => Builder(
      builder: (context) => Row(
        children: [
          Expanded(child: shellStateText(context, it, const TextStyle())),
          shellMark(it),
        ],
      ),
    );
    await tester.pumpWidget(_app(row(shell('running'))));
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(_app(row(shell('done'))));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_drawn(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_drawn(tester), 1);
  });
}
