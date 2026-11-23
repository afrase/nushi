import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, WidgetsBinding;

import 'package:nushi/agents.dart';
import 'package:nushi/browser_tabs.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/chat_find.dart';
import 'package:nushi/chat_look.dart';
import 'package:nushi/chat_paths.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/code_runs.dart';
import 'package:nushi/draft.dart';
import 'package:nushi/file_edit.dart';
import 'package:nushi/file_links.dart';
import 'package:nushi/file_tabs.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/outbox.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/related_worktrees.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/transcript_find.dart';

export 'package:nushi/chat_paths.dart';

/// A chat's state in a word, worked out in one place ([ChatState.phase]):
/// the Mac's dot and word, the phone's row and the status bar read it, so
/// they agree. In order of precedence.
enum ChatPhase {
  archived, // no agent runs; read-only until unarchived
  waiting, // on the user: a permission prompt or a question
  working, // a turn runs, the agent works on its own, or a workflow runs
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

/// The two kinds of tab beside a chat: a file's (the Files pane's) and a
/// browser's.
enum TabKind { file, browser }

/// What a chat's agent asked to show beside it: a file (ADR 0068) or a page
/// on this Mac (ADR 0100).
sealed class ShowAsk;

/// A file the show tool named, as the agent named it.
final class ShowFile implements ShowAsk {
  const new(this.path);

  final String path;
}

/// A page on this Mac's loopback: the show tool's url, or a dev server the
/// agent started, once it answers.
final class ShowPage implements ShowAsk {
  const new(this.url);

  final String url;
}

/// A launch file's entry by what tells it from the others: its name, in
/// its file.
typedef ServerEntry = ({String name, String source, bool fromMain});

/// One chat's transcript and status: a snapshot from the daemon, kept
/// current by the chat's later events.
class ChatState extends ChangeNotifier {
  new(this.id, this.folder) {
    // A subagent's pane takes the browser's place; a file's tabs stay
    // (ADR 0094, 0096).
    pane.addListener(() {
      if (pane.value != null) browser.shown.value = null;
    });
    // A file's tab closed: its edits go with it (the closing asked first).
    files.tabs.addListener(_dropEdits);
  }

  /// The files being edited in its file tabs (ADR 0096), by their tabs'
  /// names: each until its tab closes, so a tab shown again, or the chat
  /// picked again, has its unsaved edits still.
  final edits = <String, FileEdit>{};

  /// Says an edit came or went, for the tabs' marks.
  final editsChanged = ValueNotifier<int>(0);

  /// [path]'s edit, made with [make] if it has none. Its first unsaved
  /// change keeps its tab, were it a provisional one ([FileTabs.keep]).
  FileEdit edit(String path, FileEdit Function() make) {
    if (edits[path] case final e?) return e;
    final e = edits[path] = make();
    void edited() {
      if (!e.unsaved) return;
      e.removeListener(edited);
      files.keep(PreviewFile(path));
    }

    e.addListener(edited);
    editsChanged.value++;
    return e;
  }

  /// Drops [path]'s edit (its file went, or its edits were discarded).
  void dropEdit(String path) {
    final e = edits.remove(path);
    if (e == null) return;
    e.closed = true;
    editsChanged.value++;
    // Its editor, if one shows, goes with this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => e.dispose());
  }

