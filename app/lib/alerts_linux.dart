import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:nushi/alerts.dart';
import 'package:nushi/window_drag.dart';

const _service = 'org.freedesktop.Notifications';
final _path = DBusObjectPath('/org/freedesktop/Notifications');

/// The app's id, which names its `.desktop` file and its icon (ADR 0104).
const _app = 'com.nushihq.Nushi';

/// Linux's notifications, through the desktop's notification service
/// (`org.freedesktop.Notifications`: GNOME Shell's, KDE's, dunst, mako)
/// on the session bus, and the count on the app's icon through Unity's
/// launcher entry, which Ubuntu's dock, Dash to Dock and KDE's task
/// manager show (ADR 0104). The service lists nothing it has shown, so
/// what was posted is kept here: each name's number from the service
/// (sent back to replace it) and each chat's names. A click on one opens
/// its chat and brings the window to the front with the token the desktop
/// gave the click. Calls run one at a time, in order, so a name posted
/// twice in a row is replaced, never shown twice. A bus that doesn't
/// answer at first is as none, for the app's run.
class LinuxAlertCenter implements AlertCenter {
  /// Over the session bus given, none (nothing posted, no permission)
  /// when null, bringing the window given to the front on a click.
  new(this._bus, this._window);

  final DBusClient? _bus;
  final AppWindow _window;

  /// The bus once it has answered a ping, or null: package:dbus (0.7.15)
  /// leaves a client whose first connection failed waiting for good on
  /// every later call, and throws that failure where a signal stream
  /// subscribes, so nothing else is asked of it before it answers.
  late final Future<DBusClient?> _reached = () async {
    final bus = _bus;
    if (bus == null) return null;
    try {
      await bus.ping().timeout(const Duration(seconds: 5));
      return bus;
    } on Object {
      bus.close().ignore();
      return null;
    }
  }();

  final _numbers = <String, int>{}; // a name's number from the service
  final _names = <int, String>{}; // a number's name
  final _chats = <String, String>{}; // a name's chat
  final _tokens = <int, String>{}; // a click's activation token, by number
  void Function(String chat)? _open;
  StreamSubscription<DBusSignal>? _signals;
  Future<bool>? _markup;
  Future<void> _last = Future.value();

  DBusRemoteObject _notifications(DBusClient bus) =>
      DBusRemoteObject(bus, name: _service, path: _path);

