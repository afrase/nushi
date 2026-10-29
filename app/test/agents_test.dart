import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

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

  test('the agent a new chat picks, on the Mac and the phone alike: the '
      'last used if it can start, else the first that can', () {
    final d = Daemon(transport: FakeDaemon([]));
    addTearDown(d.dispose);
    agentList.value = {
      'claude': Agent(name: 'claude', ready: true),
      'codex': Agent(name: 'codex'), // not set up
      'ante': Agent(name: 'ante', ready: true),
    };
    const offered = ['claude', 'codex', 'ante'];
    d.chats['a'] = ChatState('a', '/x')..agent = 'codex';
    expect(defaultAgent(d, offered), 'claude');
    agentList.value = {
      ...agentList.value,
      'codex': Agent(name: 'codex', ready: true),
    };
    expect(defaultAgent(d, offered), 'codex');
    d.cantStart['codex'] = "couldn't start Codex";
    expect(defaultAgent(d, offered), 'claude');
    d.cantStart
      ..['claude'] = "couldn't start Claude"
      ..['ante'] = "couldn't start Ante";
    expect(defaultAgent(d, offered), 'codex'); // none can: the last used
    expect(defaultAgent(d, ['ante']), 'ante'); // the last used isn't offered
    expect(defaultAgent(d, []), '');
  });
}