  void _dropEdits() {
    final open = {for (final f in files.tabs.value) f.path};
    for (final path in [...edits.keys]) {
      if (!open.contains(path)) dropEdit(path);
    }
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

  /// All its pull requests, the primary ([pull]) first (ADR 0117; a
  /// daemon before API 118 says only the primary).
  List<GitHubLink> pulls = const [];

  /// Its pull requests whose checks failed since the user last acted on
  /// them (`checks_watch.dart`, ADR 0138): it needs you until Ask to fix or
  /// Dismiss, or until they no longer fail. The app's judgment, not the
  /// daemon's.
  List<GitHubLink> checksFailed = const [];

  /// Sets [checksFailed]; whether that changed it.
  bool failChecks(List<GitHubLink> links) {
    if (listEquals(links, checksFailed)) return false;
    checksFailed = links;
    notifyListeners();
    return true;
  }

  /// Sets [pull] (and [pulls], when [all] is given) as the daemon just said
  /// it, ahead of the chat's event.
  void linkPull(GitHubLink? link, {List<GitHubLink>? all}) {
    final list =
        all ?? (link == null ? const <GitHubLink>[] : _withPrimary(link));
    if (link == pull && listEquals(list, pulls)) return;
    pull = link;
    pulls = list;
    notifyListeners();
  }

  /// [pulls] with [link] first, for a daemon that says only the primary.
  List<GitHubLink> _withPrimary(GitHubLink link) => [
    link,
    for (final p in pulls)
      if (p.host != link.host || p.repo != link.repo || p.number != link.number)
        p,
  ];

  String title = '';
  bool archived = false; // no agent runs; read-only until unarchived

  /// When it was last archived (the daemon's `Chat.archived_unix_ms`); null
  /// while it isn't, for one archived before the daemon kept the time, and
  /// from a daemon that doesn't say.
  DateTime? archivedAt;

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
  // Subagents, background commands and workflows running (API 84); of
  // those, workflows, and whether the agent works on its own after a
  // background task: both count as working (API 120, ADR 0127).
  int background = 0;
  int workflows = 0;
  bool ownTurn = false;
  DateTime? started; // when the running turn started
  bool stopping = false; // the app asked the turn to stop
  // How the last turn ended, as the daemon judged it (API 107); unspecified
  // while one runs, before any ended, or from an older daemon.
  TurnEnd ended = TurnEnd.TURN_END_UNSPECIFIED;

  /// Why the last snapshot didn't load, while the load tries again ('' once
  /// one loads).
  String loadError = '';

  /// Its state in a word: the one reading of the flags above.
  ChatPhase get phase => archived
      ? .archived
      : waiting
      ? .waiting
      : busy || ownTurn || workflows > 0
      ? .working
      : background > 0
      ? .background
      // Its pull request's checks failed (ADR 0138): once the agent is done.
      : checksFailed.isNotEmpty
      ? .waiting
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

  /// Whether it needs you: a permission prompt or a question ([waiting]),
  /// or its pull request's checks failed once the agent is done.
  bool get needsYou => phase == ChatPhase.waiting;

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

  /// ⌘F in its transcript (the Mac's), the whole chat.
  late final find = ChatFind(this);

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

  /// Its open files (ADR 0070): their tabs and the one showing.
  late final files = FileTabs();

  /// Its browser tabs (ADR 0094): their tabs and the one showing.
  late final browser = BrowserTabs();

  /// Counts the files asked to open ([openInFiles]), the one showing too:
  /// an expanded browser gives way to each (ADR 0094).
  final filesOpened = ValueNotifier<int>(0);

  /// The file its file tabs show, as its tab names it; null with none.
  String? get shownFile => files.shown.value?.path;

  /// Which kind of tab was shown last, a file's or a browser's: what ⌘W
  /// closes when the focus is in neither pane.
  TabKind? lastTabbed;

  /// Messages this app sent that the daemon hasn't shown back yet.
  late final outbox = Outbox(notifyListeners);

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

  /// Whether its pane has room for the details panel beside the transcript
  /// and the panes open, worked out when asked (its chat area's, which sets
  /// it).
  bool Function() panelFits = fitsAlways;

  /// Whether its pane has room for the Files pane beside the transcript, or
  /// it's open, worked out when asked (its chat area's, which sets it): a
  /// side chat opens without laying the area out again.
  bool Function() filesFit = fitsAlways;

  /// Whether its pane has room for the browser beside the transcript, as
  /// [filesFit].
  bool Function() browserFits = fitsAlways;

  /// [filesFit], [browserFits] and [panelFits] before a chat area works
  /// them out.
  static bool fitsAlways() => true;

  /// The tabs it has: Pull request only while it has one.
  List<ChatTab> get tabs => [.chat, .changes, if (pull != null) .pull];

  /// [tab] as it shows: Chat in place of a pull request it no longer has.
  ChatTab get shownTab => tabs.contains(tab.value) ? tab.value : .chat;

  /// Which files its messages name are there (links to their preview).
  final fileLinks = FileLinks();

  /// The file or page its agent last asked to show (the show tool, ADR
  /// 0068; a server it started, ADR 0100) that hasn't opened: the chat's
  /// pane opens it while its transcript shows, or when it next does. A
  /// later ask takes its place; nothing but the Mac's app sets it, and it
  /// lasts while the app runs.
  final showAsked = ValueNotifier<ShowAsk?>(null);

  /// The dev server whose logs drawer shows at the bottom of the browser
  /// pane (ADR 0100), by its entry, so a run that follows shows there too;
  /// null while it's closed. In the app's memory only.
  final serverLogs = ValueNotifier<ServerEntry?>(null);

  /// The side pane expanded over its whole chat pane (ADR 0094, 0123), as
  /// its chat area has it; null with none, or no area showing it. What
  /// works on the transcript (its find) waits while one covers it.
  String? covered;

  /// Shows [path] in its Files pane (ADR 0123), the one way a file opens:
  /// the pane opens on the Chat tab if it's closed, on the tab of the same
  /// file if it has one, however each is named ([relativeIn]), or a new one
  /// last. Without [keep] (a click in the tree) and with [previewTabs] on
  /// it's a provisional tab, which the next such open takes the place of.
  void openInFiles(String path, {bool keep = true}) {
    tab.value = ChatTab.chat;
    files.open(path, folder: folder, keep: keep || !previewTabs.value);
    if (!filesChats.value.contains(id)) {
      filesChats.value = {...filesChats.value, id};
    }
    lastTabbed = TabKind.file;
    filesOpened.value++;
    sawFile(path);
  }

  /// Shows [entry], one of its file or browser tabs: a click on its tab,
  /// which doesn't keep a provisional one (a double click does, ADR 0070).
  void showTab(PreviewEntry entry) => switch (entry) {
    PreviewFile(:final path) => openInFiles(path, keep: false),
    final BrowserTab b => showBrowserTab(b),
  };

  /// Opens a new browser tab last, at [address] ('' for a new tab's page),
  /// and shows it, on the Chat tab (the pane is beside the chat).
  BrowserTab openBrowserTab([String address = '']) {
    _browsing();
    return browser.open(address);
  }

  /// Shows a server's address at [url] in a browser tab, on the Chat tab
  /// ([BrowserTabs.showServer], ADR 0098).
  void showServer(String url) {
    _browsing();
    browser.showServer(url);
  }

  /// Shows a page its agent asked for ([ShowPage]) in a browser tab, on
  /// the Chat tab ([BrowserTabs.showPage]).
  void showPage(String url) {
    _browsing();
    browser.showPage(url);
  }

  /// Shows [tab], one of its browser tabs.
  void showBrowserTab(BrowserTab tab) {
    _browsing();
    browser.showTab(tab);
  }

  /// A browser tab is about to show: on the Chat tab, in the subagent
  /// pane's place.
  void _browsing() {
    tab.value = ChatTab.chat;
    pane.value = null;
    lastTabbed = TabKind.browser;
  }

  /// Whether a browser tab shows, on the Chat tab.
  bool get browserShown =>
      browser.shown.value != null && shownTab == ChatTab.chat;

  /// The globe: hides the browser while it shows, else shows it, on the
  /// Chat tab ([BrowserTabs.show]).
  void showOrHideBrowser() {
    if (browserShown) return browser.hide();
    _browsing();
    browser.show();
  }

  /// When the user last opened each file (as its tab names it), while
  /// the app runs: one opened in the last hour is among the chat's recent
  /// artifacts (`chatArtifacts`).
  final opened = ValueNotifier<Map<String, DateTime>>(const {});

  /// Notes that the user opened [path] now (the phone's preview too), by
  /// the name its artifacts have ([relativeIn]).
  void sawFile(String path) =>
      opened.value = {...opened.value, relativeIn(folder, path): clock()};

  /// The agent's name to show: "Claude".
  String get agentName => agentTitle(agent);

  /// The terminal command that opens one of its agent's sessions, before
  /// the session id ('' when not known).
  String get resume => knownAgents[agent]?.resume ?? '';

  /// The folder the chat stands for: in a worktree, the same folder in its
  /// repository (not a folder beside it whose name starts with its name);
  /// the sidebar groups chats by it, as the daemon's
  /// ChatRecord.ProjectFolder counts it.
  String get home => switch (worktree) {
    final wt?
        when wt.repo.isNotEmpty &&
            (folder == wt.path || folder.startsWith('${wt.path}/')) =>
      wt.repo + folder.substring(wt.path.length),
    _ => folder,
  };

  /// Whether the chat has no messages yet (its snapshot is in).
  bool get fresh =>
      loaded && !items.any((i) => i.kind == ItemKind.ITEM_KIND_USER_MESSAGE);

  /// Whether it has no messages yet, or (its snapshot not in yet) likely
  /// has none: none was ever sent to it, by the daemon's word ([updated]
  /// is still [created]). What only a chat without messages shows (the
  /// bar under the box) takes its room from the first frame, not as the
  /// snapshot comes.
  bool get likelyFresh => loaded ? fresh : updated == created;

  /// Whether the snapshot is in; until then events wait in [_early].
  bool loaded = false;
  bool loading = false;
  int loads = 0; // counts loads and unloads: an answer only the latest may use

  /// How many items come before [items] (a chat opens with its recent
  /// part, GetChatRequest.recent); 0 when it has them all.
  int older = 0;

  /// The items before [items] whose subagent or background command runs,
  /// or that wait for an answer (GetChatResponse.running), kept up by their
  /// events: its background tasks show and stop, and its prompts are
  /// answered, before their page is loaded.
  final runningBefore = <Item>[];

  /// [runningBefore] and [items]: what its background tasks are found in.
  List<Item> get withRunning =>
      runningBefore.isEmpty ? items : [...runningBefore, ...items];

  /// The permissions and questions in [runningBefore]: the transcript
  /// shows them at its foot, where a waiting card belongs, until their page
  /// is loaded. By kind, not by status, so one answered there shows as
  /// answered rather than vanishing as it's clicked; it goes once a newer
  /// item comes (_applyItem), so it never sits below what came after it.
  List<Item> get asksBefore => [...runningBefore.where(_asks)];

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
    runningBefore
      ..clear()
      ..addAll(s.running);
    config = s.config;
    commands = s.commands;
    usage = s.usage;
    queue = s.queue.messages;
    status(s.status);
    loadError = '';
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
      outbox.adopt(last);
    }
    final early = [..._early];
    _early.clear();
    early.forEach(_apply);
    notifyListeners();
    find.reloaded();
  }

