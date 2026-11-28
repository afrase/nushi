import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/widgets.dart';

import 'fake_daemon.dart';
import 'harness.dart';

/// RunButton: a Button whose action is a call, its running label shown
/// meanwhile.
void main() {
  setUpAll(loadFonts);

  testWidgets('a running label longer than its own keeps the button as '
      'wide, so the button beside it stays put', (tester) async {
    final held = Completer<void>();
    await tester.pumpWidget(
      themed(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(label: 'Next', onPressed: () {}),
            RunButton(
              label: 'Reload',
              running: 'Reloading…',
              run: () => held.future,
            ),
          ],
        ),
      ),
    );
    final next = find.text('Next');
    final idle = tester.getRect(find.byType(RunButton));
    final beside = tester.getRect(next);
    await tester.tap(find.text('Reload'));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is Button && w.label == 'Reloading…'),
      findsOne,
    );
    expect(tester.getRect(find.byType(RunButton)), idle);
    expect(tester.getRect(next), beside);
    held.complete();
    await tester.pumpAndSettle();
    expect(find.text('Reload'), findsOne);
    expect(tester.getRect(find.byType(RunButton)), idle);
  });

  testWidgets('a running label shorter than its own keeps the button as '
      'wide while it runs', (tester) async {
    final held = Completer<void>();
    await tester.pumpWidget(
      themed(
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Button(label: 'Next', onPressed: () {}),
            RunButton(
              label: 'Remove from queue',
              running: 'Removing…',
              run: () => held.future,
            ),
          ],
        ),
      ),
    );
    final next = find.text('Next');
    final idle = tester.getRect(find.byType(RunButton));
    final beside = tester.getRect(next);
    await tester.tap(find.text('Remove from queue'));
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is Button && w.label == 'Removing…'),
      findsOne,
    );
    expect(tester.getRect(find.byType(RunButton)), idle);
    expect(tester.getRect(next), beside);
    held.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('without a running label, or with a shorter one, it is as '
      'wide as its own label', (tester) async {
    await tester.pumpWidget(
      themed(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Button(label: 'Remove from queue', onPressed: () {}),
            RunButton(label: 'Remove from queue', run: () async {}),
            RunButton(
              label: 'Remove from queue',
              running: 'Removing…',
              run: () async {},
            ),
          ],
        ),
      ),
    );
    final plain = tester.getSize(find.byType(Button).first);
    for (final b in find.byType(RunButton).evaluate()) {
      expect(tester.getSize(find.byWidget(b.widget)), plain);
    }
  });
}
