import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/file_mode_linux.dart';
import 'package:nushi/login_item.dart';
import 'package:nushi/login_item_linux.dart';
import 'package:nushi/native.dart';

import 'fake_app_install.dart';

void main() {
  late Directory dir;
  late String daemon;
  late LinuxLoginItem item;

  setUp(() {
    if (Platform.isLinux) native.fileModes = const LinuxFileModes();
    dir = Directory.systemTemp.createTempSync('nushi-login-');
    addTearDown(() => dir.deleteSync(recursive: true));
    daemon = '${dir.path}/opt/Nushi app/lib/nushid';
    File(daemon).createSync(recursive: true);
    item = LinuxLoginItem(
      install: FakeAppInstall()..daemon = daemon,
      environment: {'HOME': '/nowhere', 'XDG_CONFIG_HOME': '${dir.path}/cfg'},
    );
  });

  test('its file is in the XDG config folder, else ~/.config', () {
    expect(
      item.file.path,
      '${dir.path}/cfg/autostart/com.nushihq.Nushi.daemon.desktop',
    );
    expect(
      LinuxLoginItem(environment: {'HOME': '/home/u', 'XDG_CONFIG_HOME': 'rel'})
          .file
          .path,
      '/home/u/.config/autostart/com.nushihq.Nushi.daemon.desktop',
    );
  });

  test(
    'on writes the autostart entry whole, only yours; off removes it',
    () async {
      expect(await item.status(), LoginItemState.off);
      expect(await item.set(on: true), LoginItemState.on);
      expect(item.file.readAsStringSync(), '''
[Desktop Entry]
Type=Application
Name=Nushi daemon
Exec="${dir.path}/opt/Nushi app/lib/nushid" -login
NoDisplay=true
X-GNOME-Autostart-enabled=true
''');
      expect(FileStat.statSync(item.file.path).mode & 0x1ff, 0x180);
      expect(await item.openSettings(), LoginItemState.on);
      expect(await item.set(on: false), LoginItemState.off);
      expect(item.file.existsSync(), isFalse);
      expect(await item.set(on: false), LoginItemState.off);
    },
  );

  test('an entry whose nushid is gone, or that the desktop turned off, is '
      'off; turning it on writes it anew', () async {
    await item.set(on: true);
    final text = item.file.readAsStringSync();
    item.file.writeAsStringSync(text.replaceAll('=true', '=false'));
    expect(await item.status(), LoginItemState.off);
    item.file.writeAsStringSync('$text\nHidden=true\n');
    expect(await item.status(), LoginItemState.off);
    item.file.writeAsStringSync(text.replaceAll('Nushi app', 'Old'));
    expect(await item.status(), LoginItemState.off);
    expect(await item.set(on: true), LoginItemState.on);
    expect(item.file.readAsStringSync(), text);
  });

  test('without a packaged daemon, on writes nothing', () async {
    final dev = LinuxLoginItem(
      install: FakeAppInstall(),
      environment: {'XDG_CONFIG_HOME': '${dir.path}/cfg'},
    );
    expect(await dev.set(on: true), LoginItemState.off);
    expect(dev.file.existsSync(), isFalse);
  });

  test('Exec quotes a path as the desktop entry spec says, and reads it '
      'back', () {
    for (final (path, exec) in [
      ('/opt/nushi/lib/nushid', '/opt/nushi/lib/nushid -login'),
      ('/opt/a b/nushid', '"/opt/a b/nushid" -login'),
      (r'/opt/a"$`\b/nushid', r'"/opt/a\\"\\$\\`\\\\b/nushid" -login'),
      ('/opt/100%/nushid', '/opt/100%%/nushid -login'),
      ("/opt/it's/nushid", '"/opt/it\'s/nushid" -login'),
    ]) {
      expect(execValue([path, '-login']), exec, reason: path);
      expect(execProgram(exec), path, reason: exec);
    }
    expect(execProgram('"/opt/unclosed'), isNull);
    expect(() => execValue(['/opt/a\nb']), throwsArgumentError);
  });
}