  /// Puts an older page before the items; an item the page has that came
  /// meanwhile as new (its event reached past the recent part) takes its
  /// place in the page.
  void prepend(List<Item> page, int olderNow) {
    final ids = {for (final it in page) it.id};
    final late = {
      for (final it in items.where((it) => ids.contains(it.id))) it.id: it,
    };
    // What ran before the page, as its events left it.
    for (final it in runningBefore.where((it) => ids.contains(it.id))) {
      late[it.id] ??= it;
    }
    runningBefore.removeWhere((it) => ids.contains(it.id));
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
  /// its recent part. A task that runs, or a prompt still waiting, above
  /// them is kept beside them in [runningBefore], as the daemon sends it.
  /// Not while a find looks in what it has. Whether any went.
  bool trim(int n) {
    if (!loaded || outbox.sending.isNotEmpty) return false;
    if (find.looking) return false;
    var start = recentStart(items, items.length, n);
    if (pane.value case final id?) {
      final i = items.indexWhere((it) => it.id == id);
      if (i >= 0 && i < start) start = _withCalls(items, i, items.length);
    }
    if (start == 0) return false;
    // A task that runs among them stays listed, a waiting prompt shown.
    runningBefore.addAll(
      items.take(start).where((it) => _runs(it) || _waits(it)),
    );
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
    runningBefore.clear();
    outbox.clear();
    older = 0;
    olderFailed = false;
    revision++;
  }

  /// Lets go of what it owns, the chat gone (Daemon's _forget, after the
  /// frame that drops its views): a load on its way is dropped, the runs
  /// it follows stop, its find's timers end, and its notifiers and
  /// controllers are disposed. Not [forking], [rewinding], [takeBack],
  /// [side], [sideHidden] or [commitMessage]: calls that may answer after
  /// the chat went set them (a side chat's fork, the agent's commit
  /// message), and nothing listens to them by then.
  @override
  void dispose() {
    unload();
    runs.close();
    find.dispose();
    for (final e in edits.values) {
      e.dispose();
    }
    edits.clear();
    for (final n in <ChangeNotifier>[
      editsChanged,
      renaming,
      pane,
      filesOpened,
      tab,
      showAsked,
      serverLogs,
    ]) {
      n.dispose();
    }
    super.dispose();
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
    if (s.busy) {
      ended = TurnEnd.TURN_END_UNSPECIFIED;
    } else if (s.ended != TurnEnd.TURN_END_UNSPECIFIED) {
      ended = s.ended;
    }
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
    workflows = s.workflows;
    ownTurn = s.ownTurn;
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
        outbox.settle();
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
        outbox.settle();
      case EventsResponse_Kind.chat ||
          EventsResponse_Kind.removed ||
          EventsResponse_Kind.terminals ||
          EventsResponse_Kind.remote ||
          EventsResponse_Kind.removedChats ||
          EventsResponse_Kind.update ||
          EventsResponse_Kind.show ||
          EventsResponse_Kind.showUrl ||
          EventsResponse_Kind.relatedWorktrees ||
          EventsResponse_Kind.serversChanged ||
          EventsResponse_Kind.notSet:
        return; // the daemon keeps a chat's title and folder
    }
  }

