import 'dart:async';

import 'package:flutter/services.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

/// The app's Swift side of notifications and the Dock badge.
const alertsChannel = MethodChannel('nushi/alerts');

/// What a Mac notification says happened, in the phone's pushes' words.
enum AlertKind {
  permission(' needs you'),
  question(' has a question'),
  finished(' finished'),
  failed("'s turn failed");

  new(this.words);

  final String words;

  /// Whether the user wants this kind (Settings › General).
  bool get on => switch (this) {
    permission || question => alertNeedsYou.value,
    finished => alertFinished.value,
    failed => alertFailed.value,
  };
}

/// The Mac's notifications and Dock badge, from the chats' events as the
/// daemon's pushes to the phone are (`features/remote`'s notifier): a
/// permission prompt or a question when it comes, and a turn's end
/// [finishedWait] later (none if the agent went straight on, or someone
/// stopped it), "failed" when the turn had an error. A notification is
/// posted unless Nushi is the app in front *and* shows that chat: in the
/// background every chat's; in front, the other chats'. A click opens its
/// chat. Nothing leaves the Mac: macOS shows them. The badge is the number
/// of chats that need you. macOS asks for permission on the first
/// notification, not at launch.
class MacAlerts {
  new(this.daemon, {this.channel = alertsChannel}) {
    daemon
      ..onEvent = follow
      ..addListener(_changed);
    channel.setMethodCallHandler(_called);
    dockBadge.addListener(_badge);
    _changed();
  }

  final Daemon daemon;
  final MethodChannel channel;

  /// The phone's pushes wait the same: a turn the agent goes straight on
  /// from isn't over.
  static const finishedWait = Duration(seconds: 2);

  bool _focused = true;

  /// Whether Nushi is the app in front (its window key).
  bool get focused => _focused;
  set focused(bool v) {
    _focused = v;
    _clearShown();
  }

  final _running = <String>{}; // chats whose turn runs, as events said
  final _stopped = <String>{}; // whose running turn someone stopped
  final _failed = <String>{}; // whose running turn had an error
  final _asked = <String, Set<String>>{}; // prompts already notified
  final _finishing = <String, Timer>{};
  final _posted = <String>{}; // chats with notifications posted
  String? _badgeShown;

  void dispose() {
    daemon
      ..onEvent = null
      ..removeListener(_changed);
    dockBadge.removeListener(_badge);
    channel.setMethodCallHandler(null);
    for (final t in _finishing.values) {
      t.cancel();
    }
  }

  /// Sees an event before the daemon applies it.
  void follow(EventsResponse e) {
    final id = e.chatId;
    if (id.isEmpty || daemon.sides.containsKey(id)) return;
    if (e.removed) {
      _running.remove(id);
      _stopped.remove(id);
      _failed.remove(id);
      _asked.remove(id);
      _finishing.remove(id)?.cancel();
      return;
    }
    if (e.hasStatus()) {
      if (e.status.started != 0) {
        _running.add(id);
        _finishing.remove(id)?.cancel(); // the agent went on
      } else if (_running.remove(id) || daemon.chats[id]?.started != null) {
        final stopped = _stopped.remove(id);
        final failed = _failed.remove(id);
        _asked.remove(id);
        if (!stopped) {
          _finishing[id]?.cancel();
          _finishing[id] = Timer(finishedWait, () {
            _finishing.remove(id);
            _post(id, failed ? AlertKind.failed : AlertKind.finished);
          });
        }
      }
      scheduleMicrotask(_badge); // once the daemon applied it
    } else if (e.hasItem()) {
      final it = e.item.item;
      final running =
          _running.contains(id) || daemon.chats[id]?.started != null;
      final prompt =
          it.kind == ItemKind.ITEM_KIND_PERMISSION ||
          it.kind == ItemKind.ITEM_KIND_QUESTION;
      if (it.kind == ItemKind.ITEM_KIND_NOTICE && running) {
        if (it.status == 'cancelled') _stopped.add(id);
        if (it.status == 'error') _failed.add(id);
      } else if (prompt &&
          it.status == 'pending' &&
          (_asked[id] ??= {}).add(it.id)) {
        _post(
          id,
          it.kind == ItemKind.ITEM_KIND_PERMISSION
              ? AlertKind.permission
              : AlertKind.question,
        );
      }
    }
  }

  void _post(String id, AlertKind kind) {
    final chat = daemon.chats[id];
    if (!kind.on || chat == null || chat.archived) return;
    if (_focused && daemon.macView.showing == id) return;
    _posted.add(id);
    unawaited(
      channel
          .invokeMethod<Object?>('post', {
            'id': '$id/${kind.name}',
            'chat': id,
            'title': '${chat.agentName}${kind.words}',
            'body': chat.title.isEmpty ? 'New chat' : chat.title,
            'sound': alertSound.value,
          })
          .then((_) {}, onError: (Object _) {}),
    );
  }

  /// The daemon changed (a chat picked, listed, gone): the badge, and the
  /// shown chat's notifications cleared.
  void _changed() {
    _badge();
    _clearShown();
  }

  /// Takes the notifications of the chat Nushi shows in front off the
  /// Notification Center: you're looking at it.
  void _clearShown() {
    final id = daemon.macView.showing;
    if (!_focused || !_posted.remove(id)) return;
    unawaited(
      channel
          .invokeMethod<Object?>('clear', id)
          .then((_) {}, onError: (Object _) {}),
    );
  }

  /// The Dock badge: the chats that need you, or none.
  void _badge() {
    final n = daemon.chats.values
        .where((c) => c.phase == ChatPhase.waiting)
        .length;
    final label = dockBadge.value && n > 0 ? '$n' : '';
    if (label == _badgeShown) return;
    _badgeShown = label;
    unawaited(
      channel
          .invokeMethod<Object?>('badge', label)
          .then((_) {}, onError: (Object _) => _badgeShown = null),
    );
  }

  /// A notification clicked: its chat opens.
  Future<Object?> _called(MethodCall call) async {
    if (call.method == 'open' && call.arguments is String) {
      final id = call.arguments as String;
      if (daemon.chats.containsKey(id)) daemon.select(id);
    }
    return null;
  }
}

/// Whether macOS lets Nushi notify: "authorized", "denied",
/// "notDetermined" (it asks on the first one), or null when the Swift
/// side doesn't answer.
Future<String?> alertsAllowed([MethodChannel channel = alertsChannel]) async {
  try {
    return await channel.invokeMethod<String>('status');
  } on Object {
    return null;
  }
}
