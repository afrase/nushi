// The transcript's parts and the composer in the look of ADR 0111, each
// drawn whole: the window at 1700 and 720, in both themes, and the phone
// (`make renders TEST=test/transcript_look_test.dart`), with goldens of the
// parts that have none of their own.
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/collapsible.dart';
import 'package:nushi/completions.dart';
import 'package:nushi/composer.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/composer_plus.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/main.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/pickers.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/subagent_pane.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/trust_card.dart';

import 'fake_daemon.dart';
import 'harness.dart';

final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A small screenshot, as a message's image.
final Uint8List _shot = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAGAAAAA8CAIAAAAWtijjAAAAh0lEQVR42u3XsQ2AIABEUTayJ1'
  'aMw0AUlk7mAMSCCVyA0GmCvORP8IpLLsQ9aVBAAAgQIECAAAECpC5QvZsGAQIECBAgQIDWBirH'
  '+csAAQI0B5CRFiBAgAABAgQIkAABmgVoy9dnAQIECBAgQIAAAQIECBAgZxWQAAECBAgQIECAAF'
  'EABOjFHhjA0K5ShWj9AAAAAElFTkSuQmCC',
);

Item _tool(
  String id,
  String kind,
  String title, {
  String status = 'completed',
  List<String> paths = const [],
  String text = '',
  String input = '',
  List<FileChange> diffs = const [],
}) => Item(
  id: id,
  kind: ItemKind.ITEM_KIND_TOOL_CALL,
  toolKind: kind,
  title: title,
  status: status,
  paths: paths,
  text: text,
  input: input,
  diffs: diffs,
);

Item _say(String id, String text) =>
    Item(id: id, kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, text: text);

const _old = '''
func (h *Handler) Feed(w http.ResponseWriter, r *http.Request) {
	posts, err := h.store.ListPosts(ctx)
	if err != nil {
		return err
	}
}
''';

const _new = '''
func (h *Handler) Feed(w http.ResponseWriter, r *http.Request) {
	after, err := ParseCursor(q)
	if err != nil {
		return errBadCursor
	}
	posts, next, err := h.page(ctx, after)
	if err != nil {
		return err
	}
}
''';

