import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/terminals.dart';

import 'fake_daemon.dart';
import 'fake_shells.dart';

// A terminal opened to run one command (API 143): asked for with its
// command, listed with it, and ended with its exit code.

(FakeDaemon, FakeShells, Terminals) _setup() {
  final fake = FakeDaemon([]);
  final shells = FakeShells(fake);
  addTearDown(shells.close);
  return (fake, shells, Terminals(NushiServiceClient(fake)));
}

void main() {
  test('opened with its command, listed with it, not shown', () async {
    final (fake, shells, terms) = _setup();
    final t = await terms.open('c', command: 'git status', show: false);
    final asked = fake.calls.whereType<OpenTerminalRequest>().single;
    expect(asked.command, 'git status');
    expect(t.command, 'git status');
    expect(terms.of('c')!.single.command, 'git status');
    expect(terms.focusNext, isNull);
    expect(shells.opened, ['git status']);
  });

  test('a shell is opened with no command', () async {
    final (fake, _, terms) = _setup();
    final t = await terms.open('c');
    expect(fake.calls.whereType<OpenTerminalRequest>().single.command, '');
    expect(t.command, isEmpty);
  });

  test('a command that prints and exits ends its stream so', () async {
    final (fake, shells, terms) = _setup();
    shells.commands['make test'] = (output: 'FAIL\r\n', exit: 2);
    final t = await terms.open('c', command: 'make test', show: false);
    final got = await terms.client
        .attachTerminal(AttachTerminalRequest(terminalId: t.id))
        .toList();
    expect(String.fromCharCodes(got.expand((m) => m.data)), 'FAIL\r\n');
    expect(got.last.exited, isTrue);
    expect(got.last.exitCode, 2);
    expect(shells.list.single.exited, isTrue);
    expect(shells.list.single.exitCode, 2);
  });

  test('one that runs until it ends', () async {
    final (_, shells, terms) = _setup();
    final t = await terms.open('c', command: 'sleep 5', show: false);
    final stream = terms.client
        .attachTerminal(AttachTerminalRequest(terminalId: t.id))
        .toList();
    await Future<void>.delayed(Duration.zero);
    shells
      ..write(t.id, 'half\r\n')
      ..ends(t.id, exit: 130);
    final got = await stream;
    expect(String.fromCharCodes(got.expand((m) => m.data)), 'half\r\n');
    expect(got.last.exitCode, 130);
    expect(shells.list.single.exited, isTrue);
  });
}
