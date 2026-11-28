import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
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

  // Edit as JSON turns into Edit in the form and back without moving: it
  // keeps its width, and the dialog its height in both views, so it, Cancel
  // and Add keep their whole rects, for each kind of server, added or
  // edited (one the form can't show opens in its JSON), in a large window
  // and a small one; what was typed carries over each way.
  for (final size in const [Size(1700, 900), Size(720, 600)]) {
    for (final editing in [false, true]) {
      for (final kind in ['stdio', 'http', 'sse', if (editing) 'odd']) {
        final place =
            '${editing ? 'editing' : 'adding'} $kind, '
            '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('Edit as JSON and Edit in the form stay put, $place', (
          tester,
        ) async {
          for (final b in renderThemes) {
            await _switchesInPlace(tester, b, size, kind, editing: editing);
          }
        });
      }
    }
  }

  // The view not shown is laid out for its height alone: none of its
  // fields can take the focus, Tab never reaches one, and a screen reader
  // reads none of it.
  testWidgets('the view not shown takes no focus and says nothing', (
    tester,
  ) async {
    viewport(tester, const Size(1700, 900));
    final semantics = tester.ensureSemantics();
    final d = await FakeDaemon([]).connect(tester);
    await _open(tester, Brightness.dark, d);
    for (final (shown, hidden, toggle) in [
      ('Transport', 'Config', 'Edit as JSON'),
      ('Config', 'Transport', 'Edit in the form'),
    ]) {
      // The fields of the view not shown: in the tree, off stage.
      final onStage = find.byType(EditableText).evaluate().toSet();
      final unseen = find
          .byType(EditableText, skipOffstage: false)
          .evaluate()
          .where((e) => !onStage.contains(e))
          .toList();
      expect(onStage, isNotEmpty, reason: shown);
      expect(unseen, isNotEmpty, reason: shown);
      for (final e in unseen) {
        final node = (e.widget as EditableText).focusNode;
        expect(node.canRequestFocus, isFalse, reason: shown);
      }
      // Tab round the dialog, twice over: never into the view not shown.
      final reached = <FocusNode>{};
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        reached.add(FocusManager.instance.primaryFocus!);
      }
      for (final e in unseen) {
        final node = (e.widget as EditableText).focusNode;
        expect(reached, isNot(contains(node)), reason: shown);
        expect(node.hasFocus, isFalse, reason: shown);
      }
      expect(find.semantics.byLabel(shown), findsOne, reason: shown);
      expect(find.semantics.byLabel(hidden), findsNothing, reason: shown);
      await tester.tap(_button(toggle));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
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
        // Kept with the form's fields, under the JSON's box, unseen.
        expect(find.text(note), findsNothing);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    d.dispose();
  });

  // Add, and Save when editing, keep their width while they read Saving…,
  // so Cancel beside them stays put.
  for (final editing in [false, true]) {
    final idle = editing ? 'Save' : 'Add';
    testWidgets('$idle keeps its width while it reads Saving…', (tester) async {
      viewport(tester, const Size(900, 900));
      final held = Completer<Object>();
      final fake = FakeDaemon([])
        ..answer = (input) =>
            input is AddMcpServerRequest || input is EditMcpServerRequest
            ? held.future
            : null;
      final d = await fake.connect(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => mcpForm(
                context,
                McpServers.of(d, '/x', agent: 'claude'),
                server: editing
                    ? McpServer(
                        name: 'wiki',
                        scope: 'user',
                        configJson: '{"command":"npx","args":["wiki-mcp"]}',
                      )
                    : null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (!editing) {
        await tester.enterText(find.byType(TextField).at(0), 'wiki');
        await tester.enterText(find.byType(TextField).at(1), 'npx');
      }
      // The last: the env's and headers' rows have an Add of their own.
      Finder button(String label) =>
          find.byWidgetPredicate((w) => w is Button && w.label == label).last;
      final rest = tester.getRect(button(idle));
      final cancel = tester.getRect(button('Cancel'));
      await render(
        tester,
        find.byType(Dialog),
        'busy_mcp_form_${idle.toLowerCase()}_idle',
      );
      await tester.tap(button(idle));
      await tester.pump();
      expect(tester.getRect(button('Saving…')), rest);
      await render(
        tester,
        find.byType(Dialog),
        'busy_mcp_form_${idle.toLowerCase()}_busy',
      );
      expect(tester.getRect(button('Cancel')), cancel);
      held.complete(editing ? EditMcpServerResponse() : AddMcpServerResponse());
      await tester.pumpAndSettle();
      d.dispose();
    });
  }

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

/// The dialog's own button labelled [label], after any of the form's (an
/// env's or headers' Add).
Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is Button && w.label == label).last;

/// Opens the form on Claude's servers in [b]'s theme, adding a server or
/// editing [server].
Future<void> _open(
  WidgetTester tester,
  Brightness b,
  Daemon d, {
  McpServer? server,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(b == Brightness.dark ? Tokens.dark : Tokens.light)
          .toThemeData(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Button(
              label: 'open',
              onPressed: () => mcpForm(
                context,
                McpServers.of(d, '/x', agent: 'claude'),
                server: server,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A server of each kind to edit, more of its form filled than an added
/// one's; `odd` has an argument with a line break, which the form can't
/// show, so it opens in its JSON.
const _servers = {
  'stdio':
      '{"command":"npx","args":["-y","notes-mcp","--root","/tmp/notes"],'
      '"env":{"NOTES_LEVEL":"debug","NOTES_COLOR":"never"}}',
  'http':
      '{"type":"http","url":"https://notes.example.com/mcp",'
      '"headers":{"X-Team":"blue","X-Region":"north"}}',
  'sse':
      '{"type":"sse","url":"https://notes.example.com/sse",'
      '"headers":{"X-Team":"blue"}}',
  'odd': r'{"command":"npx","args":["notes\nmcp"]}',
};

/// Opens the form for [kind] at [size], presses Edit as JSON (Edit in the
/// form for one that opens in its JSON) and back, and checks the button,
/// Cancel and Add or Save keep their rects and what was typed carries
/// over; draws both views for two of the cases.
Future<void> _switchesInPlace(
  WidgetTester tester,
  Brightness b,
  Size size,
  String kind, {
  required bool editing,
}) async {
  viewport(tester, size);
  final d = await FakeDaemon([]).connect(tester);
  await _open(
    tester,
    b,
    d,
    server: editing
        ? McpServer(name: 'notes', scope: 'user', configJson: _servers[kind])
        : null,
  );
  final odd = kind == 'odd';
  final stdio = kind == 'stdio' || odd;
  if (!editing && !stdio) {
    await tester.tap(find.text(kind == 'http' ? 'HTTP' : 'SSE'));
    await tester.pumpAndSettle();
  }
  // The command, or the URL: typed when adding, the server's when editing,
  // typed in the JSON for the one that opens there.
  final typed = switch (kind) {
    _ when odd => 'uvx',
    'stdio' => editing ? 'npx' : 'uvx',
    _ => 'https://notes.example.com/${kind == 'http' ? 'mcp' : 'sse'}',
  };
  if (odd) {
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && (w.controller?.text.contains('{') ?? false),
      ),
      '{"command":"uvx","args":["notes-mcp"]}',
    );
  } else if (!editing) {
    await tester.enterText(find.byType(TextField).at(1), typed);
  }
  await tester.pump();
  final save = editing ? 'Save' : 'Add';
  final (first, second) = odd
      ? ('Edit in the form', 'Edit as JSON')
      : ('Edit as JSON', 'Edit in the form');
  final at = tester.getRect(_button(first));
  final cancel = tester.getRect(_button('Cancel'));
  final add = tester.getRect(_button(save));
  final drawn = (!editing && kind == 'stdio') || (editing && kind == 'http');
  final name =
      'mcp_height_${editing ? 'edit' : 'add'}_${kind}_${size.width.toInt()}';
  Future<void> draw({required bool json}) async {
    if (drawn) {
      await render(
        tester,
        find.byType(MaterialApp),
        '${name}_${json ? 'json' : 'form'}_${b.name}',
      );
    }
  }

  await draw(json: odd);
  for (final toggle in [first, second]) {
    await tester.tap(_button(toggle));
    await tester.pumpAndSettle();
    final json = toggle == 'Edit as JSON';
    await draw(json: json);
    final now = toggle == first ? second : first;
    expect(tester.getRect(_button(now)), at, reason: '$toggle pressed');
    expect(tester.getRect(_button('Cancel')), cancel, reason: toggle);
    expect(tester.getRect(_button(save)), add, reason: toggle);
    // In the JSON's box, or the command's or URL's field.
    final holding = find.byWidgetPredicate(
      (w) =>
          w is EditableText &&
          (json
              ? w.controller.text.contains('"$typed"')
              : w.controller.text == typed),
    );
    expect(holding, findsOne, reason: '$toggle pressed: what was typed');
  }
  await tester.tap(_button('Cancel'));
  await tester.pumpAndSettle();
  d.dispose();
}
