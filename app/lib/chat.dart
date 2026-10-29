import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

/// A chat's state in a word, worked out in one place ([ChatState.phase]):
/// the Mac's dot and word, the phone's row and the status bar read it, so
/// they agree. In order of precedence.
enum ChatPhase {
  archived, // no agent runs; read-only until unarchived
  waiting, // on the user: a permission prompt or a question
  working, // a turn runs
  background, // no turn runs, but subagents or commands it started do
  expired, // its agent deleted its session: it can't reopen
  failed, // its reopen failed
  done, // a turn ended that no client has shown yet (API 76)
  asleep, // no agent runs: a message wakes it
  fresh, // no messages yet
  idle,
}

/// What shows in a chat's place on the Mac: its transcript, its changes,
/// or its pull request.
enum ChatTab { chat, changes, pull }

/// One chat's transcript and status: a snapshot from the daemon, kept
/// current by the chat's later events.
class ChatState extends ChangeNotifier {
  new(this.id, this.folder) {
    // A subagent's pane takes the preview's place.
    pane.addListener(() {
      if (pane.value != null) preview.value = null;
    });
  }

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

  /// A file its Changes view is to show next (a terminal link to it, a
  /// review's finding); the chat shows its Changes then.
  String? openPath;

  /// The line (from 1) of [openPath] to show; 0 for its top.
  int openLine = 0;

  void showFile(String path, {int line = 0}) {
    openPath = path;
    openLine = line;
    notifyListeners();
  }

  String agent = ''; // the agent it runs, such as "claude"
  bool scratch = false; // its folder is a scratch folder: it has none yet

  /// The Jira issue it was started from (its site and key), if it was.
  String jiraSite = '';
  String jiraKey = '';

  /// The GitHub pull request or issue it was started from, if it was.
  GitHubLink? github;

  /// Its pull request: the one it was started from, else the one whose
  /// head is its branch (found, or linked by hand). API 81.
  GitHubLink? pull;

  /// Sets [pull] as the daemon just said it, ahead of the chat's event.
  void linkPull(GitHubLink? link) {
    if (link == pull) return;
    pull = link;
    notifyListeners();
  }

  String title = '';
  bool archived = false; // no agent runs; read-only until unarchived

  /// Its title to show: "New chat" until it has one.
  String get shownTitle => title.isEmpty ? 'New chat' : title;

  /// A turn ended while no client showed the chat, until one does (the
  /// daemon keeps it); null from a daemon older than API 76.
  bool? get done => _done;
  bool? _done;
  set done(bool? v) {
    if (v == _done) return;
    _done = v;
    notifyListeners();
  }

  /// Its place among the pinned chats, from 1 (the top); 0 when it isn't
  /// pinned. The daemon keeps it (API 90).
  int get pin => _pin;
  int _pin = 0;
  set pin(int v) {
    if (v == _pin) return;
    _pin = v;
    notifyListeners();
  }

  DateTime created = DateTime.now();
  final List<Item> items = [];

  /// Goes up whenever [items] change but by text streaming into one: what
  /// is worked out from the items but their text (the artifacts,
  /// `chatFilesOf`) is worked out again only then, not per chunk.
  int revision = 0;
  List<ConfigOption> config = [];

  /// Its config option of [category] ('model', 'mode', 'thought_level'),
  /// if the agent has one.
  ConfigOption? option(String category) =>
      config.where((o) => o.category == category).firstOrNull;

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
  bool asleep = false; // no agent runs for it: a message wakes it
  bool reopenFailed = false; // no agent runs: its reopen failed (a notice)
  bool sessionGone = false; // and its agent no longer has its session
  bool canSleep = false; // its agent runs and can reopen the session
  int background = 0; // subagents and background commands running (API 84)
  DateTime? started; // when the running turn started
  bool stopping = false; // the app asked the turn to stop
  String error = ''; // why the snapshot didn't load
  String loadError = ''; // the same on the phone, which tries again

  /// Its state in a word: the one reading of the flags above.
  ChatPhase get phase => archived
      ? .archived
      : waiting
      ? .waiting
      : busy
      ? .working
      : background > 0
      ? .background
      : sessionGone
      ? .expired
      : reopenFailed
      ? .failed
      : done ?? false
      ? .done
      : asleep
      ? .asleep
      : fresh
      ? .fresh
      : .idle;

  /// What the user is writing to it.
  final draft = Draft();

  /// Its question forms' answers so far, by the question's item id, until
  /// sent.
  final answers = <String, QuestionDraft>{};

  /// Its open side chat, if any (see SideChat).
  final side = ValueNotifier<ChatState?>(null);

  /// ⌘F in its transcript (the Mac's).
  final find = TranscriptFind();

  /// ⌘F in its Changes view: the files' filter, null while closed.
  final filesFilter = ValueNotifier<String?>(null);

  /// A side chat is starting (its fork is on its way).
  final forking = ValueNotifier<bool>(false);

  /// The header's title is a field to rename it (Rename from the palette
  /// or the Chat menu).
  final renaming = ValueNotifier<bool>(false);

  /// A message taken back from the transcript, set for the composer to
  /// put back in the box.
  final takeBack = ValueNotifier<QueuedMessage?>(null);

