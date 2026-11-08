import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/app_install_linux.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/file_mode.dart';
import 'package:nushi/file_mode_linux.dart';
import 'package:nushi/login_item_linux.dart';
import 'package:nushi/main.dart';
import 'package:nushi/native.dart';
import 'package:nushi/native_linux.dart';
import 'package:nushi/window_drag_linux.dart';
import 'package:nushi/window_drag_macos.dart';

import 'fake_daemon.dart';

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

int _mode(String path) => FileStat.statSync(path).mode & 0x1ff;

void main() {
  test("Linux's set is whole, keeps the system's title bar and has no menu "
      'bar and no diagrams yet', () async {
    final set = linuxNative();
    expect(set.conventions, same(linuxConventions));
    expect(set.window.menuBar, isFalse);
    expect(const MacWindow().menuBar, isTrue);
    expect(set.install, isA<LinuxAppInstall>());
    expect(set.loginItem, isA<LinuxLoginItem>());
    expect(await set.web.sincePress(), isNull);
    expect(set.web.embedded, isFalse); // outside_page_test has the rest
    final d = await set.diagrams.draw(
      'graph TD; a-->b',
      dark: false,
      width: 400,
      background: const Color(0xFFFFFFFF),
      foreground: const Color(0xFF000000),
    );
    expect((d.png, d.error), (null, 'Diagrams aren’t drawn on Linux yet'));
  });

  test('widgets read the native set’s conventions', () {
    expect(conventions, same(macConventions));
    native.conventions = linuxConventions;
    expect(conventions.commandKey, CommandKey.control);
    expect(conventions.reveal, 'Show in Folder');
  });

  // Flutter's platform menus throw off the Mac (PlatformProvidedMenuItem
  // has no menu there): the window there is the app without them.
  testWidgets('on Linux the window has no menu bar, and its keys and views '
      'are there', (tester) async {
    native.window = const LinuxWindow();
    final d = await FakeDaemon([chat('a', 'claude', 'Fix the login redirect')])
        .connect(tester);
    await tester.pumpWidget(NushiApp(daemon: d));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(find.byType(Shortcuts), findsWidgets);
    expect(find.text('Fix the login redirect'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
  }, variant: _linux);

  test("Linux's chmod sets a file's and a folder's modes", () {
    native.fileModes = const LinuxFileModes();
    final tmp = Directory.systemTemp.createTempSync('nushi-mode-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dir = Directory('${tmp.path}/a');
    privateDir(dir);
    expect(_mode(dir.path), 0x1c0);
    final f = File('${dir.path}/x');
    writeWhole(f, [1]);
    expect(_mode(f.path), 0x180);
    setMode(f.path, 0x1a4);
    expect(_mode(f.path), 0x1a4);
    expect(
      () => setMode('${tmp.path}/none', 0x180),
      throwsA(isA<FileSystemException>()),
    );
  }, skip: Platform.isLinux ? false : "Linux's libc only");
}
