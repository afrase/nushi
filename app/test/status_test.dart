import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/status.dart';
import 'package:nushi/subagents.dart';

void main() {
  test('what the agent is doing, from the turn so far', () {
    Item user() => Item(kind: ItemKind.ITEM_KIND_USER_MESSAGE);
    Item tool(String kind, String status, {String title = '', String? path}) =>
        Item(
          kind: ItemKind.ITEM_KIND_TOOL_CALL,
          toolKind: kind,
          status: status,
          title: title,
          paths: [?path],
        );
    final reply = Item(kind: ItemKind.ITEM_KIND_AGENT_MESSAGE);
    expect(doing([reply, user()]), 'Thinking');
    expect(doing([user(), reply]), 'Writing');
    expect(
      doing([user(), tool('read', 'in_progress', path: 'a.md')]),
      'Reading a.md',
    );
    expect(
      doing([user(), tool('execute', 'pending', title: 'make test'), reply]),
      'Running make test',
    );
    expect(
      doing([user(), tool('read', 'completed', path: 'a.md')]),
      'Thinking',
    );
    expect(
      doing([user(), tool('other', 'in_progress', title: 'Fetch docs')]),
      'Fetch docs',
    );
    // A call still running from an earlier turn doesn't count.
    expect(
      doing([tool('read', 'in_progress', path: 'old.md'), user()]),
      'Thinking',
    );
  });

  test('elapsed time', () {
    expect(elapsed(const Duration(seconds: 12)), '12s');
    expect(elapsed(const Duration(seconds: 64)), '1m 04s');
  });

  test('a subagent gathers the items it made', () {
    final items = [
      Item(
        id: 'a',
        kind: ItemKind.ITEM_KIND_TOOL_CALL,
        agent: 'Explore',
        status: 'completed',
        subagent: Subagent(state: 'done'),
      ),
      Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE),
      Item(id: 'r', kind: ItemKind.ITEM_KIND_TOOL_CALL, parent: 'a'),
      Item(id: 's', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, parent: 'a'),
    ];
    final subs = subagentsOf(items);
    expect([for (final s in subs) s.call.id], ['a']);
    expect([for (final it in subs.single.items) it.id], ['r', 's']);
    expect(subagentState(subs.single), 'done · 1 tool call');
  });

  test('what a subagent runs on: asked for, else the chat\'s', () {
    ConfigOption option(String category, String current, List<String> v) =>
        ConfigOption(
          category: category,
          current: current,
          values: [
            for (final x in v) ConfigValue(value: x, name: x.toUpperCase()),
          ],
        );
    final chat = ChatState('c', '/f')
      ..config = [
        option('model', 'opus', ['opus', 'haiku']),
        option('thought_level', 'high', ['low', 'high']),
      ];
    final call = Item(id: 'a', agent: 'Explore', model: 'haiku');
    var runs = subagentModel(chat, (call: call, items: const []));
    expect(
      [settingText(runs.model), settingText(runs.effort)],
      ['HAIKU', 'HIGH (inherited)'],
    );
    call.ranModel = 'Haiku 5.5'; // once it ran, the model it ran on
    runs = subagentModel(chat, (call: call, items: const []));
    expect(settingText(runs.model), 'Haiku 5.5');
    chat.config = [];
    runs = subagentModel(chat, (call: Item(), items: const []));
    expect(settingText(runs.effort), 'inherited');
  });
}