  /// The subagent or background command (its call's id) whose pane shows
  /// beside the chat, left of the details panel (see SubagentPane,
  /// BackgroundCommandPane).
  final pane = ValueNotifier<String?>(null);

  /// The file (as its tool row names it) whose preview shows in [pane]'s
  /// place: one or the other.
  final preview = ValueNotifier<String?>(null);

  /// The tab its pane shows on the Mac (Chat whenever the pane opens):
  /// here so the app's keys and the palette reach it wherever the focus is.
  final tab = ValueNotifier<ChatTab>(ChatTab.chat);

  /// Whether its pane, as last laid out, has room for the details panel.
  bool panelFits = true;

  /// The tabs it has: Pull request only while it has one.
  List<ChatTab> get tabs => [.chat, .changes, if (pull != null) .pull];

  /// [tab] as it shows: Chat in place of a pull request it no longer has.
  ChatTab get shownTab => tabs.contains(tab.value) ? tab.value : .chat;

  /// Which files its messages name are there (links to their preview).
  final fileLinks = FileLinks();

  void openPreview(String path) {
    pane.value = null;
    preview.value = path;
    sawFile(path);
  }

  /// When the user last opened each file (as [preview] names it), while
  /// the app runs: one opened in the last hour is among the chat's recent
  /// artifacts (`chatArtifacts`).
  final opened = ValueNotifier<Map<String, DateTime>>(const {});

  /// Notes that the user opened [path] now (the phone's preview too).
  void sawFile(String path) => opened.value = {...opened.value, path: clock()};

  /// The agent's name to show: "Claude".
  String get agentName => agentTitle(agent);

  /// The terminal command that opens one of its agent's sessions, before
  /// the session id ('' when not known).
  String get resume => knownAgents[agent]?.resume ?? '';

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

  /// How many items come before [items] (the phone takes the recent part
  /// first, GetChatRequest.recent); 0 when it has them all.
  int older = 0;

  /// Whether an older page is on its way.
  bool loadingOlder = false;

  /// Asks for a fresh snapshot: an event reached past what's loaded (a
  /// rewind before the recent part). The daemon sets it.
  VoidCallback? stale;

  /// How many snapshots it has taken: an older page asked for before the
  /// last one doesn't fit it.
  int snapshots = 0;
  int _seq = 0; // the last event applied
  final _early = <EventsResponse>[];

  /// Takes a snapshot, then the events that arrived while it was on its way.
  void load(GetChatResponse s) {
    items
      ..clear()
      ..addAll(s.items);
    revision++;
    older = s.older;
    config = s.config;
    commands = s.commands;
    usage = s.usage;
    queue = s.queue.messages;
    status(s.status);
    error = loadError = '';
    _seq = s.seq.toInt();
    loaded = true;
    loading = false;
    snapshots++;
    final early = [..._early];
    _early.clear();
    early.forEach(_apply);
    notifyListeners();
  }

  /// Puts an older page before the items; an item the page has that came
  /// meanwhile as new (its event reached past the recent part) takes its
  /// place in the page.
  void prepend(List<Item> page, int olderNow) {
    final ids = {for (final it in page) it.id};
    final late = {
      for (final it in items.where((it) => ids.contains(it.id))) it.id: it,
    };
    items
      ..removeWhere((it) => ids.contains(it.id))
      ..insertAll(0, [for (final it in page) late[it.id] ?? it]);
    revision++;
    older = olderNow;
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

  /// Asks for a fresh snapshot once the events at hand are applied.
  void _stale() => scheduleMicrotask(() => stale?.call());

  /// Its status as the chat list has it: what shows it follows (its dot
  /// in the sidebar, after a daemon's restart) without a snapshot.
  void listed(ChatStatus? s) {
    if (s == null) return;
    status(s);
    notifyListeners();
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
    asleep = s.asleep;
    reopenFailed = s.reopenFailed;
    sessionGone = s.sessionGone;
    canSleep = s.canSleep;
    background = s.background;
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
        revision++;
        final i = items.indexWhere((it) => it.id == e.cut);
        if (i > 0 || i == 0 && older == 0) {
          items.removeRange(i, items.length);
        } else if (older > 0) {
          // Cut before the recent part, or at its start: what shows is
          // what came before, which a fresh snapshot brings.
          if (i == 0) items.clear();
          _stale();
        }
      case EventsResponse_Kind.dropped:
        items.removeWhere((it) => it.id == e.dropped);
        revision++;
      case EventsResponse_Kind.status:
        status(e.status);
      case EventsResponse_Kind.chat ||
          EventsResponse_Kind.removed ||
          EventsResponse_Kind.terminals ||
          EventsResponse_Kind.remote ||
          EventsResponse_Kind.removedChats ||
          EventsResponse_Kind.update ||
          EventsResponse_Kind.notSet:
        return; // the daemon keeps a chat's title and folder
    }
  }

  void _applyItem(ItemEvent e) {
    final i = items.indexWhere((it) => it.id == e.item.id);
    if (i < 0 && older > 0 && (e.append || e.index < older)) {
      return; // an item before the recent part: its page will have it
    } else if (i >= 0 && e.append) {
      items[i] = items[i].deepCopy()..text = items[i].text + e.item.text;
      return;
    } else if (i < 0) {
      items.add(e.item);
    } else {
      items[i] = e.item;
    }
    revision++;
  }
}
