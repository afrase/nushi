import 'package:flutter/foundation.dart';

import 'gen/nushi/v1/nushi.pb.dart';

/// One chat's transcript and status: a snapshot from the daemon, kept
/// current by the chat's later events.
class ChatState extends ChangeNotifier {
  ChatState(this.id, this.folder);

  final String id;
  final String folder;
  String title = '';
  DateTime created = DateTime.now();
  final List<Item> items = [];
  List<ConfigOption> config = [];
  List<Command> commands = []; // the agent's slash commands
  bool busy = false;
  bool waiting = false; // on the user: a permission prompt or a question
  DateTime? started; // when the running turn started
  String error = ''; // why the snapshot didn't load

  /// Whether the snapshot is in; until then events wait in [_early].
  bool loaded = false;
  bool loading = false;
  int _seq = 0; // the last event applied
  final _early = <EventsResponse>[];

  /// Takes a snapshot, then the events that arrived while it was on its way.
  void load(GetChatResponse s) {
    items
      ..clear()
      ..addAll(s.items);
    config = s.config;
    commands = s.commands;
    status(s.status);
    error = '';
    _seq = s.seq.toInt();
    loaded = true;
    loading = false;
    for (final e in _early) {
      _apply(e);
    }
    _early.clear();
    notifyListeners();
  }

  /// Forgets the snapshot (the connection was lost): the next one replaces it.
  void unload() {
    loaded = false;
    loading = false;
    _early.clear();
  }

  void apply(EventsResponse e) {
    if (loaded) {
      _apply(e);
      notifyListeners();
    } else if (loading) {
      _early.add(e);
    } else if (e.hasStatus()) {
      status(e.status); // for the sidebar
      notifyListeners();
    }
  }

  void status(ChatStatus s) {
    busy = s.busy;
    waiting = s.waiting;
    started = s.started == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(s.started.toInt());
  }

  void _apply(EventsResponse e) {
    if (e.seq <= _seq) return; // the snapshot has it
    _seq = e.seq.toInt();
    switch (e.whichKind()) {
      case EventsResponse_Kind.item:
        _applyItem(e.item);
      case EventsResponse_Kind.config:
        config = e.config.options;
      case EventsResponse_Kind.commands:
        commands = e.commands.commands;
      case EventsResponse_Kind.status:
        status(e.status);
      case EventsResponse_Kind.chat || EventsResponse_Kind.notSet:
        return; // the daemon keeps a chat's title and folder
    }
  }

  void _applyItem(ItemEvent e) {
    final i = items.indexWhere((it) => it.id == e.item.id);
    if (i < 0) {
      items.add(e.item);
    } else if (e.append) {
      items[i] = items[i].deepCopy()..text = items[i].text + e.item.text;
    } else {
      items[i] = e.item;
    }
  }
}
