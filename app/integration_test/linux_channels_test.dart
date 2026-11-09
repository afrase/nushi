import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nushi/clipboard_files_linux.dart';
import 'package:nushi/desktop_linux.dart';
import 'package:nushi/web_views_linux.dart';
import 'package:nushi/window_drag_linux.dart';

// The Linux runner's own channels (linux/runner: clipboard.cc, gio.cc,
// window.cc) against the real GTK and GIO, through the Dart that uses them
// (ADR 0104). Run by tools/linux-channels.sh, which gives the app a virtual
// X display, a private session bus and throwaway XDG folders whose only
// default apps are fakes that write down what they were given
// (NUSHI_PROBE names that folder): nothing on the machine opens, and
// without that folder every test skips rather than open the user's
// browser.

final String? _probe = Platform.environment['NUSHI_PROBE'];

final Object _skip = !Platform.isLinux
    ? 'Linux only'
    : _probe == null
    ? "needs tools/linux-channels.sh's fake default apps"
    : false;

/// Whether gdk-pixbuf decodes pictures here: Arch's decodes through
/// glycin, in a bwrap sandbox, which some VMs and containers can't make.
final Object _pixbuf = Platform.environment['NUSHI_PROBE_PIXBUF'] == '0'
    ? "gdk-pixbuf can't decode pictures here"
    : false;

const _browser = MethodChannel('nushi/browser');
const _desktop = MethodChannel('nushi/desktop');

/// What the fake default app [app] (browser, editor, files or mail) was
/// given,
/// one launch a line.
List<String> _launched(String app) {
  final f = File('$_probe/launched-$app');
  return f.existsSync() ? f.readAsLinesSync() : [];
}

/// Nushi's variables (NUSHI_*, NUSHID_*) the fake default app [app] was
/// started with: none, though the app has NUSHI_DATA and NUSHI_PROBE.
List<String> _inherited(String app) {
  final f = File('$_probe/environment-$app');
  return f.existsSync() ? f.readAsLinesSync() : [];
}

/// Waits on the real clock, 10 s at most, until [done]: a launch and a
/// clipboard's owner answer in their own time.
Future<void> _until(String what, FutureOr<bool> Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!await done()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// The error code [call] fails with.
Future<String> _refusal(Future<void> call) async {
  try {
    await call;
  } on PlatformException catch (e) {
    return e.code;
  }
  fail('it opened');
}

/// xclip owning the X clipboard, offering [file] as [target] alone, until
/// another owner takes it or the test ends.
Future<void> _copy(String target, String file) async {
  final xclip = await Process.start('xclip', [
    '-quiet',
    '-selection',
    'clipboard',
    '-target',
    target,
    '-in',
    file,
  ]);
  addTearDown(xclip.kill);
}

/// A [width]×[height] PNG of one color.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

/// A [width]×[height] BMP of one color: 24 bits a pixel, its rows
/// bottom up, each padded to four bytes.
Uint8List _bmp(int width, int height) {
  final row = (width * 3 + 3) & ~3;
  final size = 54 + row * height;
  final b = ByteData(size)
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4d)
    ..setUint32(2, size, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, width, Endian.little)
    ..setInt32(22, height, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, row * height, Endian.little);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      b
        ..setUint8(54 + y * row + x * 3, 0xcc)
        ..setUint8(54 + y * row + x * 3 + 1, 0x66)
        ..setUint8(54 + y * row + x * 3 + 2, 0x33);
    }
  }
  return b.buffer.asUint8List();
}

