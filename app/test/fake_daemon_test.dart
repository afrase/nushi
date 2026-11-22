import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

import 'fake_daemon.dart';

// FakeDaemon fails as the daemon does, so a test of the app can tell what
// a reconnect or a dropped daemon changes.
void main() {
  testWidgets('each events subscription is its own, with its request', (
    tester,
  ) async {
    final fake = FakeDaemon([chat('a', 'claude', 'Fix the login')]);
    final d = await fake.connect(tester);
    expect(fake.subscriptions, hasLength(1));
    expect(fake.subscriptions.single.request.imageRefs, isTrue);

    d.relink(); // the app lets it go; the next ping subscribes again
    await tester.pump();
    expect(fake.subscriptions.single.live, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(fake.subscriptions, hasLength(2));
    expect(fake.subscriptions.last.live, isTrue);
    d.dispose(); // its ping timer ends with the test
  });

  test('an event with nobody subscribed fails the test that sends it', () {
    final fake = FakeDaemon([]);
    expect(() => fake.emit(EventsResponse(chatId: 'a')), throwsStateError);
  });

  testWidgets('a daemon gone drops the subscription; back, the app '
      'subscribes again', (tester) async {
    final fake = FakeDaemon([chat('a', 'claude', 'Fix the login')]);
    final d = await fake.connect(tester);
    fake.down = true;
    await tester.pump();
    expect(fake.subscriptions.single.live, isFalse);
    expect(() => fake.emit(EventsResponse(chatId: 'a')), throwsStateError);
    await tester.pump(const Duration(seconds: 2));
    expect(d.connected, isFalse);
    expect(fake.subscriptions, hasLength(1)); // none while it's gone

    fake.down = false;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(fake.subscriptions, hasLength(2));
    expect(fake.subscriptions.last.live, isTrue);
    expect(d.chats.keys, ['a']); // listed again
    d.dispose(); // its ping timer ends with the test
  });

  testWidgets('a daemon gone ends every stream it serves, not just events', (
    tester,
  ) async {
    final fake = FakeDaemon([chat('a', 'claude', 'Fix the login')])
      ..files['README.md'] = [104, 105];
    final hooked = StreamController<Object>();
    addTearDown(hooked.close);
    fake.streams = (r) => r is WatchServerLogRequest ? hooked.stream : null;
    final d = await fake.connect(tester);
    final ends = <String, Object?>{};
    void watch(String name, Stream<Object> s) => s.listen(
      (_) {},
      onError: (Object e) => ends[name] = e,
      onDone: () => ends.putIfAbsent(name, () => 'done'),
    );
    watch(
      'folder',
      d.client.watchChatFolder(
        WatchChatFolderRequest(chatId: 'a', path: '/Users/me/nushi'),
      ),
    );
    watch(
      'file',
      d.client.watchChatFile(
        WatchChatFileRequest(chatId: 'a', path: 'README.md'),
      ),
    );
    watch(
      'hooked',
      d.client.watchServerLog(WatchServerLogRequest(chatId: 'a')),
    );
    await tester.pump();
    expect(ends, isEmpty);

    fake.down = true;
    await tester.pump();
    expect(ends.keys, unorderedEquals(['folder', 'file', 'hooked']));
    for (final e in ends.values) {
      expect(
        e,
        isA<ConnectException>().having((e) => e.code, 'code', Code.unavailable),
      );
    }
    fake.putFile('README.md', [104]); // a watch the daemon dropped is gone
    await tester.pump();
    fake.down = false;
    await tester.pump(const Duration(seconds: 2));
    d.dispose(); // its ping timer ends with the test
  });
}
