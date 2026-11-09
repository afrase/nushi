import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/alerts.dart';
import 'package:nushi/alerts_linux.dart';
import 'package:nushi/session_bus_linux.dart';
import 'package:nushi/window_drag.dart';
import 'package:nushi/window_drag_linux.dart';

// Linux's notifications against a bus of the test's own (package:dbus's
// server, in this process) with a fake notification service on it, so
// they run on the Mac too: the client says its uid, which only Linux's
// libc would otherwise give (ADR 0104).

const _service = 'org.freedesktop.Notifications';
final _path = DBusObjectPath('/org/freedesktop/Notifications');

/// A notification service that keeps what it was sent, numbering each
/// new one, and says whether it reads markup.
class _Notifications extends DBusObject {
  new({this.markup = true}) : super(_path);

  final bool markup;
  final notified = <List<DBusValue>>[];
  final closed = <int>[];
  var _next = 0;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async =>
      switch (call.name) {
        'GetCapabilities' => DBusMethodSuccessResponse([
          DBusArray.string(['actions', if (markup) 'body-markup']),
        ]),
        'Notify' => _notify(call.values),
        'CloseNotification' => _close(call.values.single.asUint32()),
        _ => DBusMethodErrorResponse.unknownMethod(),
      };

  DBusMethodResponse _notify(List<DBusValue> values) {
    notified.add(values);
    final replaces = values[1].asUint32();
    return DBusMethodSuccessResponse([
      DBusUint32(replaces != 0 ? replaces : ++_next),
    ]);
  }

  DBusMethodResponse _close(int number) {
    closed.add(number);
    return DBusMethodSuccessResponse();
  }

  /// A click on notification [number], as GNOME Shell sends it: its
  /// activation token, then the action.
  Future<void> click(int number, {String? token}) async {
    if (token != null) {
      await emitSignal(_service, 'ActivationToken', [
        DBusUint32(number),
        DBusString(token),
      ]);
    }
    await emitSignal(_service, 'ActionInvoked', [
      DBusUint32(number),
      const DBusString('default'),
    ]);
  }
}

/// A window that says when it was brought to the front, and with what.
class _Window implements AppWindow {
  final presented = <String?>[];
  static const _linux = LinuxWindow();

  @override
  double get titleInset => _linux.titleInset;

  @override
  bool get headersMoveWindow => false;

  @override
  bool get menuBar => false;

  @override
  Future<void> present({String? token}) async => presented.add(token);

  @override
  Future<void> arm(int micros) async {}

  @override
  Future<void> zoom() async {}
}

/// A server that can start a notification service it doesn't run yet.
class _Activating extends DBusServer {
  @override
  List<String> get activatableNames => [_service];
}

/// A bus of the test's own: [server] on a socket in a temp folder.
Future<DBusAddress> _bus(DBusServer server) async {
  final dir = Directory.systemTemp.createTempSync('nushi-bus-');
  final address = await server.listenAddress(DBusAddress.unix(dir: dir));
  addTearDown(() async {
    await server.close();
    dir.deleteSync(recursive: true);
  });
  return address;
}

/// A client of the bus at [address], as the test's uid needs no libc.
DBusClient _client(DBusAddress address) {
  final c = DBusClient(address, authClient: DBusAuthClient(uid: '0'));
  addTearDown(c.close);
  return c;
}

/// [service] on a new bus, and a [LinuxAlertCenter] over it.
Future<(LinuxAlertCenter, _Window, DBusClient)> _center(
  _Notifications service,
) async {
  final address = await _bus(DBusServer());
  final host = _client(address);
  await host.registerObject(service);
  await host.requestName(_service);
  final window = _Window();
  return (LinuxAlertCenter(_client(address), window), window, host);
}

Future<void> _post(
  LinuxAlertCenter center,
  String id, {
  String chat = 'a',
  String title = 'Claude finished',
  String body = 'Fix the login redirect',
  bool sound = true,
}) => center.post(id: id, chat: chat, title: title, body: body, sound: sound);

