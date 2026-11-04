import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;

import 'package:nushi/agents.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_look.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/related_worktrees.dart';
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
    // However the preview closes, its tabs go with it.
    preview.addListener(() {
      if (preview.value == null) previewFiles.value = const [];
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

  /// The worktrees its subagents work in (ADR 0081).
  late final related = RelatedWorktrees(id);

  /// What a list shows of it, which tells its listeners only when that
  /// changes, not as text streams in ([ChatLook]).
  late final look = ChatLook(this);

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

  /// Its color, if it has one the app knows. The daemon keeps it (API 99).
  ChatColor? get color => _color;
  ChatColor? _color;
  set color(ChatColor? v) {
    if (v == _color) return;
    _color = v;
    notifyListeners();
  }

  /// The ids of its pinned messages' items, in the order pinned; the
  /// daemon keeps them (API 102, ADR 0085). An id not among [items] is a
  /// message not loaded yet (the phone's) or gone.
  List<String> get pinnedMessages => _pinnedMessages;
  List<String> _pinnedMessages = const [];
  set pinnedMessages(List<String> v) {
    if (listEquals(v, _pinnedMessages)) return;
    _pinnedMessages = List.unmodifiable(v);
    notifyListeners();
  }

  /// Its pins' titles, by item id (API 104): a few words the daemon made
  /// from the message, or the agent's own once it made one. A pin without
  /// one (an older daemon's) is listed by its message's first line.
  Map<String, String> get pinTitles => _pinTitles;
  Map<String, String> _pinTitles = const {};
  set pinTitles(Map<String, String> v) {
    if (mapEquals(v, _pinTitles)) return;
    _pinTitles = Map.unmodifiable(v);
    notifyListeners();
  }

  DateTime created = DateTime.now();

  /// When a message was last sent to it or a turn of it last ended (the
  /// daemon's `Chat.updated_unix_ms`); [created] until then, and from a
  /// daemon that doesn't say.
  DateTime updated = DateTime.now();
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
  bool canWriteCommit = false; // the agent can write a commit message
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

  /// Its code blocks' runs in its terminals, for the app's run.
  late final runs = CodeRuns(id, draft.outputs);

  /// Its question forms' answers so far, by the question's item id, until
  /// sent.
  final answers = <String, QuestionDraft>{};

  /// Its open side chat, if any (see SideChat).
  final side = ValueNotifier<ChatState?>(null);

  /// Its side chat is hidden (⇧⌘B), alive all the same: a chip in the
  /// header shows it again. In the app's memory only.
  final sideHidden = ValueNotifier<bool>(false);

  /// ⌘F in its transcript (the Mac's).
  final find = TranscriptFind();

  /// ⌘F in its Changes view.
  final changesFind = ChangesFind();

  /// The message being written in its Changes view. In the app's memory
  /// only.
  final TextEditingController commitMessage = TextEditingController();

  /// Commits made in its Changes view: its folder's views read again.
  int get commits => _commits;
  int _commits = 0;
  void committed() {
    _commits++;
    notifyListeners();
  }

  /// A side chat is starting (its fork is on its way).
  final forking = ValueNotifier<bool>(false);

  /// The header's title is a field to rename it (Rename from the palette
  /// or the Chat menu).
  final renaming = ValueNotifier<bool>(false);

  /// A message taken back from the transcript, set for the composer to
  /// put back in the box.
  final takeBack = ValueNotifier<QueuedMessage?>(null);

  /// This app waits on a rewind of the chat, or on a Stop that may take its
  /// message back (`whileRewinding`): the composer is locked until the
  /// answer is here, later than the daemon's status says the chat is free.
  /// Only this app's own: a rewind from another device doesn't set it.
  final rewinding = ValueNotifier<bool>(false);

  /// The subagent or background command (its call's id) whose pane shows
  /// beside the chat, left of the details panel (see SubagentPane,
  /// BackgroundCommandPane).
  final pane = ValueNotifier<String?>(null);

  /// The file (as its tool row names it) whose preview shows in [pane]'s
  /// place: one or the other.
  final preview = ValueNotifier<String?>(null);

  /// The files open in the preview, in the order opened, [preview] the one
  /// showing: with two or more the pane shows tabs (ADR 0070). In the app's
  /// memory, as [preview] is, and empty when it's null.
  final previewFiles = ValueNotifier<List<String>>(const []);

  /// The files whose preview shows its Source, while the app runs: a file's
  /// view is made again each time it shows.
  final previewSources = <String>{};

  /// Messages this app sent to the idle chat that the daemon hasn't shown
  /// back yet: the transcript shows each at once, faint, after the items.
  /// Each goes when its echo (the daemon's user message of the same text)
  /// comes, which takes its place in the transcript ([echoes]); when its
  /// send fails ([unsend]); when the daemon ran it as a command ([ran]); or,
  /// sent, when the chat's status or queue says the daemon has it without
  /// an echo. In the app's memory only.
  final List<Item> sending = [];

  /// The [sending] message (its id) each echo took the place of: the
  /// transcript keeps its entry for the echo, so it doesn't rise in again.
  final Map<String, String> echoes = {};

  /// [sending] messages whose send failed, fading out of the transcript.
  final Set<String> unsent = {};

  final _sent = <String>{}; // sent, the echo still to come
  int _sends = 0;

  /// A message on its way: shown in the transcript until its echo.
  Item send(
    String text,
    List<ImageData> images, {
    List<String> files = const [],
  }) {
    final it = Item(
      id: 'sending ${++_sends}',
      kind: ItemKind.ITEM_KIND_USER_MESSAGE,
      text: text,
      images: images,
      files: files,
    );
    sending.add(it);
    notifyListeners();
    return it;
  }

  /// [it]'s send went through: the daemon has it, and its echo comes
  /// before the chat's next status.
  void sent(Item it) {
    if (sending.contains(it)) _sent.add(it.id);
  }

  /// [it] was a command the daemon ran in the agent's place
  /// (SendPromptResponse.ranCommand): no echo comes, so it goes now.
  void ran(Item it) => _drop(it.id);

  /// [it]'s send failed: it fades out over [fade], then goes.
  void unsend(Item it, {required Duration fade}) {
    if (!sending.contains(it)) return;
    if (fade == Duration.zero) {
      _drop(it.id);
    } else {
      unsent.add(it.id);
      Timer(fade, () => _drop(it.id));
    }
    notifyListeners();
  }

  void _drop(String id) {
    final had = sending.length;
    sending.removeWhere((it) => it.id == id);
    unsent.remove(id);
    _sent.remove(id);
    if (sending.length != had) notifyListeners();
  }

  /// [echo], a user message the daemon shows, takes the place of the
  /// message on its way with its text, if there is one.
  void _adopt(Item echo) {
    if (echo.kind != ItemKind.ITEM_KIND_USER_MESSAGE) return;
    final it = sending
        .where((s) => s.text == echo.text && !unsent.contains(s.id))
        .firstOrNull;
    if (it == null) return;
    echoes[echo.id] = it.id;
    sending.remove(it);
    _sent.remove(it.id);
  }

  /// Sent messages the daemon has without an echo (they went into the
  /// queue, say) go.
  void _settleSent() {
    if (_sent.isEmpty) return;
    sending.removeWhere((it) => _sent.contains(it.id));
    _sent.clear();
  }

  /// How far from its bottom its transcript was left, scrolled up: it opens
  /// there again (unless it needs you), with Jump to latest showing. Null
  /// when it was left at its bottom. In the app's memory only.
  double? kept;

  /// How many items it had when it was let go scrolled up ([letGo]): it
  /// loads as many again, so the place [kept] names is there.
  int keptItems = 0;

  /// The tab its pane shows on the Mac (Chat whenever the pane opens):
  /// here so the app's keys and the palette reach it wherever the focus is.
  final tab = ValueNotifier<ChatTab>(ChatTab.chat);

  /// Whether its pane, as last laid out, has room for the details panel.
  bool panelFits = true;

  /// Whether its pane, as last laid out, has room for a preview beside the
  /// transcript.
  bool previewFits = true;

  /// The tabs it has: Pull request only while it has one.
  List<ChatTab> get tabs => [.chat, .changes, if (pull != null) .pull];

  /// [tab] as it shows: Chat in place of a pull request it no longer has.
  ChatTab get shownTab => tabs.contains(tab.value) ? tab.value : .chat;

  /// Which files its messages name are there (links to their preview).
  final fileLinks = FileLinks();

  /// The file its agent last asked to show (the show tool, ADR 0068) that
  /// hasn't opened: the chat's pane opens it while its transcript shows,
  /// or when it next does. A later ask takes its place; nothing but the
  /// Mac's app sets it, and it lasts while the app runs.
  final showAsked = ValueNotifier<String?>(null);

  /// Shows [path] in the preview: the tab of the same file if it has one,
  /// however each is named (relative to the folder, or absolute), or a new
  /// one last.
  void openPreview(String path) {
    pane.value = null;
    final file = _absolute(path);
    final open = previewFiles.value
        .where((f) => _absolute(f) == file)
        .firstOrNull;
    if (open == null) previewFiles.value = [...previewFiles.value, path];
    preview.value = open ?? path;
    sawFile(path);
  }

  String _absolute(String path) =>
      Uri.file(path.startsWith('/') ? path : '$folder/$path')
          .normalizePath()
          .path;

  /// Closes [file]'s tab. If it showed, the one after it shows, or the last;
  /// with none left the preview closes.
  void closePreviewFile(String file) {
    final at = previewFiles.value.indexOf(file);
    if (at < 0) return;
    final rest = [...previewFiles.value]..removeAt(at);
    if (rest.isEmpty) {
      preview.value = null;
      return;
    }
    previewFiles.value = rest;
    if (preview.value == file) preview.value = rest[min(at, rest.length - 1)];
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
  int loads = 0; // counts loads and unloads: an answer only the latest may use

  /// How many items come before [items] (a chat opens with its recent
  /// part, GetChatRequest.recent); 0 when it has them all.
  int older = 0;

  /// The older pages on their way (Daemon.loadOlder), if any.
  Future<void>? get olderLoad => _olderLoad;
  Future<void>? _olderLoad;

  /// Whether an older page is on its way.
  bool get loadingOlder => _olderLoad != null;

  /// Whether the last older page failed: the Mac's transcript offers Try
  /// again at its top, and asks for no more on its own until then.
  bool olderFailed = false;

  /// Older pages set out, until [on] ends ([olderDone]).
  void olderGoing(Future<void> on) {
    _olderLoad = on;
    olderFailed = false;
    notifyListeners();
  }

  /// The older pages that set out are in, or [failed].
  void olderDone({required bool failed}) {
    _olderLoad = null;
    olderFailed = failed;
    notifyListeners();
  }

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
    olderFailed = false;
    _seq = s.seq.toInt();
    loaded = true;
    loading = false;
    snapshots++;
    // A message on its way that the snapshot has: its echo.
    if (items.lastWhere(
          (it) => it.kind == ItemKind.ITEM_KIND_USER_MESSAGE,
          orElse: Item.new,
        )
        case final last when last.hasId()) {
      _adopt(last);
    }
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

  /// Lets go of all but its last [n] items, reaching back to the call of a
  /// subagent whose steps are among them as the daemon's pages do, and to
  /// the call its [pane] shows: a long chat left at its bottom goes back to
  /// its recent part. Not while a find looks in what it has. Whether any
  /// went.
  bool trim(int n) {
    if (!loaded || sending.isNotEmpty) return false;
    if ((find.query ?? '').isNotEmpty) return false;
    var start = recentStart(items, items.length, n);
    if (pane.value case final id?) {
      final i = items.indexWhere((it) => it.id == id);
      if (i >= 0 && i < start) start = i;
    }
    if (start == 0) return false;
    items.removeRange(0, start);
    older += start;
    olderFailed = false;
    revision++;
    notifyListeners();
    return true;
  }

  /// The chat moved to [to]; what shows its folder follows.
  void moved(String to) {
    folder = to;
    notifyListeners();
  }

  /// Lets its items go, to save memory while it isn't shown: it loads
  /// again when opened, as at launch (Daemon.keptChats).
  void letGo() {
    unload();
    keptItems = kept == null ? 0 : items.length;
    items.clear();
    sending.clear();
    unsent.clear();
    _sent.clear();
    older = 0;
    olderFailed = false;
    revision++;
  }

  /// Forgets the snapshot (the connection was lost): the next one replaces it.
  void unload() {
    loads++;
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
    if (busy && !s.busy) related.turnEnded();
    busy = s.busy;
    waiting = s.waiting;
    canFork = s.canFork;
    canWriteCommit = s.canWriteCommit;
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
        _settleSent();
      case EventsResponse_Kind.cut:
        revision++;
        showAsked.value = null; // the call may be what was cut
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
        _settleSent();
      case EventsResponse_Kind.chat ||
          EventsResponse_Kind.removed ||
          EventsResponse_Kind.terminals ||
          EventsResponse_Kind.remote ||
          EventsResponse_Kind.removedChats ||
          EventsResponse_Kind.update ||
          EventsResponse_Kind.show ||
          EventsResponse_Kind.relatedWorktrees ||
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
      _adopt(e.item);
      final at = e.index - older;
      if (at > 0 && at < items.length) {
        items.insert(at, e.item); // a reopen's: a compaction's mark
      } else {
        items.add(e.item);
      }
    } else {
      items[i] = e.item;
    }
    revision++;
  }
}

/// Where the last [n] of [items] before [end] start: [n] back, and further
/// back to the call that started a subagent whose steps are among them, so
/// the subagent shows whole (internal/api's pageStart).
int recentStart(List<Item> items, int end, int n) {
  var start = max(0, end - n);
  final index = {for (final (i, it) in items.take(end).indexed) it.id: i};
  for (var i = end - 1; i >= start; i--) {
    if (index[items[i].parent] case final j? when j < start) start = j;
  }
  return start;
}