  /// Runs [call] after every call before it, whatever they did.
  Future<T> _inTurn<T>(Future<T> Function() call) {
    final done = _last.then((_) => call());
    _last = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  @override
  Future<void> post({
    required String id,
    required String chat,
    required String title,
    required String body,
    required bool sound,
  }) async {
    final bus = await _reached;
    if (bus == null) return;
    _listen(bus);
    await _inTurn(() async {
      // Markup the service would read in the body, from a chat's title
      // (the agent's words) or a failure, is shown as written. The
      // summary is plain text, which the service escapes itself.
      final escape = await (_markup ??= _bodyMarkup(bus));
      final reply = await _notifications(bus).callMethod(_service, 'Notify', [
        const DBusString('Nushi'),
        DBusUint32(_numbers[id] ?? 0),
        const DBusString(_app),
        DBusString(title),
        DBusString(escape ? escaped(body) : body),
        DBusArray.string(['default', 'Open']),
        DBusDict.stringVariant({
          'desktop-entry': const DBusString(_app),
          'category': const DBusString('im.received'),
          if (sound)
            'sound-name': const DBusString('message-new-instant')
          else
            'suppress-sound': const DBusBoolean(true),
        }),
        const DBusInt32(-1),
      ], replySignature: DBusSignature('u'));
      final number = reply.returnValues.single.asUint32();
      if (_numbers[id] case final old? when old != number) _names.remove(old);
      _numbers[id] = number;
      _names[number] = id;
      _chats[id] = chat;
    });
  }

  /// Whether the service reads markup in a notification's body (its
  /// `body-markup` capability; dunst and GNOME Shell do).
  Future<bool> _bodyMarkup(DBusClient bus) async {
    try {
      final reply = await _notifications(bus).callMethod(
        _service,
        'GetCapabilities',
        const [],
        replySignature: DBusSignature('as'),
      );
      return reply.returnValues.single.asStringArray().contains('body-markup');
    } on Object {
      _markup = null; // asked again with the next one
      return true;
    }
  }

  @override
  Future<void> withdraw(List<String> ids) async {
    final bus = await _reached;
    if (bus == null) return;
    await _inTurn(() => _close(bus, ids));
  }

  @override
  Future<void> clear(String chat) async {
    final bus = await _reached;
    if (bus == null) return;
    await _inTurn(
      () => _close(bus, [
        for (final MapEntry(key: id, value: c) in _chats.entries)
          if (c == chat) id,
      ]),
    );
  }

  /// Closes the notifications named [ids] that are shown.
  Future<void> _close(DBusClient bus, List<String> ids) async {
    for (final id in ids) {
      final number = _numbers.remove(id);
      _chats.remove(id);
      if (number == null) continue;
      _names.remove(number);
      _tokens.remove(number);
      await _notifications(bus).callMethod(_service, 'CloseNotification', [
        DBusUint32(number),
      ], replySignature: DBusSignature.empty);
    }
  }

  /// The count of [label] (digits, or '' for none), as the launcher
  /// entry's Update signal, which no one answers.
  @override
  Future<void> badge(String label) async {
    final count = int.tryParse(label) ?? 0;
    await (await _reached)?.emitSignal(
      path: DBusObjectPath('/com/nushihq/Nushi'),
      interface: 'com.canonical.Unity.LauncherEntry',
      name: 'Update',
      values: [
        const DBusString('application://$_app.desktop'),
        DBusDict.stringVariant({
          'count': DBusInt64(count),
          'count-visible': DBusBoolean(count > 0),
        }),
      ],
    );
  }

  /// Allowed while a notification service runs or the bus can start one;
  /// otherwise no answer, as the freedesktop service has no permission
  /// to ask about (a desktop's own switch for Nushi stays its own).
  @override
  Future<NotifyPermission?> allowed() async {
    final bus = await _reached;
    if (bus == null) return null;
    try {
      if (await bus.nameHasOwner(_service) ||
          (await bus.listActivatableNames()).contains(_service)) {
        return NotifyPermission.allowed;
      }
    } on Object {
      // No bus to ask.
    }
    return null;
  }

  /// There's no one place for a desktop's notification settings.
  @override
  Future<void> openSettings() async {}

  /// A null [open] (the alerts gone) stops following the service until
  /// the next notification.
  @override
  void onOpen(void Function(String chat)? open) {
    _open = open;
    if (open != null) {
      _reached.then((bus) {
        if (bus != null && _open != null) _listen(bus);
      }).ignore();
    } else {
      _signals?.cancel().ignore();
      _signals = null;
    }
  }

  /// Follows the service's signals on [bus] from now on: a click's token,
  /// then its action, and a notification gone.
  void _listen(DBusClient bus) {
    if (_signals != null) return;
    _signals =
        DBusSignalStream(
          bus,
          sender: _service,
          interface: _service,
          path: _path,
        ).listen(
          _signal,
          onError: (Object _) {
            // A bus that went away: nothing more to follow.
          },
        );
  }

  void _signal(DBusSignal s) {
    final values = s.values;
    if (values.length != 2 || values.first is! DBusUint32) return;
    final number = values.first.asUint32();
    switch ((s.name, values.last)) {
      case ('ActivationToken', final DBusString token):
        if (_names.containsKey(number)) _tokens[number] = token.value;
      case ('ActionInvoked', DBusString(value: 'default')):
        final id = _names[number];
        final chat = _chats[id];
        final token = _tokens.remove(number);
        if (chat == null) return;
        _window.present(token: token).ignore();
        _open?.call(chat);
      case ('NotificationClosed', _):
        final id = _names.remove(number);
        _tokens.remove(number);
        if (id != null && _numbers[id] == number) {
          _numbers.remove(id);
          _chats.remove(id);
        }
    }
  }
}

/// [text] with the characters notification markup reads (`&`, `<`, `>`)
/// escaped, so it shows as written: a chat's title may hold a tag or a
/// link.
String escaped(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
