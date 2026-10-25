import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/mcp_form.dart';
import 'package:nushi/mcp_servers.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';

void main() {
  setUpAll(loadFonts);

  // The switch to JSON sits at the left under the fields, Cancel and Add at
  // the right, in the form and in the JSON view.
  testWidgets('the form’s buttons', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    final d = await FakeDaemon([]).connect(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: NushiTheme(Tokens.dark).toThemeData(),
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
}
