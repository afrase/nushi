import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/slides.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';
import 'package:nushi/widgets.dart' show showError;

import 'harness.dart';

// The window's toasts as a queue (ADR 0128): one at a time, each in its
// turn, `replace` in the showing one's place, gone after its duration or
// its action, at once under Reduce Motion.

void main() {
  late Toasts toasts;

  Future<void> start(WidgetTester tester) async {
    const here = ValueKey('here');
    await tester.pumpWidget(themed(const SizedBox(key: here)));
    toasts = Toasts.maybeOf(tester.element(find.byKey(here)))!;
  }

  String? shown() => switch (find.byType(ToastLine).evaluate().toList()) {
    [final e] => (e.widget as ToastLine).text,
    [] => null,
    _ => throw StateError('more than one toast'),
  };

  testWidgets('one at a time, each in its turn, for its duration', (
    tester,
  ) async {
    await start(tester);
    showToast(toasts, 'one', duration: const Duration(seconds: 2));
    showToast(toasts, 'two');
    await tester.pumpAndSettle();
    expect(shown(), 'one');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(shown(), 'two');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(shown(), isNull);
  });

  testWidgets('replace takes the showing one’s place at once; hide and '
      'an action take it away', (tester) async {
    await start(tester);
    var undone = 0;
    showToast(toasts, 'Checking…', duration: const Duration(minutes: 1));
    await tester.pumpAndSettle();
    showToast(
      toasts,
      'Archived',
      replace: true,
      action: (label: 'Undo', onPressed: () => undone++),
    );
    await tester.pump();
    expect(shown(), 'Archived');
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(shown(), isNull);
    showToast(toasts, 'three', closable: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(shown(), isNull);
    showToast(toasts, 'four');
    showToast(toasts, 'five');
    await tester.pumpAndSettle();
    toasts.clear();
    await tester.pump();
    expect(shown(), isNull);
  });

  testWidgets('under Reduce Motion it comes and goes at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await start(tester);
    showToast(toasts, 'one');
    await tester.pump();
    expect(shown(), 'one');
    // Whole on its first frame, not fading in.
    final faded = find.ancestor(
      of: find.byType(ToastLine),
      matching: find.byType(Faded),
    );
    expect(tester.widget<Faded>(faded).opacity, 1);
    toasts.hide();
    await tester.pump();
    expect(shown(), isNull);
  });

  testWidgets('every failure has one look: the failure fill, its icon in '
      'the failure ink, a ×, for 8 s', (tester) async {
    await start(tester);
    final here = tester.element(find.byKey(const ValueKey('here')));
    final t = NushiTheme.of(here).t;
    showError(here, 'nope');
    await tester.pumpAndSettle();
    expect(shown(), 'nope');
    final icon = tester.widget<Icon>(
      find
          .descendant(of: find.byType(ToastLine), matching: find.byType(Icon))
          .first,
    );
    expect(icon.icon, Icons.error_outline);
    expect(icon.color, t.crashed);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
    final fill = tester.widget<Material>(
      find
          .ancestor(of: find.byType(ToastLine), matching: find.byType(Material))
          .first,
    );
    expect(fill.color, t.crashedSoft);
    // Past a plain toast's 4 s it stays; at 8 s it goes.
    await tester.pump(const Duration(seconds: 5));
    expect(shown(), 'nope');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(shown(), isNull);
    // A plain one keeps the lifted fill.
    showToast(toasts, 'fine');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byType(ToastLine),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      t.lifted,
    );
  });
}
