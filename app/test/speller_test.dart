import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/native_macos.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/speller_macos.dart';

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

  test("the Mac's is its own; a test has none unless it sets one", () {
    expect(macosNative().speller, isA<MacSpeller>());
    expect(speller, isNull);
  });
}