/// A long mixed transcript: every part the transcript draws, and at its
/// end a running command.
final _items = <Item>[
  Item(
    id: 'u',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        'Paginate the home feed: 20 a page, and keep the reader’s place '
        'across reloads. Tests too.',
  ),
  Item(
    id: 'th',
    kind: ItemKind.ITEM_KIND_THOUGHT,
    text: 'The feed reads the whole table. A keyset cursor would hold.',
  ),
  _tool('r1', 'read', 'Read', paths: ['internal/store/posts.go']),
  _tool('r2', 'read', 'Read', paths: ['internal/feed/handler.go']),
  _tool('r3', 'search', 'Search for ListPosts'),
  _say(
    'm1',
    '`ListPosts` reads the whole table in one query. I’ll give it a keyset '
        'cursor on `(published, id)`, so a post published while someone '
        'reads doesn’t shift the pages, and have an Explore agent find every '
        'template that renders the feed.',
  ),
  Item(
    id: 'plan',
    kind: ItemKind.ITEM_KIND_PLAN,
    plan: [
      PlanEntry(content: 'A cursor in store.ListPosts', status: 'completed'),
      PlanEntry(content: 'Page the feed handler', status: 'completed'),
      PlanEntry(
        content: 'Older posts link in the templates',
        status: 'in_progress',
      ),
      PlanEntry(
        content: 'Tests for the cursor and the handler',
        status: 'pending',
      ),
    ],
  ),
  Item(
    id: 'sa',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'think',
    agent: 'Explore',
    title: 'Find every template that renders the feed',
    prompt: 'Find every template that renders the feed, in every theme.',
    status: 'in_progress',
    subagent: Subagent(state: 'running'),
  ),
  Item(
    id: 'sa1',
    parent: 'sa',
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    toolKind: 'search',
    title: 'Search for range .Posts',
    status: 'completed',
  ),
  Item(
    id: 'sa2',
    parent: 'sa',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'Three themes render it, each from its own `feed.html`.',
  ),
  _tool(
    'e1',
    'edit',
    'Edit',
    paths: ['internal/feed/handler.go'],
    diffs: [
      FileChange(
        path: 'internal/feed/handler.go',
        oldText: _old,
        newText: _new,
      ),
    ],
  ),
  _tool(
    'e2',
    'edit',
    'Edit',
    paths: ['internal/store/posts.go'],
    diffs: [
      FileChange(
        path: 'internal/store/posts.go',
        oldText: 'a\nb\nc\n',
        newText: 'a\nB\nc\nd\n',
      ),
    ],
  ),
  _tool(
    'e3',
    'edit',
    'Edit',
    paths: ['docs/design/feed-cursor.md'],
    diffs: [
      FileChange(
        path: 'docs/design/feed-cursor.md',
        newText: '# The cursor\n\nKeyset, on (published, id).\n',
      ),
    ],
  ),
  _say(
    'm2',
    'The store and the handler page now.\n\n'
        '```go\nfunc ParseCursor(q url.Values) (Cursor, error) {\n'
        '\t// The cursor is opaque to the reader.\n'
        '\treturn decode(q.Get("after"))\n}\n```\n\n'
        '| Page | Posts | Query |\n| --- | --- | --- |\n'
        '| First | 20 | 3 ms |\n| Later | 20 | 2 ms |\n\n'
        '> A cursor, not an offset: a new post must not shift the pages.\n\n'
        'While Explore goes through the themes, I’m running the store’s '
        'tests.',
  ),
  Item(
    id: 'img',
    kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
    text: 'The feed’s foot, as it draws now:',
    images: [ImageData(mimeType: 'image/png', data: _shot)],
  ),
  _tool(
    'x1',
    'execute',
    'go vet ./internal/feed/...',
    status: 'failed',
    text: '```\nhandler.go:41:2: declared and not used: next\n```',
  ),
  _tool(
    'f1',
    'fetch',
    'Fetch https://pkg.go.dev/net/url',
    text: 'Package url parses URLs and implements query escaping.',
  ),
  _tool(
    'mcp',
    'other',
    'mcp__jira__search',
    input: '{\n  "jql": "project = LUM AND text ~ feed"\n}',
    text: 'LUM-142 Paginate the feed',
  ),
  Item(
    id: 'err',
    kind: ItemKind.ITEM_KIND_NOTICE,
    status: 'error',
    text: 'The agent’s connection dropped for a moment.',
  ),
  Item(
    id: 'u2',
    kind: ItemKind.ITEM_KIND_USER_MESSAGE,
    text:
        '> a keyset cursor on (published, id)\n\n'
        'Good. Also run `make check` before you stop.',
  ),
  _tool(
    'x2',
    'execute',
    'go test ./internal/store/... ./internal/feed/...',
    status: 'in_progress',
  ),
];

Item _permission() => Item(
  id: 'p',
  kind: ItemKind.ITEM_KIND_PERMISSION,
  title: 'make check',
  status: 'pending',
  options: [
    Option(id: 'y', name: 'Allow once'),
    Option(id: 'a', name: 'Always allow make'),
    Option(id: 'n', name: 'Reject'),
  ],
);

Item _question() => Item(
  id: 'q',
  kind: ItemKind.ITEM_KIND_QUESTION,
  status: 'pending',
  text: 'How should a reader move between pages?',
  fields: [
    Field(
      id: 'how',
      title: 'Paging',
      type: FieldType.FIELD_TYPE_CHOICE,
      description: 'Which control ends the feed?',
      options: [
        Option(id: 'o', name: 'An Older posts link', description: 'One page'),
        Option(id: 's', name: 'Endless scroll'),
        Option(id: 'n', name: 'Numbered pages'),
      ],
    ),
  ],
);

