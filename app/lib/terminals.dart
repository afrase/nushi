import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nushi/conventions.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart' as pb;
import 'package:nushi/keys.dart';
import 'package:nushi/terminal_session.dart';
import 'package:xterm2/xterm.dart';

/// The chats' terminals as the daemon lists them, and an emulator for each
/// one the app has shown. The daemon runs the shells; the emulators replay
/// their output when the app attaches.
class Terminals extends ChangeNotifier {
  new(this.client, {this.api = noDaemonApi});

  final NushiServiceClient client;

  /// The daemon's API version, as it is now (`Daemon.daemonApi`).
  final int Function() api;
  final _lists = <String, List<pb.Terminal>>{}; // by chat, once known
  final _sessions = <String, TermSession>{}; // by terminal id
  final _opened = <String>{}; // opened here, not attached to yet
  final _restarting = <String>{}; // restarted here: it attaches once done

  /// The tab shown in each chat's panel, by chat.
  final active = <String, String>{};

  /// The terminals the user has seen: picked ([show]) or shown in an open
  /// panel. A command's terminal the user saw stays when its command ends
  /// (CommandRuns), one they never did is closed.
  final looked = <String>{};

  /// A terminal just opened or picked, which takes the keyboard focus.
  String? focusNext;

  /// A chat's terminals in order, or null until they are listed.
  List<pb.Terminal>? of(String chatId) => _lists[chatId];

  /// Lists a chat's terminals (again, after reconnecting).
  Future<void> load(String chatId) async {
    final resp = await client.listTerminals(
      pb.ListTerminalsRequest(chatId: chatId),
    );
    apply(chatId, resp.terminals);
  }

  /// Lists a chat's terminals afresh before the app decides on what runs
  /// in them (closing one, typing a run into one): the daemon reads each
  /// foreground program as it is now, where the list it sends as events
  /// may lag (ADR 0132). Says whether the daemon answered; when it didn't,
  /// the list stays as the app knew it.
  Future<bool> refresh(String chatId) async {
    try {
      await load(chatId);
      return true;
    } on Object {
      return false;
    }
  }

  /// Takes a chat's whole list of terminals (an event or a listing).
  void apply(String chatId, List<pb.Terminal> list) {
    final ids = {for (final t in list) t.id};
    // One no longer listed was seen for the last time.
    looked.removeAll([
      for (final t in _lists[chatId] ?? const <pb.Terminal>[])
        if (!ids.contains(t.id)) t.id,
    ]);
    _lists[chatId] = list;
    _sessions.removeWhere((id, s) {
      final gone = s.chatId == chatId && !ids.contains(id);
      if (gone) s.dispose();
      return gone;
    });
    // Restarted elsewhere (another app): its stream ended with the old
    // shell, so it attaches to the new one. Not fresh: the app that
    // restarted it answers the new shell's first queries.
    for (final t in list) {
      final s = _sessions[t.id];
      if (s != null && s.exited && !t.exited && !_restarting.contains(t.id)) {
        s.attach();
      }
    }
    if (!ids.contains(active[chatId])) {
      final id = list.lastOrNull?.id;
      id == null ? active.remove(chatId) : active[chatId] = id;
    }
    notifyListeners();
  }

  /// Forgets a chat's terminals and their emulators (the chat is gone).
  void forget(String chatId) {
    looked.removeAll([
      for (final t in _lists[chatId] ?? const <pb.Terminal>[]) t.id,
    ]);
    _lists.remove(chatId);
    active.remove(chatId);
    _sessions.removeWhere((_, s) {
      if (s.chatId == chatId) s.dispose();
      return s.chatId == chatId;
    });
  }

  /// Forgets the lists, which may have changed while disconnected; open
  /// panels list them again.
  void stale() {
    _lists.clear();
    notifyListeners();
  }

  /// The emulator of a terminal, attached to it.
  TermSession session(pb.Terminal t) =>
      _sessions[t.id] ??= TermSession(client, t.id, t.chatId, api: api)
        ..fresh = _opened.remove(t.id);

