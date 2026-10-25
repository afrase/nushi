import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

void main() {
  test(
    'new chats start with the newest chat’s agent, named as the daemon says',
    () {
      agentList.value = {
        'claude': Agent(
          name: 'claude',
          title: 'Claude',
          resume: 'claude --resume',
        ),
        'codex': Agent(name: 'codex', title: 'Codex', resume: 'codex resume'),
      };
      expect(lastAgent([]), 'claude'); // the default
      final old = ChatState('a', '/x')
        ..agent = 'codex'
        ..created = DateTime(2026);
      final gone = ChatState('b', '/x')
        ..agent =
            'ante' // no longer known
        ..created = DateTime(2027);
      expect(lastAgent([old, gone]), 'codex');
      final newer = ChatState('c', '/x')
        ..agent = 'claude'
        ..created = DateTime(2026, 2);
      expect(lastAgent([old, gone, newer]), 'claude');
      expect(old.agentName, 'Codex');
      expect(old.resume, 'codex resume');
      expect(gone.agentName, 'Ante');
    },
  );
}
