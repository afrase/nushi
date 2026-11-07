import 'dart:async';

import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/native.dart';
import 'package:nushi/settings.dart';

/// What posts notifications and badges the app's icon (ADR 0097): on the
/// Mac, its Notification Center and Dock (`alerts_macos.dart`).
abstract interface class AlertCenter {
  /// Posts a notification named [id] (one posted with the same id takes
  /// the place of the one before) for chat [chat], with [title] over
  /// [body], and the notification sound when [sound].
  Future<void> post({
    required String id,
    required String chat,
    required String title,
    required String body,
    required bool sound,
  });

  /// Takes back the notifications named [ids].
  Future<void> withdraw(List<String> ids);

  /// Takes back every notification for chat [chat].
  Future<void> clear(String chat);

  /// Puts [label] on the app's icon ('' for none).
  Future<void> badge(String label);

  /// Whether the system lets the app notify, in the Mac's words:
  /// "authorized", "denied" or "notDetermined" (it asks on the first one).
  Future<String?> allowed();

  /// Opens the system's settings for the app's notifications.
  Future<void> openSettings();

  /// Has [open] called with a chat's id when one of its notifications is
  /// clicked; null stops.
  void onOpen(void Function(String chat)? open);
}

/// The API from which the daemon says how each turn ended
/// (ChatStatus.ended, failure). While an older daemon waits to restart (ADR
/// 0056) the alerts still guess it from the turn's notices.
const turnEndApi = 107;

/// What a Mac notification says happened, in the phone's pushes' words.
enum AlertKind {
  permission(' needs you'),
  question(' has a question'),
  finished(' finished'),
  failed("'s turn failed");

  new(this.words);

  final String words;

  /// The notification this kind takes the place of: a turn's end, done or
  /// failed, replaces the last one, so a Try again that worked leaves no
  /// stale failure beside it; a prompt or question has its own.
  String get slot => this == finished || this == failed ? 'ended' : name;

  /// Whether the user wants this kind (Settings › General).
  bool get on => switch (this) {
    permission || question => alertNeedsYou.value,
    finished => alertFinished.value,
    failed => alertFailed.value,
  };
}

/// The notifications and the app icon's badge ([AlertCenter], the Mac's
/// Notification Center and Dock), from the chats' events as the
/// daemon's pushes to the phone are (`features/remote`'s notifier): a
/// permission prompt or a question when it comes, and a turn's end
/// [finishedWait] later as the daemon judged it (ChatStatus.ended):
/// "finished", "failed" with what ended it, nothing for a stopped one, and
/// none if the agent went straight on. A notification is
/// posted unless Nushi is the app in front *and* shows that chat: in the
/// background every chat's; in front, the other chats'. A click opens its
/// chat, and a "needs you" goes once its chat no longer does. Nothing
/// leaves the Mac: macOS shows them. The badge is the number of chats that
/// need you. macOS asks for permission on the first
/// notification, not at launch.
class ChatAlerts {
  new(this.daemon) {
    daemon
      ..onEvent = follow
      ..addListener(_changed);
    center.onOpen(_open);
    dockBadge.addListener(_badge);
    _changed();
  }

  final Daemon daemon;

  /// What posts them: the platform's ([Native.alerts]).
  final AlertCenter center = native.alerts;

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
  // An older daemon's turns, judged from their notices: whose running turn
  // someone stopped, and whose had an error.
  final _stopped = <String>{};
  final _failed = <String>{};
  final _asked = <String, Set<String>>{}; // prompts already notified
  final _finishing = <String, Timer>{};
  final _posted = <String>{}; // chats with notifications posted
  // Chats with a "needs you" posted: whether the chat has been seen
  // waiting since, after which its end takes the notification back.
  final _needs = <String, bool>{};
  String? _badgeShown;

  /// The chat a click asked for before the daemon listed its chats (a
  /// notification left from before launched Nushi): it opens once listed.
  String? _opening;