final _config = EventsResponse(
  chatId: 'c',
  seq: Int64(2),
  config: ChatConfig(
    options: [
      ConfigOption(
        id: 'mode',
        name: 'Mode',
        category: 'mode',
        current: 'acceptEdits',
        values: [
          ConfigValue(value: 'default', name: 'Manual'),
          ConfigValue(value: 'acceptEdits', name: 'Accept edits'),
          ConfigValue(value: 'plan', name: 'Plan'),
        ],
      ),
      ConfigOption(
        id: 'model',
        name: 'Model',
        category: 'model',
        current: 'opus',
        values: [
          ConfigValue(value: 'opus', name: 'Opus 5.5'),
          ConfigValue(value: 'sonnet', name: 'Sonnet 5'),
        ],
      ),
      ConfigOption(
        id: 'effort',
        name: 'Effort',
        category: 'thought_level',
        current: 'high',
        values: [
          ConfigValue(value: 'high', name: 'High'),
          ConfigValue(value: 'low', name: 'Low'),
        ],
      ),
      ConfigOption(
        id: 'fast',
        name: 'Fast mode',
        category: 'fast',
        type: 'boolean',
        current: 'false',
      ),
    ],
  ),
);

/// The app on a chat with [items], working unless [idle], its details
/// hidden, at [size] in [brightness].
Future<(Daemon, FakeDaemon)> _app(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  List<Item>? items,
  bool idle = false,
  List<String> open = const [],
}) async {
  viewport(tester, size, brightness: brightness);
  showDetails.value = false;
  sidebarHidden.value = true;
  Collapsible.opened
    ..clear()
    ..addAll(open);
  addTearDown(Collapsible.opened.clear);
  final c = chat('c', 'claude', 'Paginate the feed');
  final fake = FakeDaemon([c])
    ..answer = ((input) => input is GetChatRequest
        ? GetChatResponse(chat: c, items: items ?? _items)
        : null);
  final d = await fake.connect(tester);
  d.select('c');
  await tester.pumpWidget(NushiApp(daemon: d));
  await tester.pumpAndSettle();
  fake.emit(_config);
  if (!idle) {
    d.chats['c']!
      ..busy = true
      ..started = clock().subtract(const Duration(minutes: 3, seconds: 12))
      ..notifyListeners();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (d, fake);
}

const _sizes = [('1700', Size(1700, 1000)), ('720', Size(720, 900))];

void main() {
  setUpAll(loadFonts);

  for (final b in Brightness.values) {
    for (final (w, size) in _sizes) {
      testWidgets('a long mixed transcript, ${b.name}, $w wide', (
        tester,
      ) async {
        // The edits' run open, and its first file's diff.
        final (d, _) = await _app(
          tester,
          size: Size(size.width, 2300),
          brightness: b,
          open: ['group e1', 'e1', 'x1'],
        );
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'look_transcript_${w}_${b.name}',
        );
        d.dispose();
      }, variant: _mac);

      testWidgets('its end at the window’s height, the agent working, '
          '${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        await tester.enterText(
          find.byType(TextField),
          'Also keep the cursor in the URL, so a shared link opens the '
          'same page.',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Queue and Stop and send keep their words at both widths, and
        // the row is one line.
        expect(find.text('Queue'), findsOneWidget);
        expect(find.text('Stop and send'), findsOneWidget);
        final stop = tester.getRect(find.byTooltip('Stop (esc)'));
        final plus = tester.getRect(find.byType(PlusButton));
        expect(stop.center.dy, plus.center.dy);
        expect(tester.getRect(find.byType(Pickers)).center.dy, plus.center.dy);
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'look_working_${w}_${b.name}',
        );
        d.dispose();
      }, variant: _mac);

      testWidgets('a permission and a question, ${b.name}, $w wide', (
        tester,
      ) async {
        final (d, _) = await _app(
          tester,
          size: size,
          brightness: b,
          idle: true,
          items: [
            _items.first,
            _say('m', 'Two things before I go on.'),
            _permission(),
            _question(),
          ],
        );
        expectTextInside(tester, size.width);
        await render(
          tester,
          find.byType(NushiApp),
          'look_cards_${w}_${b.name}',
        );
        d.dispose();
      }, variant: _mac);

      testWidgets('the subagent’s pane, ${b.name}, $w wide', (tester) async {
        final (d, _) = await _app(tester, size: size, brightness: b);
        d.chats['c']!.pane.value = 'sa';
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        expect(find.byType(SubagentPane), findsOneWidget);
        await render(
          tester,
          find.byType(NushiApp),
          'look_subagent_${w}_${b.name}',
        );
        d.dispose();
      }, variant: _mac);
    }

    // The composer's states, as the chat's view has it: 720 and 400 wide
    // (beside a pane), where Queue and Stop and send lose their words.
    testWidgets('the composer’s states, ${b.name}', (tester) async {
      viewport(tester, const Size(1180, 900), brightness: b);
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      final fake = FakeDaemon([]);
      final d = await fake.connect(tester);
      ChatState state(String id) => ChatState(id, '/Users/me/lumen')
        ..agent = 'claude'
        ..loaded = true
        ..config = _config.config.options;
      final empty = state('empty');
      final written = state('written')
        ..draft.text.text = 'Also keep the cursor in the URL.';
      final attached = state('attached')
        ..draft.text.text = 'This is where it breaks.'
        ..draft.images.value = [ImageData(mimeType: 'image/png', data: _shot)]
        ..draft.replies.value = [
          (quote: 'a keyset cursor', text: 'On which columns?', from: ''),
        ];
      final working = state('working')
        ..busy = true
        ..started = clock()
        ..draft.text.text = 'Also the README';
      final queued = state('queued')
        ..busy = true
        ..started = clock()
        ..queue = [
          QueuedMessage(id: 'q1', text: 'Then the docs'),
          QueuedMessage(id: 'q2', text: 'And run make check before you stop'),
        ];
      final narrow = state('narrow')
        ..busy = true
        ..started = clock()
        ..draft.text.text = 'Also the README';
      for (final c in [empty, written, attached, working, queued, narrow]) {
        d.chats[c.id] = c;
      }
      Widget box(ChatState c, double width) => SizedBox(
        width: width,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Composer(chat: c, daemon: d),
        ),
      );
      await tester.pumpWidget(
        themed(
          SingleChildScrollView(
            child: RepaintBoundary(
              key: const Key('states'),
              child: ColoredBox(
                color: tokens.base,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      box(empty, 720),
                      box(narrow, 400),
                      box(written, 720),
                      box(queued, 400),
                      box(attached, 720),
                      box(working, 720),
                    ],
                  ),
                ),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // With room, the words; beside a pane, the same actions as icons.
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Stop and send'), findsOneWidget);
      expect(find.byTooltip('Queue (⏎)'), findsNWidgets(2));
      expect(find.byTooltip('Stop and send (⌘⏎)'), findsNWidgets(2));
      expect(find.byTooltip('Stop (esc)'), findsNWidgets(3));
      expect(find.byTooltip('Send (⏎)'), findsNWidgets(2));
      // Stop is the square in a circle it was before the redesign, in a
      // round area 28 across that tints under the pointer: no fill.
      final stop = find.byTooltip('Stop (esc)').first;
      expect(
        find.ancestor(of: stop, matching: find.byType(RoundButton)),
        findsNothing,
      );
      expect(find.ancestor(of: stop, matching: find.byType(Tap)), findsOne);
      expect(tester.getSize(stop), const Size.square(28));
      expect(find.byType(SendButtons), findsNWidgets(6));
      await expectLater(
        find.byKey(const Key('states')),
        matchesGoldenFile('goldens/composer_states_${b.name}.png'),
      );
      await closeView(tester, d);
    });

    testWidgets('the slash list over the box, ${b.name}', (tester) async {
      viewport(tester, const Size(720, 360), brightness: b);
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      await tester.pumpWidget(
        themed(
          RepaintBoundary(
            key: const Key('list'),
            child: ColoredBox(
              color: tokens.base,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ChoiceList(
                  const [
                    (
                      label: '/compact',
                      detail: 'Summarise the chat so far',
                      insert: '',
                    ),
                    (
                      label: '/plan',
                      detail: 'Plan before changing anything',
                      insert: '',
                    ),
                    (
                      label: '/review',
                      detail: 'Review the changes',
                      insert: '',
                    ),
                  ],
                  1,
                  onPick: (_) {},
                ),
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await expectLater(
        find.byKey(const Key('list')),
        matchesGoldenFile('goldens/choice_list_${b.name}.png'),
      );
    });

    testWidgets('the trust card, ${b.name}', (tester) async {
      viewport(tester, const Size(720, 420), brightness: b);
      final tokens = b == Brightness.dark ? Tokens.dark : Tokens.light;
      final ask = TrustAsk('/Users/me/lumen', 'Start a chat', [
        FolderRun(
          file: '/Users/me/lumen/.mcp.json',
          what: 'MCP server docs',
          command: 'npx -y @lumen/docs-mcp',
        ),
        FolderRun(
          file: '/Users/me/lumen/.claude/settings.json',
          what: 'Hook, before each tool',
          command: 'set -e\n./scripts/guard.sh "\$TOOL"\necho ok',
        ),
      ], 'claude');
      await tester.pumpWidget(
        themed(
          ColoredBox(color: tokens.base, child: TrustCard(ask)),
          tokens: tokens,
        ),
      );
      await expectLater(
        find.byType(TrustCard),
        matchesGoldenFile('goldens/trust_card_${b.name}.png'),
      );
    });

    testWidgets('the phone: the transcript and the composer, ${b.name}', (
      tester,
    ) async {
      viewport(tester, const Size(390, 844), ratio: 2, brightness: b);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      Collapsible.opened.clear();
      final c = chat('c', 'claude', 'Paginate the feed');
      final fake = FakeDaemon([c])
        ..answer = ((input) => input is GetChatRequest
            ? GetChatResponse(chat: c, items: _items)
            : null);
      final phone = await startPhone(tester, fake);
      await tester.tap(find.text('Paginate the feed'));
      await tester.pumpAndSettle();
      fake.emit(_config);
      await tester.pumpAndSettle();
      // A phone's box is too narrow for the pickers: they're under it.
      expect(
        tester.getRect(find.text('Accept edits')).top,
        greaterThan(tester.getRect(find.byType(PlusButton)).bottom),
      );
      // Every control of the box's row is a touch target.
      for (final target in [
        find.descendant(
          of: find.byType(PlusButton),
          matching: find.byType(Pressable),
        ),
        find
            .ancestor(
              of: find.text('Accept edits'),
              matching: find.byType(Pressable),
            )
            .first,
      ]) {
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(TouchTargets.size),
        );
      }
      await render(tester, find.byType(PhoneApp), 'look_phone_${b.name}');
      final idle = tester.getSize(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Also the README');
      await tester.pumpAndSettle();
      await render(tester, find.byType(PhoneApp), 'look_phone_text_${b.name}');
      // While a turn runs the hint says what a message does, still on one
      // line: the box is no higher for it (it wrapped at 390, and the box
      // grew 14 points).
      await tester.enterText(find.byType(TextField), '');
      fake.emit(
        EventsResponse(
          chatId: 'c',
          seq: Int64(3),
          status: ChatStatus(busy: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Queue it, or stop and send'), findsOneWidget);
      expect(tester.getSize(find.byType(TextField)).height, idle.height);
      await render(
        tester,
        find.byType(PhoneApp),
        'look_phone_working_${b.name}',
      );
      await endPhone(tester, phone);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
