import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectrpc/connect.dart' as connect;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:nushi/agents.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/chat_images.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/dev_servers.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/files_kept.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/issue_chat.dart';
import 'package:nushi/mac_view.dart';
import 'package:nushi/native.dart';
import 'package:nushi/place.dart';
import 'package:nushi/project_icons.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/sign_in_run.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/trust_ask.dart';
import 'package:nushi/visits.dart';

export 'package:nushi/issue_chat.dart';
export 'package:nushi/place.dart';

part 'daemon_events.dart';
part 'daemon_link.dart';
part 'daemon_open.dart';
part 'daemon_pages.dart';
part 'daemon_places.dart';
part 'daemon_sides.dart';
part 'daemon_start.dart';

/// The daemon's data folder, as the daemon picks it ([Native.install]);
/// `NUSHI_DATA` picks another one (development).
/// Tests get a new one in the temporary folder, never the user's, even
/// with `NUSHI_DATA` exported (a restart there would stop its daemon):
/// one per test process, as test files run side by side and a shared
/// app.json would let one file's settings overwrite another's; new, so a
/// reused pid starts from no one's prefs. flutter_test_config deletes it.
/// On the web (the phone) there is none: it throws each time it's read,
/// and counts it ([dataDirOnWeb]).
final String dataDir = _dataDir();

String _dataDir() {
  if (kIsWeb) {
    dataDirOnWeb++;
    throw UnsupportedError('No data folder on the web');
  }
  return Platform.environment.containsKey('FLUTTER_TEST')
      ? Directory.systemTemp.createTempSync('nushi-test-').path
      : Platform.environment['NUSHI_DATA'] ?? native.install.dataFolder;
}

/// How often [dataDir] was read on the web, where it throws: so a test
/// sees a store reach it though a catch swallowed the error. The phone's
/// code never should.
@visibleForTesting
int dataDirOnWeb = 0;

/// The folder the app's own stores keep their files in (`app.json`,
/// `reviews.json`, `pulls/`, `context.json`): [dataDir], or null on the
/// phone, which keeps no files (dart:io has no file system on the web,
/// and [dataDir] throws there). Each store checks it once and keeps only
/// memory when it's null, so its catches are left for a real file's
/// trouble.
String? get appFiles => kIsWeb ? null : dataDir;

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 151;

/// The oldest daemon API this app works with (ADR 0004): below it the Mac
/// shows only its Restart screen (`OutdatedScreen`) until the daemon has
/// restarted into the bundled one; the phone, never blocked, says to open
/// Nushi on the Mac (`OldDaemonBar`). The phone's is built into the
/// relay's web app (ADR 0113), so it moves when the relay is updated.
/// The API of the newest stable release at least 7 days old, raised in
/// the commit that cuts each stable release (`docs/development.md`'s
/// Releases); a gate at or below it goes (`api_floor_test.dart`).
const apiFloor = 120;

// The gates above the floor (ADR 0004), oldest first: each guards a call
// or a request field a daemon between the floor and the app's API lacks
// (a field an older daemon would drop unsaid most of all), and each goes
// with the floor once the floor reaches it (`api_floor_test.dart`).

/// The API from which GetDiff answers one file (GetDiffRequest.path), what
/// a file preview's change marks are drawn from. Goes with the floor.
const oneFileDiffApi = 121;

/// The API from which GetDiff lists a base's changes by name alone
/// (GetDiffRequest.names), what the Files tree's dots come from. Goes with
/// the floor.
const namesDiffApi = 123;

/// The API that answers GetUsage (ADR 0136). Goes with the floor.
const usageApi = 126;

/// The API from which the daemon reads and sets which of a pull request's
/// files the user marked viewed (GetGitHubViewed, SetGitHubViewed). Goes
/// with the floor.
const viewedApi = 130;

/// The API from which the daemon says a comment's, a review's and a
/// description's reactions and adds or takes away the user's
/// (GitHubComment.reactions, ReactGitHub). Goes with the floor.
const reactionsApi = 131;

/// The API from which GetGitHubItems' items say their checks' commit
/// (`checks_oid`), so the chats' states are asked as the rows' items.
/// Goes with the floor.
const statesFromItemsApi = 133;

/// The API that finds in a chat's whole history (FindInChat). Goes with
/// the floor.
const findInChatApi = 136;

/// The API whose GetChatItems reaches back to an item (`through`). Goes
/// with the floor.
const pageThroughApi = 137;

/// The API from which the daemon opens a terminal that runs one command
/// and ends with it (OpenTerminalRequest.command). Goes with the floor.
const commandTerminalApi = 143;

/// The API from which the daemon wakes a sleeping chat without a message
/// (WakeChat): an older one has no Wake. Goes with the floor.
const wakeApi = 146;

/// The API from which Unqueue sends a queued message now in one call
/// (UnqueueRequest.send_now), keeping it queued should the send fail; an
/// older daemon takes it out, then has it sent. Goes with the floor.
const sendNowApi = 147;

