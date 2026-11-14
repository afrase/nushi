import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

void main() {
  setUpAll(loadFonts);

  // The switch to JSON sits at the left under the fields, Cancel and Add at
  // the right, in the form and in the JSON view.
  testWidgets('the form’s buttons', (tester) async {
    viewport(tester, const Size(900, 900));
    final d = await FakeDaemon([]).connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => mcpForm(context, McpServers.of(d, '/x')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final toggle in ['Edit as JSON', 'Edit in the form']) {
      final field = tester.getRect(find.byType(TextField).first);
      final button = tester.getRect(
        find
            .ancestor(of: find.text(toggle), matching: find.byType(Button))
            .first,
      );
      final add = tester.getRect(
        find
            .ancestor(of: find.text('Add').last, matching: find.byType(Button))
            .first,
      );
      expect(button.left, field.left, reason: toggle);
      expect(add.right, field.right, reason: toggle);
      await tester.tap(find.text(toggle));
      await tester.pumpAndSettle();
    }
    d.dispose();
  });

  // The empty form to look at (`make renders`): its hints a step fainter
  // than a typed value, so an example never reads as typed.
  for (final tokens in [Tokens.dark, Tokens.light]) {
    for (final width in [1700.0, 720.0]) {
      final name = 'mcp_form_${width.toInt()}_${tokens.brightness.name}';
      testWidgets('the empty form, $name', (tester) async {
        viewport(tester, Size(width, 900));
        final d = await FakeDaemon([]).connect(tester);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: NushiTheme(tokens).toThemeData(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Button(
                    label: 'open',
                    onPressed: () => mcpForm(context, McpServers.of(d, '/x')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus(); // the hint, not a caret
        await tester.pumpAndSettle();
        // The command's hint, a step under a typed value (`tokens_test`).
        final hint = tester.widget<Text>(find.text('npx'));
        expect(hint.style?.color, NushiTheme(tokens).t.hint);
        await render(tester, find.byType(MaterialApp), name);
        d.dispose();
      });
    }
  }
}
