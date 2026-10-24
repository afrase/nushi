import 'package:flutter/foundation.dart';

import 'draft.dart';
import 'gen/nushi/v1/nushi.pb.dart';
import 'settings.dart';

/// One chat's transcript and status: a snapshot from the daemon, kept
/// current by the chat's later events.
class ChatState extends ChangeNotifier {
  ChatState(this.id, this.folder);

  final String id;
  String folder; // it can move (MoveChat)
  Worktree? worktree; // the git worktree it runs in, if Nushi made one

  /// What its Changes view shows (a `Scope`'s name), once picked;
  /// remembered.
  String? get scope => changeScopes.value[id];
  set scope(String? v) {
    changeScopes.value = {...changeScopes.value, id: ?v};
    notifyListeners();
  }

  /// A file its Changes view is to show next (a terminal link to it).
  String? openPath;

  void showFile(String path) {
    openPath = path;
    notifyListeners();
  }

  String agent = ''; // the agent it runs, such as "claude"
  bool scratch = false; // its folder is a scratch folder: it has none yet
  String title = '';
  bool archived = false; // no agent runs; read-only until unarchived
  DateTime created = DateTime.now();
  final List<Item> items = [];
  List<ConfigOption> config = [];
  List<Command> commands = []; // the agent's slash commands
  Usage usage = Usage(); // what the agent last reported
  List<QueuedMessage> queue = []; // waiting for the agent's next chance
  bool busy = false;
  bool waiting = false; // on the user: a permission prompt or a question
  bool canFork = false; // the agent can fork it into side chats
  bool canImages = false; // the agent takes images in prompts
  bool canRewind = false; // the agent rewinds to a user message
  bool mcpChanged = false; // MCP servers changed since the agent started
  bool canAskContext = false; // the agent can say what fills its context
  DateTime? started; // when the running turn started
  bool stopping = false; // the app asked the turn to stop
  String error = ''; // why the snapshot didn't load

  /// What the user is writing to it.
  final draft = Draft();

  /// Its open side question, if any (see SidePanel).
  ChatState? side;

  /// A message taken back from the transcript, set for the composer to
  /// put back in the box.
  final takeBack = ValueNotifier<QueuedMessage?>(null);

  /// The subagent or background shell (its call's id) whose pane shows
  /// beside the chat, in place of the details panel (see SubagentPane,
  /// ShellPane).
  final pane = ValueNotifier<String?>(null);

  /// The agent's name to show: "Claude".
  String get agentName => switch (agent) {
    'claude' => 'Claude',
    '' => 'The agent',
    _ => agent[0].toUpperCase() + agent.substring(1),
  };

  /// The folder the chat stands for: in a worktree, the same folder in its
  /// repository; the sidebar groups chats by it.
  String get home => switch (worktree) {
    final wt? when folder.startsWith(wt.path) =>
      wt.repo + folder.substring(wt.path.length),
    _ => folder,
  };

  /// Whether the chat has no messages yet (its snapshot is in).
  bool get fresh =>
      loaded && !items.any((i) => i.kind == ItemKind.ITEM_KIND_USER_MESSAGE);

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
    usage = s.usage;
    queue = s.queue.messages;
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

  /// The chat moved to [to]; what shows its folder follows.
  void moved(String to) {
    folder = to;
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

  void status(ChatStatus? s) {
    if (s == null) return;
    busy = s.busy;
    waiting = s.waiting;
    canFork = s.canFork;
    canImages = s.images;
    canRewind = s.canRewind;
    mcpChanged = s.mcpChanged;
    canAskContext = s.canAskContext;
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
      case EventsResponse_Kind.usage:
        usage = e.usage;
      case EventsResponse_Kind.queue:
        queue = e.queue.messages;
      case EventsResponse_Kind.cut:
        final i = items.indexWhere((it) => it.id == e.cut);
        if (i >= 0) items.removeRange(i, items.length);
      case EventsResponse_Kind.dropped:
        items.removeWhere((it) => it.id == e.dropped);
      case EventsResponse_Kind.status:
        status(e.status);
      case EventsResponse_Kind.chat ||
          EventsResponse_Kind.removed ||
          EventsResponse_Kind.terminals ||
          EventsResponse_Kind.notSet:
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