  void _applyItem(ItemEvent e) {
    final i = items.indexWhere((it) => it.id == e.item.id);
    if (i < 0 && older > 0 && (e.append || e.index < older)) {
      // An item before the recent part: its page will have it; a task
      // running there is kept up.
      final j = runningBefore.indexWhere((it) => it.id == e.item.id);
      if (j < 0) return;
      runningBefore[j] = e.append
          ? (runningBefore[j].deepCopy()
              ..text = runningBefore[j].text + e.item.text)
          : e.item;
    } else if (i >= 0 && e.append) {
      items[i] = items[i].deepCopy()..text = items[i].text + e.item.text;
      return;
    } else if (i < 0) {
      outbox.adopt(e.item);
      // A prompt from above answered at the foot goes as the chat moves on.
      runningBefore.removeWhere((it) => _asks(it) && !_waits(it));
      // An append carries no index; any other new item its place, 0 too.
      final at = e.index - older;
      if (!e.append && at >= 0 && at < items.length) {
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

/// Whether [it] is a subagent, background command or workflow that runs.
bool _runs(Item it) =>
    it.backgroundCommand.state == 'running' ||
    it.subagent.state == 'running' ||
    workflowRuns(it);

/// Whether [it] launched a workflow that runs and isn't stalled (ADR 0127).
bool workflowRuns(Item it) =>
    it.workflow.state == 'running' && !it.workflow.stalled;

/// Where the last [n] of [items] before [end] start: [n] back, and further
/// back to the call that started a subagent whose steps are among them, so
/// the subagent shows whole (internal/features/chats/pages.go's
/// pageStart). A permission or question still waiting above them isn't
/// reached back to: it goes beside them ([ChatState.runningBefore]).
int recentStart(List<Item> items, int end, int n) =>
    _withCalls(items, max(0, end - n), end);

/// [from], or further back to the call of a subagent whose steps are
/// among [items] from it to [end]: a step kept always keeps its call.
int _withCalls(List<Item> items, int from, int end) {
  var start = from;
  final index = {for (final (i, it) in items.take(end).indexed) it.id: i};
  for (var i = end - 1; i >= start; i--) {
    if (index[items[i].parent] case final j? when j < start) start = j;
  }
  return start;
}

/// Whether [it] is a permission or a question.
bool _asks(Item it) =>
    it.kind == ItemKind.ITEM_KIND_PERMISSION ||
    it.kind == ItemKind.ITEM_KIND_QUESTION;

/// Whether [it] is a permission or a question still waiting for its answer.
bool _waits(Item it) => _asks(it) && it.status == 'pending';