  void dispose() {
    daemon
      ..onEvent = null
      ..removeListener(_changed);
    dockBadge.removeListener(_badge);
    center.onOpen(null);
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
      final s = e.status;
      if (s.started != 0) {
        _running.add(id);
        _finishing.remove(id)?.cancel(); // the agent went on
      } else if (_judged) {
        if (s.ended != TurnEnd.TURN_END_UNSPECIFIED) {
          _running.remove(id);
          _asked.remove(id);
          _finishing.remove(id)?.cancel();
        }
        // A stopped turn, or a status that isn't an end: nothing.
        if (s.ended == TurnEnd.TURN_END_DONE) {
          _finish(id, AlertKind.finished);
        } else if (s.ended == TurnEnd.TURN_END_FAILED) {
          _finish(id, AlertKind.failed, s.failure);
        }
      } else if (_running.remove(id) || daemon.chats[id]?.started != null) {
        final stopped = _stopped.remove(id);
        final failed = _failed.remove(id);
        _asked.remove(id);
        if (!stopped) {
          _finish(id, failed ? AlertKind.failed : AlertKind.finished);
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
      if (it.kind == ItemKind.ITEM_KIND_NOTICE && running && !_judged) {
        if (it.status == 'cancelled') _stopped.add(id);
        if (it.status == 'error' || it.status == 'turn_failed') _failed.add(id);
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

  /// Whether the daemon judges each turn's end (from [turnEndApi]).
  bool get _judged => daemon.daemonApi >= turnEndApi;

  /// Posts a turn's end [finishedWait] from now, unless the agent goes on
  /// first; [detail] is what ended a failed one.
  void _finish(String id, AlertKind kind, [String detail = '']) {
    _finishing[id]?.cancel();
    _finishing[id] = Timer(finishedWait, () {
      _finishing.remove(id);
      _post(id, kind, detail);
    });
  }

  /// Posts [kind] for chat [id], the chat's title under it, then [detail]
  /// when there is one.
  void _post(String id, AlertKind kind, [String detail = '']) {
    final chat = daemon.chats[id];
    if (chat == null || chat.archived) return;
    if (!kind.on) {
      // A turn's end the user doesn't want still takes the place of the
      // one before: a Try again that worked leaves no failure behind.
      if (kind.slot == 'ended' && _posted.contains(id)) {
        center.withdraw(['$id/ended']).ignore();
      }
      return;
    }
    if (_focused && daemon.macView.showing == id) return;
    _posted.add(id);
    if (kind == AlertKind.permission || kind == AlertKind.question) {
      _needs[id] = chat.waiting;
    }
    center
        .post(
          id: '$id/${kind.slot}',
          chat: id,
          title: '${chat.agentName}${kind.words}',
          body: detail.isEmpty
              ? chat.shownTitle
              : '${chat.shownTitle}\n$detail',
          sound: alertSound.value,
        )
        .ignore();
  }

  /// The daemon changed (a chat picked, listed, gone): the badge, and the
  /// shown chat's notifications cleared.
  void _changed() {
    if (_opening case final id? when daemon.chatsListed) {
      _opening = null;
      if (daemon.chats.containsKey(id)) daemon.select(id);
    }
    _badge();
    _clearShown();
  }

  /// Takes the notifications of the chat Nushi shows in front off the
  /// Notification Center: you're looking at it.
  void _clearShown() {
    final id = daemon.macView.showing;
    if (!_focused || !_posted.remove(id)) return;
    center.clear(id).ignore();
  }

  /// The Dock badge: the chats that need you, or none. A chat that no
  /// longer does (answered, cancelled, or its agent stopped: a daemon's
  /// restart) has its "needs you" notifications taken back.
  void _badge() {
    final n = daemon.chats.values
        .where((c) => c.phase == ChatPhase.waiting)
        .length;
    for (final MapEntry(key: id, value: seen) in _needs.entries.toList()) {
      final waiting = daemon.chats[id]?.waiting ?? false;
      if (waiting) {
        _needs[id] = true;
      } else if (seen || !daemon.chats.containsKey(id)) {
        _needs.remove(id);
        center.withdraw([
          '$id/${AlertKind.permission.name}',
          '$id/${AlertKind.question.name}',
        ]).ignore();
      }
    }
    final label = dockBadge.value && n > 0 ? '$n' : '';
    if (label == _badgeShown) return;
    _badgeShown = label;
    unawaited(
      center
          .badge(label)
          .then((_) {}, onError: (Object _) => _badgeShown = null),
    );
  }

  /// A notification clicked: its chat opens, or once the daemon has listed
  /// the chats, when it hasn't yet.
  void _open(String id) {
    if (daemon.chats.containsKey(id)) {
      daemon.select(id);
    } else if (!daemon.chatsListed) {
      _opening = id;
    }
  }
}

/// Whether the system lets Nushi notify ([AlertCenter.allowed]), or null
/// when it doesn't answer.
Future<String?> alertsAllowed() async {
  try {
    return await native.alerts.allowed();
  } on Object {
    return null;
  }
}
