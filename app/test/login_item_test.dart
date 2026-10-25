import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  const channel = MethodChannel('nushi/login');
  late List<MethodCall> calls;
  late String status;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'set') {
            status = call.arguments == true ? 'enabled' : 'notRegistered';
          }
          return status;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: const NushiTheme(Tokens.dark).toThemeData(),
      home: const Scaffold(body: StartAtLogin()),
    ),
  );

  testWidgets('the switch registers and unregisters the login item', (
    tester,
  ) async {
    status = 'notRegistered';
    await show(tester);
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(calls.last.method, 'set');
    expect(calls.last.arguments, true);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(calls.last.arguments, false);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('waiting for approval says so and opens Login Items', (
    tester,
  ) async {
    status = 'requiresApproval';
    await show(tester);
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.textContaining('Login Items'));
    await tester.pump();
    expect(calls.last.method, 'openSettings');
  });

  testWidgets('no row without the launch agent or the channel', (tester) async {
    status = 'notFound';
    await show(tester);
    await tester.pump();
    expect(find.byType(Switch), findsNothing);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await show(tester);
    await tester.pump();
    expect(find.byType(Switch), findsNothing);
  });
}