/// Waits until [done], as the bus's messages cross its sockets: every
/// 10 ms, 10 s at most.
Future<void> _until(bool Function() done) async {
  for (var i = 0; !done(); i++) {
    if (i == 1000) fail('not done after 10 s');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A moment for what should not happen to show if it does: too short, it
/// lets a test pass, never fail.
Future<void> _moment() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('a notification says it is Nushi’s, its body escaped where the '
      'service reads markup (the summary is plain text), with the sound or '
      'without', () async {
    final service = _Notifications();
    final (center, _, _) = await _center(service);
    await _post(
      center,
      'a/ended',
      title: 'Claude & Co <i>finished</i>',
      body: 'Fix <b>this</b> & that\nexit status 1',
    );
    await _post(center, 'a/question', sound: false);
    final [sent, quiet] = service.notified;
    expect(sent[0].asString(), 'Nushi');
    expect(sent[1].asUint32(), 0);
    expect(sent[2].asString(), 'com.nushihq.Nushi');
    expect(sent[3].asString(), 'Claude & Co <i>finished</i>');
    expect(
      sent[4].asString(),
      'Fix &lt;b&gt;this&lt;/b&gt; &amp; that\nexit status 1',
    );
    expect(sent[5].asStringArray(), ['default', 'Open']);
    expect(sent[6].asStringVariantDict(), {
      'desktop-entry': const DBusString('com.nushihq.Nushi'),
      'category': const DBusString('im.received'),
      'sound-name': const DBusString('message-new-instant'),
    });
    expect(sent[7].asInt32(), -1);
    expect(
      quiet[6].asStringVariantDict()['suppress-sound'],
      const DBusBoolean(true),
    );
    expect(quiet[6].asStringVariantDict(), isNot(contains('sound-name')));

    final plain = _Notifications(markup: false);
    final (other, _, _) = await _center(plain);
    await _post(other, 'a/ended', body: 'a <b> & c');
    expect(plain.notified.single[4].asString(), 'a <b> & c');
  });

  test('the same name replaces the one shown, also when posted twice at '
      'once; clearing a chat closes its own', () async {
    final service = _Notifications();
    final (center, _, _) = await _center(service);
    await Future.wait([
      _post(center, 'a/ended'),
      _post(center, 'a/ended', title: 'Claude’s turn failed'),
    ]);
    await _post(center, 'a/question');
    await _post(center, 'b/ended', chat: 'b');
    expect([for (final n in service.notified) n[1].asUint32()], [0, 1, 0, 0]);

    await center.clear('a');
    expect(service.closed, unorderedEquals([1, 2]));
    await center.withdraw(['b/ended', 'b/permission']);
    expect(service.closed, unorderedEquals([1, 2, 3]));
    // A name closed is posted anew.
    await _post(center, 'a/ended');
    expect(service.notified.last[1].asUint32(), 0);
  });

  test('one closed by the user is posted anew, not replaced', () async {
    final service = _Notifications();
    final (center, _, _) = await _center(service);
    final opened = <String>[];
    center.onOpen(opened.add);
    await _post(center, 'a/ended');
    await _post(center, 'b/ended', chat: 'b');
    await service.emitSignal(_service, 'NotificationClosed', [
      const DBusUint32(1),
      const DBusUint32(2),
    ]);
    // A click after it, so the close has arrived once the click has.
    await service.click(2);
    await _until(() => opened.isNotEmpty);
    await _post(center, 'a/ended');
    expect(service.notified.last[1].asUint32(), 0);
    await center.clear('a');
    expect(service.closed, [3]);
  });

  test("a click opens its chat and brings the window up with the click's "
      'token; an action of no notification of ours does nothing', () async {
    final service = _Notifications();
    final (center, window, _) = await _center(service);
    final opened = <String>[];
    center.onOpen(opened.add);
    await _post(center, 'a/question');
    await _post(center, 'b/ended', chat: 'b');
    await service.click(1, token: 'gnome-shell/Nushi/1234-0-host_TIME5');
    await service.click(9);
    await service.click(2);
    await _until(() => opened.length == 2);
    expect(opened, ['a', 'b']);
    expect(window.presented, ['gnome-shell/Nushi/1234-0-host_TIME5', null]);

    center.onOpen(null);
    await service.click(1);
    await _moment();
    expect(opened, ['a', 'b']);
  });

  test("the badge is the launcher entry's count of the app's .desktop "
      'file', () async {
    final address = await _bus(DBusServer());
    final dock = _client(address);
    final updates = <DBusSignal>[];
    final sub = DBusSignalStream(
      dock,
      interface: 'com.canonical.Unity.LauncherEntry',
      name: 'Update',
    ).listen(updates.add);
    addTearDown(sub.cancel);
    // Its match is the bus's once the ping that follows it is answered.
    await dock.ping();
    final center = LinuxAlertCenter(_client(address), _Window());
    await center.badge('3');
    await center.badge('');
    await _until(() => updates.length == 2);
    expect(
      [for (final u in updates) u.values.first.asString()],
      [
        'application://com.nushihq.Nushi.desktop',
        'application://com.nushihq.Nushi.desktop',
      ],
    );
    expect(
      [for (final u in updates) u.values.last.asStringVariantDict()],
      [
        {'count': const DBusInt64(3), 'count-visible': const DBusBoolean(true)},
        {
          'count': const DBusInt64(0),
          'count-visible': const DBusBoolean(false),
        },
      ],
    );
  });

  test('allowed while a notification service runs or can start; no answer '
      'without one or without a bus', () async {
    final (running, _, _) = await _center(_Notifications());
    expect(await running.allowed(), NotifyPermission.allowed);

    final activating = LinuxAlertCenter(
      _client(await _bus(_Activating())),
      _Window(),
    );
    expect(await activating.allowed(), NotifyPermission.allowed);

    final none = LinuxAlertCenter(_client(await _bus(DBusServer())), _Window());
    expect(await none.allowed(), isNull);

    final gone = DBusServer();
    final address = await _bus(gone);
    await gone.close();
    expect(
      await LinuxAlertCenter(_client(address), _Window()).allowed(),
      isNull,
    );

    final nothing = LinuxAlertCenter(null, _Window());
    expect(await nothing.allowed(), isNull);
    await _post(nothing, 'a/ended');
    await nothing.clear('a');
    await nothing.badge('1');
  });

  test("a bus that can't be reached is as none: every call returns, and "
      'nothing is thrown', () async {
    final dir = Directory.systemTemp.createTempSync('nushi-bus-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final center = LinuxAlertCenter(
      _client(DBusAddress.unix(path: '${dir.path}/bus')),
      _Window(),
    )..onOpen((_) {});
    const limit = Duration(seconds: 10);
    await _post(center, 'a/ended').timeout(limit);
    await _post(center, 'a/question').timeout(limit);
    expect(await center.allowed().timeout(limit), isNull);
    expect(await center.allowed().timeout(limit), isNull);
    await center.withdraw(['a/ended']).timeout(limit);
    await center.clear('a').timeout(limit);
    await center.badge('2').timeout(limit);
  });

  test('the session bus is the one the environment names, else the '
      "runtime folder's, else none", () {
    expect(sessionBusAt({}), isNull);
    expect(sessionBusAt({'XDG_RUNTIME_DIR': 'relative'}), isNull);
    expect(sessionBusAt({'XDG_RUNTIME_DIR': '/run/user/1000'}), isNotNull);
    expect(
      sessionBusAt({
        'DBUS_SESSION_BUS_ADDRESS':
            'unix:path=/run/user/1000/bus;unix:abstract=/tmp/x',
      }),
      isNotNull,
    );
    expect(sessionBusAt({'DBUS_SESSION_BUS_ADDRESS': 'nonsense'}), isNull);
  });

  test('escaping leaves nothing markup reads', () {
    expect(
      escaped('<a href="x">&amp;</a>'),
      '&lt;a href="x"&gt;&amp;amp;&lt;/a&gt;',
    );
  });
}
