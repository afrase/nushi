// Settings › Keyboard shortcuts' test helpers: the page, its rows, keys and
// buttons found by their keys, a key recorded on a row, what's saved, and
// how a row looks (a chosen key, its ring, No key shown).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/controls.dart' show KeyCapButton, Tap;
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/window_drag_linux.dart';

import 'fake_daemon.dart';
import 'settings_harness.dart';

/// Settings alone at Keyboard shortcuts in a window of [size], tall
/// enough that every row is built.
Future<Daemon> shortcutsPage(
  WidgetTester tester, {
  Size size = const Size(1000, 2600),
  Tokens tokens = Tokens.dark,
}) async {
  final d = await FakeDaemon([]).connect(tester);
  await pumpSettings(
    tester,
    d,
    SettingsSection.shortcuts,
    size: size,
    tokens: tokens,
  );
  return d;
}

/// Settings at Keyboard shortcuts over the whole app, as it opens, tall
/// enough that every row is built: where Esc reaches the modal that shuts
/// it.
Future<Daemon> shortcutsInApp(WidgetTester tester) => pumpSettingsApp(
  tester,
  FakeDaemon([]),
  SettingsSection.shortcuts,
  size: const Size(1700, 2600),
);

/// [id]'s key, the row's control.
Finder keyOf(String id) => find.byKey(ValueKey('shortcut-key-$id'));

/// [id]'s row.
Finder rowOf(String id) => find.byKey(ValueKey('shortcut-row-$id'));

/// [text] in [id]'s row.
Finder inRow(String id, String text) =>
    find.descendant(of: rowOf(id), matching: find.text(text));

/// [f] brought into view and tapped, then settled.
Future<void> tapIt(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// [f], a row's button that shows only under the pointer (No key),
/// pointed at with a mouse and clicked, then the mouse gone.
Future<void> clickShown(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  final at = tester.getCenter(f);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: at);
  await tester.pumpAndSettle();
  await mouse.down(at);
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.removePointer();
  await tester.pumpAndSettle();
}

/// [key] pressed with [holding] held, then settled.
Future<void> pressKey(
  WidgetTester tester,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [],
  PhysicalKeyboardKey? physical,
]) async {
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key, physicalKey: physical);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pumpAndSettle();
}

/// [id]'s key clicked and [key] pressed with [holding].
Future<void> recordKey(
  WidgetTester tester,
  String id,
  LogicalKeyboardKey key, [
  List<LogicalKeyboardKey> holding = const [],
  PhysicalKeyboardKey? physical,
]) async {
  await tapIt(tester, keyOf(id));
  await pressKey(tester, key, holding, physical);
}

const LogicalKeyboardKey metaKey = LogicalKeyboardKey.metaLeft;
const LogicalKeyboardKey altKey = LogicalKeyboardKey.altLeft;
const LogicalKeyboardKey shiftKey = LogicalKeyboardKey.shiftLeft;
const LogicalKeyboardKey ctrlKey = LogicalKeyboardKey.controlLeft;

/// The keys `app.json` holds, none before the first change.
Map<String, Object?> savedKeys() =>
    readSaved()['shortcuts'] as Map<String, Object?>? ?? {};

/// What [id]'s key shows.
String keyShows(WidgetTester tester, String id) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: keyOf(id), matching: find.byType(Text)),
  );
  return texts.map((t) => t.data ?? t.textSpan!.toPlainText()).join();
}

/// The app as on Linux: its conventions and window.
void shortcutsOnLinux() => native
  ..conventions = linuxConventions
  ..window = const LinuxWindow();

/// [id]'s field's focus.
FocusNode focusOf(WidgetTester tester, String id) => tester
    .widgetList<Focus>(
      find.descendant(of: keyOf(id), matching: find.byType(Focus)),
    )
    .map((f) => f.focusNode)
    .firstWhere((n) => n?.debugLabel == 'shortcut-$id')!;

/// The width of the line round [id]'s cap: 2 its focus ring, 1 the
/// outline of no key, 0 none.
double ringOf(WidgetTester tester, String id) => switch (tester
    .widgetList<Container>(
      find.descendant(of: keyOf(id), matching: find.byType(Container)),
    )
    .map((c) => c.foregroundDecoration)
    .whereType<BoxDecoration>()
    .firstOrNull
    ?.border) {
  final Border b => b.top.width,
  _ => 0,
};

/// The name of the nearest widget round the keyboard's focus keyed
/// `shortcut-…`.
String? focusedShortcut() {
  String? found;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    if (e.widget.key case ValueKey(:final String value)
        when value.startsWith('shortcut')) {
      found = value;
      return false;
    }
    return true;
  });
  return found;
}

/// [id]'s Take it, while a clash is offered.
Finder takeOf(String id) => find.byKey(ValueKey('shortcut-take-$id'));

/// [id]'s Reset, where it has one.
Finder resetOf(String id) => find.byKey(ValueKey('shortcut-reset-$id'));

/// [id]'s No key, where it has one.
Finder clearOf(String id) => find.byKey(ValueKey('shortcut-clear-$id'));

/// The colour of [text] on [id]'s row.
Color? inkOf(WidgetTester tester, String id, String text) =>
    tester.widget<Text>(inRow(id, text)).style?.color;

/// Whether [id]'s cap wears a chosen key's look: the accent's soft fill.
bool isChosen(WidgetTester tester, String id) =>
    tester
        .widget<Tap>(find.descendant(of: keyOf(id), matching: find.byType(Tap)))
        .fill ==
    Tokens.dark.accentSoft;

/// Whether [id]'s No key is shown: painted and hit, not only kept room.
bool clearShown(WidgetTester tester, String id) =>
    tester
        .widget<Opacity>(
          find.ancestor(of: clearOf(id), matching: find.byType(Opacity)).first,
        )
        .opacity ==
    1;

/// Every key's cap ends at its group's right edge, less the row's
/// padding, a fixed key's too; returns how many were checked.
int expectCapsAtEdge(WidgetTester tester) {
  final caps = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        RegExp('^shortcut-(key|fixed)-')
            .hasMatch((w.key! as ValueKey<String>).value),
  );
  var n = 0;
  for (final e in caps.evaluate()) {
    final group = tester.getRect(
      find
          .ancestor(
            of: find.byWidget(e.widget),
            matching: find.byType(SettingsGroup),
          )
          .first,
    );
    final cap = (e.widget.key! as ValueKey<String>).value.contains('-fixed-')
        ? find.descendant(
            of: find.byWidget(e.widget),
            matching: find.byType(KeyCapButton),
          )
        : find.byWidget(e.widget);
    expect(
      tester.getRect(cap).right,
      moreOrLessEquals(group.right - 14, epsilon: 0.5),
      reason: '${e.widget.key}',
    );
    n++;
  }
  return n;
}
