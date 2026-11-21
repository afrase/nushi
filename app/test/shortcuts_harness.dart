// Settings › Keyboard shortcuts' test helpers: the page, its rows and keys
// found by their keys, a key recorded on a row, what's saved.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';
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
