// What a failed call says to the user: a daemon's message, without
// ConnectException's "[code] " before it.
import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

void main() {
  test('a daemon error is its message; anything else its text', () {
    expect(
      errorText(ConnectException(Code.unavailable, 'daemon unavailable')),
      'daemon unavailable',
    );
    expect(errorText(StateError('no')), 'Bad state: no');
  });

  testWidgets('a snack bar says the message, not its code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.dark).toThemeData(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Button(
              label: 'Go',
              onPressed: () => tryOrShow(
                context,
                () async => throw ConnectException(
                  Code.failedPrecondition,
                  'the folder is gone',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(find.text('the folder is gone'), findsOneWidget);
  });
}
