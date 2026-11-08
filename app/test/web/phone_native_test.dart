// The phone's web app shares the desktop's widgets but has no native edge:
// `native` is never set in the browser (ADR 0097, 0102). A shared widget
// reads what differs by platform through the getters that answer for the
// phone too, so the previews the phone opens build without it.
// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/phone/preview_screen.dart';
import 'package:nushi/sidebar_button.dart';
import 'package:nushi/speller.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_views.dart';
import 'package:nushi/window_drag.dart';

import '../fake_daemon.dart';

void main() {
  test('the getters answer for the phone without the native edge', () {
    expect(conventions, same(macConventions));
    expect(webEmbedded, isFalse);
    expect(headersMoveWindow, isFalse);
    expect(lightsInset, 0);
    expect(speller, isNull);
  });

  test('paired with Linux, the phone says its words but keeps its own '
      'modifier', () {
    phoneHost = linuxConventions;
    addTearDown(() => phoneHost = macConventions);
    expect(conventions.machine, 'computer');
    expect(conventions.reveal, 'Show in Folder');
    expect(conventions.commandKey, CommandKey.meta);
  });

  testWidgets('a PDF’s preview and a CSV’s open on the phone', (tester) async {
    final fake = FakeDaemon([chat('c', 'claude', 'The landing page')])
      ..files['report.pdf'] = utf8.encode('%PDF-1.7')
      ..files['stock.csv'] = utf8.encode('name,count\nkettle,3\n');
    // The phone's daemon, which its link pings (phone/link.dart).
    final d = Daemon(transport: fake, remote: true);
    await d.ping();
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    Future<void> open(String path) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: const NushiTheme(Tokens.dark).toThemeData(),
          home: PreviewScreen(d, d.chats['c']!, path, key: ValueKey(path)),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    }

    await open('report.pdf');
    expect(find.text('Open it on your Mac to see it.'), findsOneWidget);
    await open('stock.csv');
    expect(find.text('kettle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  });
}
