import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/pull_link.dart';

void main() {
  Item call(
    String title, {
    String input = '',
    String tool = '',
    String status = 'completed',
  }) => Item(
    id: title,
    kind: ItemKind.ITEM_KIND_TOOL_CALL,
    title: title,
    input: input,
    tool: tool,
    status: status,
  );

  test("a push or a new pull request asks for the chat's again", () {
    expect(pushedOrOpened(call('git push -u origin HEAD')), isTrue);
    expect(
      pushedOrOpened(call('Bash', input: '{"command": "git -C x push"}')),
      isTrue,
    );
    expect(pushedOrOpened(call('gh pr create --fill')), isTrue);
    expect(
      pushedOrOpened(
        call(
          'github · create_pull_request',
          tool: 'mcp__github__create_pull_request',
        ),
      ),
      isTrue,
    );
    expect(pushedOrOpened(call('git push', status: 'in_progress')), isFalse);
    expect(pushedOrOpened(call('git pull')), isFalse);
    expect(pushedOrOpened(call('gh pr view')), isFalse);
    expect(
      pushedOrOpened(
        Item(
          kind: ItemKind.ITEM_KIND_AGENT_MESSAGE,
          text: 'git push',
          status: 'completed',
        ),
      ),
      isFalse,
    );
  });
}
