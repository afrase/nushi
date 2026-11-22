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
}
