import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/composer_parts.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';

// The one rule of the boxes that send (isSendKey), in both modes of
// Settings › General's "Enter starts a new line" (ADR 0147), on the Mac
// and on Linux, where Control is the command key: what sends, what starts
// a line, what stops a running turn and sends now, and what a menu over
// the box takes. Real key events, the modifiers held down.

/// What each Enter in the window did: 's' sent, 'l' a line, 'n' sent
/// now, 'p' a menu's pick.
final _seen = StringBuffer();

/// A focused box that writes down what each Enter is ([_seen]).
Future<void> _box(WidgetTester tester) async {
  final focus = FocusNode();
  addTearDown(focus.dispose);
  addTearDown(_seen.clear);
  await tester.pumpWidget(
    Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent) {
          if (isSendKey(e)) _seen.write(sendNowHeld() ? 'n' : 's');
          if (isLineKey(e)) _seen.write('l');
          if (isPickKey(e)) _seen.write('p');
        }
        return KeyEventResult.handled;
      },
      child: const SizedBox(),
    ),
  );
  await tester.pump();
}

/// What Enter (or [key]) held with [holding] did in [_box]'s box.
Future<String> _enter(
  WidgetTester tester,
  List<LogicalKeyboardKey> holding, {
  LogicalKeyboardKey key = LogicalKeyboardKey.enter,
}) async {
  _seen.clear();
  for (final k in holding) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in holding.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  return _seen.toString();
}

const LogicalKeyboardKey _shift = LogicalKeyboardKey.shiftLeft;
const LogicalKeyboardKey _alt = LogicalKeyboardKey.altLeft;
const LogicalKeyboardKey _ctrl = LogicalKeyboardKey.controlLeft;
const LogicalKeyboardKey _meta = LogicalKeyboardKey.metaLeft;

void main() {
  for (final (platform, conventions, cmd) in [
    ('the Mac', macConventions, _meta),
    ('Linux', linuxConventions, _ctrl),
  ]) {
    // What each key held with Enter does: off, then on.
    final keys = <String, (List<LogicalKeyboardKey>, String, String)>{
      'Enter': ([], 'sp', 'lp'),
      '⇧': ([_shift], 'l', 'l'),
      '⌥': ([_alt], 'l', 'l'),
      if (cmd == _meta) '⌃': ([_ctrl], 'l', 'l'),
      'command': ([cmd], 'np', 'sp'),
      '⇧ command': ([_shift, cmd], 'l', 'n'),
    };
    for (final on in [false, true]) {
      testWidgets('on $platform, Enter starts a new line ${on ? 'on' : 'off'}'
          ': what sends, starts a line, sends now and picks', (tester) async {
        native.conventions = conventions;
        enterStartsLine.value = on;
        await _box(tester);
        for (final MapEntry(key: name, value: (holding, off, onWant))
            in keys.entries) {
          expect(
            await _enter(tester, holding),
            on ? onWant : off,
            reason: name,
          );
        }
        // The keypad's Enter is Enter.
        expect(
          await _enter(tester, [], key: LogicalKeyboardKey.numpadEnter),
          on ? 'lp' : 'sp',
        );
        expect(
          await _enter(tester, [cmd], key: LogicalKeyboardKey.numpadEnter),
          on ? 'sp' : 'np',
        );
      });
    }
  }

  test('the keys shown follow the mode, on the Mac and on Linux', () {
    expect((sendKeyLabel, sendNowKeyLabel), ('⏎', '⌘⏎'));
    enterStartsLine.value = true;
    expect((sendKeyLabel, sendNowKeyLabel), ('⌘⏎', '⇧⌘⏎'));
    native.conventions = linuxConventions;
    expect((sendKeyLabel, sendNowKeyLabel), ('Ctrl+Enter', 'Ctrl+Shift+Enter'));
    enterStartsLine.value = false;
    expect((sendKeyLabel, sendNowKeyLabel), ('Enter', 'Ctrl+Enter'));
  });

  test('the pref is saved in app.json and read back', () async {
    expect(enterStartsLine.value, isFalse);
    enterStartsLine.value = true;
    await Future<void>.delayed(Duration.zero); // its save
    expect(readSaved()['enterStartsLine'], isTrue);
    enterStartsLine.value = false;
    enterStartsLine.readFrom(readSaved()..['enterStartsLine'] = true);
    expect(enterStartsLine.value, isTrue);
  });
}
