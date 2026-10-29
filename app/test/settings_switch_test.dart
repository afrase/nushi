import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';

void main() {
  testWidgets('a switch whose change is a call: tapped twice while it runs, '
      'it sends once; its error shows', (tester) async {
    final asked = <bool>[];
    var call = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: const NushiTheme(Tokens.light).toThemeData(),
        home: Scaffold(
          body: Center(
            child: SettingsSwitch(
              value: false,
              run: ({required on}) {
                asked.add(on);
                return call.future;
              },
            ),
          ),
        ),
      ),
    );
    Switch shown() => tester.widget<Switch>(find.byType(Switch));

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(shown().onChanged, isNull); // held while the call runs
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(asked, [true]);

    call.complete();
    await tester.pumpAndSettle();
    expect(shown().onChanged, isNotNull);

    call = Completer<void>();
    await tester.tap(find.byType(Switch));
    call.completeError(StateError('no daemon'));
    await tester.pumpAndSettle();
    expect(asked, [true, true]);
    expect(find.text('Bad state: no daemon'), findsOne);
    expect(shown().onChanged, isNotNull);
  });
}
