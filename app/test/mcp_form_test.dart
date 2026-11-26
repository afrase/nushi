import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
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
            onPressed: () =>
                mcpForm(context, McpServers.of(d, '/x', agent: 'claude')),
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

  testWidgets('an OAuth server with hidden parts says beside its URL that '
      'they are changed in Edit as JSON; one without says nothing', (
    tester,
  ) async {
    viewport(tester, const Size(900, 900));
    final d = await FakeDaemon([]).connect(tester);
    const note =
        'Its OAuth settings have hidden parts: change them in Edit as JSON.';
    for (final (oauth, shown) in [
      ('{"authServerMetadataUrl":"https://login.example.com/••••/meta"}', true),
      ('{"callbackPort":8765}', false),
    ]) {
      final server = McpServer(
        name: 'wiki',
        scope: 'user',
        configJson:
            '{"type":"http","url":"https://wiki.example.com/mcp",'
            '"oauth":$oauth}',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => mcpForm(
                context,
                McpServers.of(d, '/x', agent: 'claude'),
                server: server,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(note), shown ? findsOneWidget : findsNothing);
      if (shown) {
        // Right under the URL's field, before the headers.
        final url = tester.getRect(find.byType(TextField).at(1));
        final said = tester.getRect(find.text(note));
        expect(said.top, greaterThanOrEqualTo(url.bottom));
        expect(said.top, lessThan(tester.getRect(find.text('Headers')).top));
        await tester.tap(find.text('Edit as JSON'));
        await tester.pumpAndSettle();
        expect(find.text(note), findsNothing);
      }
      await tester.tap(find.text('Cancel'));
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
                    onPressed: () => mcpForm(
                      context,
                      McpServers.of(d, '/x', agent: 'claude'),
                    ),
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

  // A repository's .mcp.json is anyone's: a value of the wrong type is
  // shown as what it is, never a cast that throws in a row's build.
  test('a config of the wrong shape reads, never throws', () {
    final c = config(
      McpServer(
        configJson: '{"type":1,"url":1,"args":"x","env":"y","headers":[1]}',
      ),
    );
    expect(transport(c), 'http'); // it has a url
    expect(target(c), '1');
    expect(secrets(c), '');
    final stdio = config(
      McpServer(configJson: '{"command":["a"],"args":"--x"}'),
    );
    expect(transport(stdio), 'stdio');
    expect(target(stdio), '[a] --x');
    expect(config(McpServer(configJson: '[1]')), isEmpty);
    expect(config(McpServer(configJson: 'not json')), isEmpty);
  });

  testWidgets('editing a server of the wrong shape opens its JSON', (
    tester,
  ) async {
    viewport(tester, const Size(900, 900));
    final d = await FakeDaemon([]).connect(tester);
    final server = McpServer(
      name: 'odd',
      scope: 'project',
      configJson: '{"url":1,"env":"x"}',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => mcpForm(
              context,
              McpServers.of(d, '/x', agent: 'claude'),
              server: server,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Edit in the form'), findsOneWidget); // the JSON view
    expect(find.textContaining('"url": 1'), findsOneWidget);
    d.dispose();
  });
}