/// A PNG's width and height, from its header.
(int, int) _size(Uint8List png) {
  final header = ByteData.sublistView(png, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}

/// The file manager's interface on the session bus, saying what it was
/// asked to show.
class _FileManager extends DBusObject {
  new() : super(DBusObjectPath('/org/freedesktop/FileManager1'));

  final shown = <String>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.name != 'ShowItems') {
      return DBusMethodErrorResponse.unknownMethod();
    }
    shown.addAll(call.values[0].asStringArray());
    return DBusMethodSuccessResponse();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Before anything opens: the default apps are the fakes (the browser
  // says so by its name), or no test runs.
  setUpAll(() async {
    if (_skip != false) return;
    expect(
      await _browser.invokeMethod<String>('browserName'),
      'Nushi fake browser',
    );
  });

  late Directory work;
  setUp(() {
    work = Directory('$_probe/work')..createSync(recursive: true);
  });
  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  group('the default browser', () {
    test('opens a web address and a file, a file with the browser rather '
        'than the app its type has', () async {
      final page = File('${work.path}/my page.html')
        ..writeAsStringSync('<p>hi');
      final file = Uri.file(page.path);
      await _browser.invokeMethod<void>('open', '$file');
      await _browser.invokeMethod<void>('open', 'https://example.com/a?b=1');
      await _until('the browser', () => _launched('browser').length == 2);
      // GIO gives a local file to an app's %u as its path, as a browser
      // takes it. Each launch ends once the app has started, so the two
      // write their lines in either order.
      expect(
        _launched('browser'),
        unorderedEquals([page.path, 'https://example.com/a?b=1']),
      );
      expect(_launched('editor'), isEmpty);
      expect(Platform.environment, contains('NUSHI_DATA'));
      expect(_inherited('browser'), isEmpty);
    });

    test('opens a clicked link, and only a web one, without Nushi’s '
        'variables', () async {
      final before = _launched('browser').length;
      const web = LinuxWebViews();
      await web.openLink(Uri.parse('https://example.com/pull/7'));
      await web.openLink(Uri.file('${work.path}/run me.sh'));
      await _until('the browser', () => _launched('browser').length > before);
      expect(_launched('browser').sublist(before), [
        'https://example.com/pull/7',
      ]);
      expect(_inherited('browser'), isEmpty);
    });

    test('opens mail with the default app for mailto:, and nothing else '
        'there', () async {
      await const LinuxWebViews().openMail(
        Uri.parse('mailto:me@example.com?subject=Hi%20there'),
      );
      await _until('the mail app', () => _launched('mail').isNotEmpty);
      expect(
        _launched('mail').single,
        'mailto:me@example.com?subject=Hi%20there',
      );
      expect(_inherited('mail'), isEmpty);
      for (final url in ['https://example.com/', 'file:///etc/hosts', '']) {
        expect(
          await _refusal(_browser.invokeMethod<void>('openMail', url)),
          'refused',
          reason: url,
        );
      }
      expect(_launched('mail'), hasLength(1));
      expect(_launched('browser').where((l) => l.contains('mailto')), isEmpty);
    });

    test('refuses what is no web address or file, opening nothing', () async {
      final before = _launched('browser').length;
      for (final url in [
        'javascript:alert(1)',
        'ftp://example.com/a',
        'no address',
        '',
      ]) {
        expect(
          await _refusal(_browser.invokeMethod<void>('open', url)),
          'refused',
          reason: url,
        );
      }
      expect(await _refusal(_browser.invokeMethod<void>('open')), 'refused');
      expect(_launched('browser'), hasLength(before));
    });

    test('is none when no app opens https, which open says', () async {
      final fake = File('$_probe/data/applications/nushi-fake-browser.desktop');
      final entry = fake.readAsStringSync();
      fake.deleteSync();
      addTearDown(() => fake.writeAsStringSync(entry));
      // GIO watches the folder, and reads it again once it changes.
      await _until(
        'the browser to go',
        () async => await _browser.invokeMethod<String>('browserName') == null,
      );
      expect(
        await _refusal(
          _browser.invokeMethod<void>('open', 'https://example.com/'),
        ),
        'no-browser',
      );
      fake.writeAsStringSync(entry);
      await _until(
        'the browser to come back',
        () async => await _browser.invokeMethod<String>('browserName') != null,
      );
    });
  }, skip: _skip);

  group('the desktop', () {
    test('opens a file as text with the default app for text, whatever its '
        'type', () async {
      final script = File('${work.path}/run me.sh')
        ..writeAsStringSync('echo hi');
      await const LinuxDesktop().openAsText(script.path);
      await _until('the editor', () => _launched('editor').isNotEmpty);
      expect(_launched('editor').last, script.path);
      expect(_inherited('editor'), isEmpty);
      expect(
        await _refusal(_desktop.invokeMethod<void>('openAsText', 'a/b.txt')),
        'refused',
      );
    });

    test('shows a file in the file manager on the bus, else opens its '
        'folder with the default app for folders', () async {
      final file = File('${work.path}/a b.txt')..writeAsStringSync('x');
      final bus = DBusClient.session();
      addTearDown(bus.close);
      final manager = _FileManager();
      await bus.registerObject(manager);
      expect(
        await bus.requestName('org.freedesktop.FileManager1'),
        DBusRequestNameReply.primaryOwner,
      );
      await const LinuxDesktop().reveal(file.path);
      expect(manager.shown, ['${Uri.file(file.path)}']);
      expect(_launched('files'), isEmpty);

      await bus.releaseName('org.freedesktop.FileManager1');
      await const LinuxDesktop().reveal(file.path);
      await _until('the folder', () => _launched('files').isNotEmpty);
      expect(_launched('files').single, work.path);
      expect(_inherited('files'), isEmpty);
      expect(manager.shown, hasLength(1));
      expect(
        await _refusal(_desktop.invokeMethod<void>('openFolder', 'a/b')),
        'refused',
      );
    });
  }, skip: _skip);

  group('the clipboard', () {
    const clipboard = LinuxClipboardFiles();

    test("gives a file manager's copied files, only this machine's", () async {
      final list = File('${work.path}/uris')
        ..writeAsStringSync(
          [
            'file:///home/me/a%20b.txt',
            'https://example.com/c.txt',
            'file://elsewhere/etc/hosts',
            'file://localhost/srv/d.png',
            '',
          ].join('\r\n'),
        );
      await _copy('text/uri-list', list.path);
      await _until(
        'the files',
        () async => (await clipboard.files()).isNotEmpty,
      );
      expect(await clipboard.files(), ['/home/me/a b.txt', '/srv/d.png']);
      expect(await clipboard.image(), isNull);
    });

    test('gives a copied picture as PNG', () async {
      final png = File('${work.path}/p.png')
        ..writeAsBytesSync(await _png(7, 5));
      await _copy('image/png', png.path);
      await _until('the picture', () async => await clipboard.image() != null);
      final image = (await clipboard.image())!;
      expect(image.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_size(image), (7, 5));
      expect(await clipboard.files(), isEmpty);

      // The next owner's "PNG" that isn't one is none.
      final fake = File('${work.path}/fake.png')..writeAsStringSync('<svg/>');
      await _copy('image/png', fake.path);
      await _until('no picture', () async => await clipboard.image() == null);
    });

    test('gives a picture of another kind as PNG', () async {
      final bmp = File('${work.path}/p.bmp')..writeAsBytesSync(_bmp(7, 5));
      await _copy('image/bmp', bmp.path);
      await _until('the picture', () async => await clipboard.image() != null);
      final image = (await clipboard.image())!;
      expect(image.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_size(image), (7, 5));
    }, skip: _pixbuf);

    test('gives no picture or files for copied text', () async {
      await Clipboard.setData(const ClipboardData(text: 'file:///etc/hosts'));
      await _until(
        'the text',
        () async =>
            (await Clipboard.getData(Clipboard.kTextPlain))?.text != null,
      );
      expect(await clipboard.image(), isNull);
      expect(await clipboard.files(), isEmpty);
    });
  }, skip: _skip);

  group('the window', () {
    test('comes to the front with a token and without', () async {
      const window = LinuxWindow();
      await window.present(token: 'nushi-test_TIME0');
      await window.present();
    });
  }, skip: _skip);
}
