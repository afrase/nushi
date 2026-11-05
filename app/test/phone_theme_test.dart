// The phone's theme (ADR 0086): one of the built-ins, its own setting, kept
// in the browser's storage and read before anything shows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/phone/chats_screen.dart';
import 'package:nushi/phone/phone.dart';
import 'package:nushi/phone/phone_app.dart';
import 'package:nushi/phone/platform.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

Future<(Phone, PhonePlatform)> _phone(
  WidgetTester tester, {
  String? theme,
}) async {
  viewport(tester, const Size(390, 844), ratio: 2, brightness: Brightness.dark);
  final fake = FakeDaemon([chat('c', 'claude', 'Fix the login')]);
  final platform = PhonePlatform()
    ..saved = pairedRecord()
    ..theme = theme;
  final phone = await startPhone(tester, fake, platform: platform);
  return (phone, platform);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a theme picked in Settings repaints at once and is kept', (
    tester,
  ) async {
    final (phone, platform) = await _phone(tester);
    expect(phone.theme.value, same(nushiTheme));
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOne);
    for (final c in builtInThemes) {
      expect(find.text(c.name), findsOne);
    }
    await tester.tap(find.text('Solarized'));
    await tester.pumpAndSettle();
    final solarized = builtInTheme('solarized')!;
    expect(phone.theme.value, same(solarized));
    expect(platform.theme, 'solarized');
    final t = NushiTheme.of(tester.element(find.text('Solarized'))).t;
    expect(t, same(solarized.dark));
    await render(tester, find.byType(PhoneApp), 'phone_theme_settings');
    await endPhone(tester, phone);
  });

  testWidgets('a theme kept shows from the start; one it doesn’t know is '
      'Nushi’s', (tester) async {
    final (phone, _) = await _phone(tester, theme: 'nord');
    expect(phone.theme.value.id, 'nord');
    final t = NushiTheme.of(tester.element(find.byType(ChatsScreen))).t;
    expect(t, same(builtInTheme('nord')!.dark));
    await endPhone(tester, phone);

    final (other, _) = await _phone(tester, theme: 'custom:Mine');
    expect(other.theme.value, same(nushiTheme));
    await endPhone(tester, other);
  });
}
