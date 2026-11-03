import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/speller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('nushi/spelling');

  test('each call says what the Swift side reads', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'check' => ['qick'],
            'guesses' => ['quick', 'quack'],
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const mac = MacSpeller();
    expect(await mac.misspelled(['the', 'qick']), ['qick']);
    expect(await mac.guesses('qick'), ['quick', 'quack']);
    await mac.ignore('qick');
    await mac.learn('qick');
    expect(
      [
        for (final c in calls) [c.method, c.arguments],
      ],
      [
        [
          'check',
          ['the', 'qick'],
        ],
        ['guesses', 'qick'],
        ['ignore', 'qick'],
        ['learn', 'qick'],
      ],
    );
  });

  test('only the Mac has one', () {
    expect(speller, isNull); // tests run as Android unless they say
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(speller, isA<MacSpeller>());
  });
}