  /// Opens a terminal for a chat (in [folder], or the chat's) and shows it.
  /// Without [show] it's only listed (a code block's run, which the panel
  /// shows when asked), its emulator attached at once to answer the
  /// shell's queries: fish waits on them before its first prompt. With a
  /// [command] (a daemon of `commandTerminalApi` or newer) the terminal is
  /// the login shell running it, listed with it (`Terminal.command`), and
  /// it ends when the command does: its session's stream says so, with
  /// the exit code, in its last message.
  Future<pb.Terminal> open(
    String chatId, {
    String folder = '',
    bool show = true,
    String command = '',
  }) async {
    final resp = await client.openTerminal(
      pb.OpenTerminalRequest(
        chatId: chatId,
        folder: folder,
        cols: 80,
        rows: 24,
        command: command,
      ),
    );
    final list = _lists[chatId] ?? [];
    if (!list.any((t) => t.id == resp.terminal.id)) {
      _lists[chatId] = [...list, resp.terminal];
    }
    // Its session may be made already, from the list's event: then it's
    // fresh, and nothing waits to be made.
    if (_sessions[resp.terminal.id] case final s?) {
      s.fresh = true;
    } else {
      _opened.add(resp.terminal.id);
    }
    if (show) {
      active[chatId] = focusNext = resp.terminal.id;
    } else {
      active[chatId] ??= resp.terminal.id;
      // Sized as it opened, which attaches it; the panel sizes it to its
      // view once shown.
      session(resp.terminal).terminal.resize(80, 24);
    }
    notifyListeners();
    return resp.terminal;
  }

  void show(String chatId, String id) {
    looked.add(id);
    active[chatId] = focusNext = id;
    notifyListeners();
  }

  Future<void> close(String id) =>
      client.closeTerminal(pb.CloseTerminalRequest(terminalId: id));

  Future<void> rename(String id, String name) => client.renameTerminal(
    pb.RenameTerminalRequest(terminalId: id, name: name),
  );

  /// Moves a chat's terminal from [from] to [to] in its list.
  Future<void> move(String chatId, int from, int to) {
    final list = [...?_lists[chatId]];
    list.insert(to, list.removeAt(from));
    _lists[chatId] = list;
    notifyListeners();
    return client.arrangeTerminals(
      pb.ArrangeTerminalsRequest(
        chatId: chatId,
        terminalIds: [for (final t in list) t.id],
      ),
    );
  }

  Future<void> restart(String id) async {
    final s = _sessions[id];
    _restarting.add(id);
    try {
      await client.restartTerminal(
        pb.RestartTerminalRequest(
          terminalId: id,
          cols: s?.terminal.viewWidth ?? 80,
          rows: s?.terminal.viewHeight ?? 24,
        ),
      );
    } finally {
      _restarting.remove(id);
    }
    s
      ?..fresh = true
      ..attach();
  }

  bool _disposed = false;

  // An answer that lands after the Daemon is gone (a listing, an open)
  // changes nothing anyone shows.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Ends every emulator's stream and retry, with the Daemon that made it
  /// (`Daemon.terminals`).
  @override
  void dispose() {
    _disposed = true;
    for (final s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}

/// What a terminal tab shows: the name given to it, the program in front,
/// or the shell and its folder.
String terminalName(pb.Terminal t) => t.name.isNotEmpty
    ? t.name
    : t.program.isNotEmpty
    ? t.program
    : '${t.shell} in ${t.folder.split('/').last}';

/// No daemon's API known: what a [Terminals] or [TermSession] made
/// without one assumes, as a daemon older than every gate.
int noDaemonApi() => 0;

/// The platform a terminal reads its keys as: the Mac's, or Linux's where
/// Control is the command key (ADR 0104): its keytab, and AltGr typing its
/// character rather than Alt and Control.
TerminalTargetPlatform get terminalPlatform => switch (commandKey) {
  CommandKey.meta => TerminalTargetPlatform.macos,
  CommandKey.control => TerminalTargetPlatform.linux,
};
