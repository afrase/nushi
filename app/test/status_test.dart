import 'package:flutter_test/flutter_test.dart';
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
      ),
      Item(id: 'm', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE),
      Item(id: 'r', kind: ItemKind.ITEM_KIND_TOOL_CALL, parent: 'a'),
      Item(id: 's', kind: ItemKind.ITEM_KIND_AGENT_MESSAGE, parent: 'a'),
    ];
    final subs = subagentsOf(items, busy: false);
    expect([for (final s in subs) s.call.id], ['a']);
    expect([for (final it in subs.single.items) it.id], ['r', 's']);
    expect(subagentState(subs.single), 'done · 1 tool call');
  });
}
