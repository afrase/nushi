import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/clipboard_files_linux.dart';
import 'package:nushi/daemon.dart' show dataDir;
import 'package:nushi/desktop_linux.dart';

// Linux's clipboard files and desktop over their channels and D-Bus, on any
// host: the runner's side is answered here as `linux/runner` answers it
// (integration_test/linux_channels_test.dart drives the real one), the
// file manager by a fake on a bus of the test's own.

/// The file manager's interface, saying what it was asked to show.
class _FileManager extends DBusObject {
  new() : super(DBusObjectPath('/org/freedesktop/FileManager1'));

  /// Each call's URIs, and its startup id after them.
  final shown = <List<String>>[];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == 'org.freedesktop.FileManager1' &&
        call.name == 'ShowItems' &&
        call.signature == DBusSignature('ass')) {
      shown.add([...call.values[0].asStringArray(), call.values[1].asString()]);
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

/// A session bus of the test's own, and a client on it. The server takes
/// any uid (package:dbus finds none to send on the Mac), so it runs on any
/// host (ADR 0102).
Future<(DBusServer, DBusClient Function())> _bus() async {
  final dir = Directory.systemTemp.createTempSync('nushi-bus-');
  final server = DBusServer();
  final address = await server.listenAddress(DBusAddress.unix(dir: dir));
  final clients = <DBusClient>[];
  addTearDown(() async {
    for (final c in clients) {
      await c.close();
    }
    await server.close();
    dir.deleteSync(recursive: true);
  });
  return (
    server,
    () {
      final c = DBusClient(address, authClient: DBusAuthClient(uid: '0'));
      clients.add(c);
      return c;
    },
  );
}

/// The runner's [channel], answered by [answer] and saying what it was
/// asked, until the test ends.
List<MethodCall> _answer(String channel, Object? Function(MethodCall) answer) {
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(MethodChannel(channel), (c) async {
          calls.add(c);
          return answer(c);
        });
  addTearDown(
    () => messenger.setMockMethodCallHandler(MethodChannel(channel), null),
  );
  return calls;
}

/// app.log's lines that say the desktop opened nothing.
List<String> _nothingOpened() {
  final log = File('$dataDir/app.log');
  return log.existsSync()
      ? log
            .readAsLinesSync()
            .where((l) => l.contains('the desktop opened nothing'))
            .toList()
      : [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("the clipboard's files and picture come from the runner, none when "
      'it has none', () async {
    final png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
    var full = true;
    final calls = _answer(
      'nushi/clipboard',
      (c) => switch (c.method) {
        'files' when full => ['/home/me/a b.txt', '/home/me/c.png'],
        'image' when full => png,
        _ => null,
      },
    );
    const clipboard = LinuxClipboardFiles();
    expect(await clipboard.files(), ['/home/me/a b.txt', '/home/me/c.png']);
    expect(await clipboard.image(), png);
    full = false;
    expect(await clipboard.files(), isEmpty);
    expect(await clipboard.image(), isNull);
    expect(
      [for (final c in calls) c.method],
      ['files', 'image', 'files', 'image'],
    );
  });

  test('a file shows selected in the file manager, by its file URI, and '
      'nothing else opens', () async {
    final (_, client) = await _bus();
    final manager = _FileManager();
    final service = client();
    await service.requestName('org.freedesktop.FileManager1');
    await service.registerObject(manager);
    final opened = <Uri>[];
    final desktop = LinuxDesktop(
      bus: client(),
      launch: (url) async {
        opened.add(url);
        return true;
      },
    );
    await desktop.reveal('/home/me/my notes/a#1.md');
    expect(manager.shown, [
      ['file:///home/me/my%20notes/a%231.md', ''],
    ]);
    expect(opened, isEmpty);
  });

  test('with no file manager on the bus, or no bus, the folder opens '
      'instead', () async {
    final (_, client) = await _bus();
    final opened = <Uri>[];
    Future<bool> launch(Uri url) async {
      opened.add(url);
      return true;
    }

    await LinuxDesktop(bus: client(), launch: launch).reveal('/home/me/a.txt');
    final gone = DBusClient(
      DBusAddress.unix(path: '${Directory.systemTemp.path}/nushi-no-bus'),
      authClient: DBusAuthClient(uid: '0'),
    );
    addTearDown(gone.close);
    await LinuxDesktop(bus: gone, launch: launch).reveal('/srv/x/b.txt');
    expect(opened, [Uri.directory('/home/me'), Uri.directory('/srv/x')]);
  });

  test('a folder opens with its default app; one that opens nothing is '
      'logged without its path, never thrown', () async {
    final opened = <Uri>[];
    var works = true;
    final desktop = LinuxDesktop(
      launch: (url) async {
        opened.add(url);
        if (!works) {
          throw PlatformException(code: 'Launch Error', message: 'no app');
        }
        return true;
      },
    );
    final before = _nothingOpened().length;
    await desktop.openFolder('/home/me/themes');
    expect(opened, [Uri.directory('/home/me/themes')]);
    expect(_nothingOpened(), hasLength(before));
    works = false;
    await desktop.openFolder('/home/me/themes');
    expect(_nothingOpened(), hasLength(before + 1));
    expect(_nothingOpened().last, contains('call=openFolder'));
    expect(_nothingOpened().last, contains('code="Launch Error"'));
    expect(_nothingOpened().last, isNot(contains('/home/me')));
  });

  test('a file opens as text through the runner, and its refusal is logged '
      'the same way', () async {
    var editor = true;
    final calls = _answer(
      'nushi/desktop',
      (c) => editor
          ? null
          : throw PlatformException(
              code: 'no-editor',
              message: 'No default app for text is set',
            ),
    );
    final before = _nothingOpened().length;
    const desktop = LinuxDesktop();
    await desktop.openAsText('/home/me/.claude/skills/a/SKILL.md');
    expect(_nothingOpened(), hasLength(before));
    editor = false;
    await desktop.openAsText('/home/me/.claude/skills/a/SKILL.md');
    expect([
      for (final c in calls) (c.method, c.arguments),
    ], List.filled(2, ('openAsText', '/home/me/.claude/skills/a/SKILL.md')));
    expect(_nothingOpened(), hasLength(before + 1));
    expect(_nothingOpened().last, contains('code=no-editor'));
  });
}