/// The API from which the daemon never removes a chat because its agent
/// no longer has its session (ADR 0015's amendment of 2026-11-25): a
/// daemon at 150 or below may, and says so in ListChats' `removed` and the
/// `removedChats` event, which the removed chats' bar shows. The bar, its
/// [Daemon.removedChats] and DismissRemovedChats go with the floor.
const keepsGoneChatsApi = 151;

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
class Daemon extends ChangeNotifier {
  /// [transport] reaches the daemon: on the Mac its socket with the
  /// client token (`macDaemon` in main.dart), on the phone its relay's,
  /// in a test a fake. The phone passes [remote]: then nothing of the
  /// Mac's runs (no bundled daemon, no app log), and its link pings
  /// (phone/link.dart), which also keeps its relay connection alive.
  new({
    required connect.Transport transport,
    this.remote = false,
    this.drafts,
  }) {
    client = NushiServiceClient(transport);
    // The phone's link pings on its own schedule (phone/link.dart).
    if (remote) return;
    addListener(macView.tick);
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(ping()),
    );
    appLog.client = client;
    appLog.reachable = () => connected;
    unawaited(
      ping().then(
        (_) => appLog.info('app started', {
          'version': native.install.version,
          'api': '$apiVersion',
          'pid': '$pid',
          'daemon': connected ? 'answers' : 'not answering',
        }),
      ),
    );
  }

  /// Whether this is the phone's link to a Mac's daemon through a relay.
  final bool remote;

  /// Where the chats' drafts are kept, if anywhere (not in tests).
  final Drafts? drafts;

  late final NushiServiceClient client;
  Timer? _timer;

  /// The chats' images that came as references (ADR 0099): fetched as
  /// they show, kept by hash. The Mac's daemon is on the same machine, so
  /// it keeps fewer and lets a row's go once it's far off the screen.
  late final images = ChatImages(
    (chatId, sha256) async {
      final got = await client.getChatImage(
        GetChatImageRequest(chatId: chatId, sha256: sha256),
      );
      return bytesOf(got.data);
    },
    maxBytes: remote ? 64 << 20 : 32 << 20,
    local: !remote,
    whenBack: whenBack,
  );

  /// The projects' own icons, for their tiles in the Mac's sidebar (ADR
  /// 0112): each folder's asked of the daemon once (GetProjectIcon) and
  /// kept until the app quits. A daemon without the call answers none.
  late final projectIcons = ProjectIcons((folder) async {
    final got = await client.getProjectIcon(
      GetProjectIconRequest(folder: folder),
    );
    return got.data.isEmpty ? null : bytesOf(got.data);
  }, whenBack: whenBack);
  bool connected = false;

  /// Why the last ping failed (the phone shows it in details).
  Object? pingError;
  int daemonApi = 0; // the daemon's API version
  String _build = ''; // the running daemon's build
  int _links = 0; // times the daemon was reached anew ([whenBack])
  String daemonVersion = ''; // its release, "" when it isn't one (API 74)
  String daemonOs = ''; // its system, Go's name for it; "" before API 112
  int daemonPid = 0; // its process's id, as it last said; 0 before API 122

  /// The running daemon's build: its program's `<size>-<mtime in ms>`.
  String get daemonBuild => _build;

  /// The bundled daemon's build (`native.install.daemonBuild`): none on
  /// the phone, or when the app isn't packaged. Tests set one.
  late String? bundled = remote ? null : native.install.daemonBuild;

  /// What the daemon's restart into the bundled one waits for, as it last
  /// said (API 85): chats that run or wait, terminals running a command.
  List<RestartHold> restartHolds = const [];

  /// Whether the daemon took the last ask to restart once idle: it will
  /// restart by itself, as the Restart screen then says. One older than
  /// API 77 refuses the ask, and waits for Restart daemon.
  bool restartsWhenIdle = false;

  /// What the daemon's check for a newer release found, from its pings and
  /// events (API 86); empty until it said.
  UpdateCheck update = UpdateCheck();

  /// Whether the daemon last answered [updatesWhenIdle]: when it's gone,
  /// it's restarting.
  bool updating = false;
  final _launcher = Launcher();

  StreamSubscription<EventsResponse>? _events;

  /// Every stored chat, by id.
  final chats = <String, ChatState>{};

  /// Whether [chats] has been listed once: a chat not in it is gone.
  bool chatsListed = false;

  /// The chats the daemon removed because their agent no longer had their
  /// sessions, until [dismissRemoved]: only a daemon before
  /// [keepsGoneChatsApi] removes any.
  List<RemovedChat> removedChats = [];

  /// What the Mac's window shows, told to the daemon (not the phone's).
  late final macView = MacView(this);

  /// The open side chats: not stored, not listed. Each is its chat's
  /// [ChatState.side], the one place the link is kept.
  Iterable<ChatState> get sides =>
      chats.values.map((c) => c.side.value).nonNulls;

  /// The open side chat [id], if one is.
  ChatState? sideOf(String id) {
    for (final s in sides) {
      if (s.id == id) return s;
    }
    return null;
  }

  String? selectedId;
  ChatState? get selected => chats[selectedId];

  /// The places visited, for Back and Forward (ADR 0119): what shows is
  /// noted each time this notifies.
  final visits = Visits();

  @override
  void notifyListeners() {
    visits.see(switch (place) {
      ChatPlace() => selectedId == null ? null : Visit(place, chat: selectedId),
      final other => Visit(other),
    });
    super.notifyListeners();
  }

  /// What shows in the chat's place: the chat, Jira or GitHub.
  Place place = const ChatPlace();

  /// Settings, while it's open over the window (ADR 0087): it never
  /// changes [place].
  SettingsAt? settingsOpen;

  /// The section Settings opens on: the last one shown while the app runs.
  SettingsSection lastSettings = SettingsSection.general;

  /// The folder whose MCP servers Settings › MCP servers shows: the one
  /// picked there, else the open chat's, else the home folder.
  String? mcpFolder;

  /// The folder whose skills Settings › Skills shows, as [mcpFolder].
  String? skillsFolder;

  /// The agent whose skills show, once one was picked or the view was
  /// opened from a chat; null until then, when the view shows the agent a
  /// new chat would start with.
  String? skillsAgent;

  /// The chats' terminals, whose sessions end with the daemon.
  late final Terminals terminals = () {
    final t = Terminals(client);
    whenDisposed(t.dispose);
    return t;
  }();

  /// The chats' folders' dev servers (ADR 0098), the Mac's only.
  late final devServers = DevServers(client);

  /// A folder's code waiting for the user's word before a chat starts or
  /// moves there (see TrustCard).
  TrustAsk? trustAsk;

  /// What a bar over the app says once, until dismissed: a start the
  /// user walked away from (its trust card answered no).
  String? notice;

  Future<bool>? _pinging;

  Future<void>? _restarting;

  /// Whether the last [restartDaemon] failed (its caller shows why).
  bool restartFailed = false;

  /// Sees each event before it's applied (the Mac's notifications).
  void Function(EventsResponse)? onEvent;

  /// How many of a chat's latest items the phone takes first, and in each
  /// page before them (a slow link).
  static const recentItems = 80;

  /// The same on the Mac: a long chat's recent part is several screens
  /// (about 18 turns of a long chat's, 100 entries), and a page laid out
  /// over a few frames keeps a fast scroll up going ([DaemonPages]).
  static const macRecentItems = 200;

  /// Each chat's wait before its failed load tries again ([DaemonOpen]).
  final _loadRetries = <String, Timer>{};

  /// The chats' list changed here ahead of the daemon's events (pins):
  /// whatever shows it builds again.
  void listChanged() => notifyListeners();

  /// [notifyListeners], for this library's extensions: it's protected, and an
  /// extension isn't a subclass.
  void _changed() => notifyListeners();

  /// How many chats keep their items in memory: the shown one and the
  /// ones shown just before it, quick to go back to. A long chat's items
  /// take from about half a megabyte to several (tool output, diffs; an
  /// image over 64 KB comes as a reference, its bytes in [images]); kept
  /// for every chat opened since launch, they added up.
  static const keptChats = 6;

  /// The chats picked since launch, the last picked last.
  final _picked = <String>[];

  /// The folder a chat is starting in ('' for none), while one is, and
  /// its agent (the sidebar's placeholder row shows it).
  String? starting;
  String? startingAgent;

  /// Why each agent whose last start failed in this run didn't start, as
  /// the daemon said: its plain why ("Ante isn't installed: …"), or an
  /// older daemon's whole message ("couldn't start Ante: …"); a start that
  /// works clears it.
  final cantStart = <String, String>{};

  /// Each agent's sign-in through its own login, by name, once one began
  /// (`signInOf`, ADR 0145).
  final signIns = <String, SignInRun>{};

  final _disposers = <VoidCallback>[];

  /// Runs [f] as the daemon is disposed: a store of its own ends its
  /// timers (`GitHubItems`'s), `terminals` its sessions.
  void whenDisposed(VoidCallback f) => _disposers.add(f);

  /// Ends the events subscription: the next ping that answers subscribes
  /// again. A call cancelled before its response began goes on waiting for
  /// it, and fails when its channel is dropped ([DaemonLink.relink], then
  /// the phone's reset): into the cancel's future, the only place left, so
  /// that failure of a call nobody listens to any more is taken here.
  void _unsubscribe() {
    _events?.cancel().ignore();
    _events = null;
  }

  @override
  void dispose() {
    for (final f in _disposers) {
      f();
    }
    _timer?.cancel();
    for (final t in _loadRetries.values) {
      t.cancel();
    }
    _unsubscribe();
    super.dispose();
  }
}
