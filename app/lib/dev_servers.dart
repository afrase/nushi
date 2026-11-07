import 'package:flutter/foundation.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The API from which the daemon runs dev servers (ADR 0098).
const serversApi = 109;

/// A chat's folder's dev servers as the daemon lists them (ADR 0098): the
/// launch files' entries with their servers' states, read when the
/// Servers menu shows and again on each of the daemon's word that the
/// folder's servers changed. The daemon runs them; the app asks.
class DevServers extends ChangeNotifier {
  new(this.client);

  final NushiServiceClient client;
  final _lists = <String, ListServersResponse>{}; // by chat, once listed
  final _errors = <String, String>{}; // by chat: why it couldn't be listed

  /// What runs once a server this app started answers, by its id: its tab
  /// opens.
  final _onReady = <String, void Function(String url)>{};

  /// A chat's servers, or null until listed.
  ListServersResponse? of(String chatId) => _lists[chatId];

  /// Why a chat's servers couldn't be listed, or null.
  String? errorOf(String chatId) => _errors[chatId];

  /// Lists a chat's servers.
  Future<void> load(String chatId) async {
    try {
      _take(
        chatId,
        await client.listServers(ListServersRequest(chatId: chatId)),
      );
      _errors.remove(chatId);
    } on Object catch (e) {
      _errors[chatId] = errorText(e);
    }
    notifyListeners();
  }

  /// Lists each chat's servers listed so far again (after reconnecting).
  void reload() {
    for (final chat in [..._lists.keys]) {
      load(chat).ignore();
    }
  }

  /// The daemon says [folder]'s servers changed: each chat listed there
  /// lists them again.
  void changed(String folder) {
    for (final chat in [..._lists.keys]) {
      if (_lists[chat]?.folder == folder) load(chat).ignore();
    }
  }

  /// Takes a chat's listing, and opens the tab of a server this app
  /// started once it answers; one that ended without answering opens
  /// nothing.
  void _take(String chatId, ListServersResponse list) {
    _lists[chatId] = list;
    for (final s in list.servers) {
      final ready = _onReady[s.serverId];
      if (ready == null) continue;
      if (s.state == DevServerState.DEV_SERVER_STATE_RUNNING) {
        _onReady.remove(s.serverId);
        ready(s.url);
      } else if (!runs(s)) {
        _onReady.remove(s.serverId);
      }
    }
  }

  /// Starts a chat's entry at [index]; [onReady] runs with its address
  /// once it answers. A failure is listed on its row (the daemon keeps
  /// it); the list is read again either way.
  Future<void> start(
    String chatId,
    int index, {
    required void Function(String url) onReady,
  }) async {
    try {
      final r = await client.startServer(
        StartServerRequest(chatId: chatId, index: index),
      );
      if (r.server.state == DevServerState.DEV_SERVER_STATE_RUNNING) {
        onReady(r.server.url); // it ran already
      } else {
        _onReady[r.server.serverId] = onReady;
      }
    } on Object catch (_) {
      // The row says why: the daemon lists the failed start.
    }
    await load(chatId);
  }

  /// Stops one of a chat's folder's servers.
  Future<void> stop(String chatId, String serverId) async {
    _onReady.remove(serverId);
    try {
      await client.stopServer(
        StopServerRequest(chatId: chatId, serverId: serverId),
      );
    } finally {
      await load(chatId);
    }
  }

  /// Stops every server of a chat's folder.
  Future<void> stopAll(String chatId) async {
    try {
      await client.stopAllServers(StopAllServersRequest(chatId: chatId));
    } finally {
      await load(chatId);
    }
  }

  /// Whether [s] runs: started, answering or not.
  static bool runs(DevServer s) => switch (s.state) {
    DevServerState.DEV_SERVER_STATE_STARTING ||
    DevServerState.DEV_SERVER_STATE_RUNNING ||
    DevServerState.DEV_SERVER_STATE_NOT_ANSWERING => true,
    _ => false,
  };
}
