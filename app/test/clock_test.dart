import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clock.dart';

void main() {
  testWidgets('minuteClock tells its listeners once a minute, only while '
      'one listens', (tester) async {
    var told = 0;
    void tell() => told++;
    expect(minuteClock.ticking, isFalse);
    minuteClock.addListener(tell);
    addTearDown(() => minuteClock.removeListener(tell));
    expect(minuteClock.ticking, isTrue);
    await tester.pump(const Duration(seconds: 59));
    expect(told, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(told, 1);
    minuteClock.removeListener(tell);
    expect(minuteClock.ticking, isFalse);
    await tester.pump(const Duration(minutes: 2));
    expect(told, 1);
  });
}
