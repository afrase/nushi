import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectrpc/connect.dart' as connect;
import 'package:connectrpc/http2.dart';
import 'package:connectrpc/protobuf.dart';
import 'package:connectrpc/protocol/connect.dart' as protocol;
import 'package:flutter/foundation.dart';
import 'package:nushi/agents.dart';
import 'package:nushi/app_log.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/context_cache.dart';
import 'package:nushi/drafts.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/issue_chat.dart';
import 'package:nushi/mac_view.dart';
import 'package:nushi/place.dart';
import 'package:nushi/remote.dart';
import 'package:nushi/review.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/terminals.dart';
import 'package:nushi/trust_ask.dart';
import 'package:uds_transport/uds_transport.dart';

export 'package:nushi/issue_chat.dart';
export 'package:nushi/place.dart';

part 'daemon_events.dart';
part 'daemon_link.dart';
part 'daemon_open.dart';
part 'daemon_places.dart';
part 'daemon_sides.dart';
part 'daemon_start.dart';

final support = '${Platform.environment['HOME']}/Library/Application Support';

/// The daemon's data folder; `NUSHI_DATA` picks another one (development).
/// Tests get a new one in the temporary folder, never the user's, even
/// with `NUSHI_DATA` exported (a restart there would stop its daemon):
/// one per test process, as test files run side by side and a shared
/// app.json would let one file's settings overwrite another's; new, so a
/// reused pid starts from no one's prefs. flutter_test_config deletes it.
final String dataDir = Platform.environment.containsKey('FLUTTER_TEST')
    ? Directory.systemTemp.createTempSync('nushi-test-').path
    : Platform.environment['NUSHI_DATA'] ?? '$support/Nushi';

/// The API version this app was built with (`internal/api.Version`).
const apiVersion = 96;

/// The API from which the daemon keeps which chats are pinned, in order
/// (Chat.pin, PinChats).
const pinApi = 90;

/// The API from which the daemon re-runs a pull request's failed jobs
/// (RerunGitHubChecks).
const rerunApi = 88;

/// The API from which the daemon checks for a newer release of Nushi
/// (Ping's update, CheckForUpdates, Settings.check_updates).
const updatesApi = 86;

/// The API from which a daemon restarts itself once nothing runs, when
/// asked (RestartWhenIdle).
const restartWhenIdleApi = 77;

/// A pull request or an issue the GitHub view shows the details of: which
/// it is goes with it, so the pane stays one whatever the inbox holds.
typedef GitHubPick = ({GitHubRef ref, bool pull});

/// The app's link to nushid. [connected] follows a ping every few seconds;
/// while connected, daemon events keep [chats] current. When no daemon
/// answers, the bundled one is started; a running daemon is only ever
/// stopped by [restartDaemon].
class Daemon extends ChangeNotifier {
  /// A test passes a [transport] of its own. The phone passes its
  /// relay's, [remote]: then nothing of the Mac's runs (no bundled daemon,
  /// no token, no app log), and its link pings (phone/link.dart), which
  /// also keeps its relay connection alive.
  new({connect.Transport? transport, this.remote = false, this.drafts}) {
    client = NushiServiceClient(
      transport ??
          protocol.Transport(
            baseUrl: 'http://nushid',
            codec: const ProtoCodec(),
            httpClient: createHttpClient(transport: _transport),
            interceptors: [_auth],
          ),
    );
    // The phone's link pings on its own schedule (phone/link.dart).
    if (remote) return;
    addListener(macView.tick);
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(ping()),
    );
    appLog.client = client;
    appLog.reachable = () => connected && hasLog(daemonApi);
    unawaited(
      ping().then(
        (_) => appLog.info('app started', {
          'version': appVersion,
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

  late final _transport = UdsTransport('$dataDir/nushid.sock');
  late final NushiServiceClient client;
  Timer? _timer;
  bool connected = false;

  /// Why the last ping failed (the phone shows it in details).
  Object? pingError;
  int daemonApi = 0; // the daemon's API version
  String _build = ''; // the running daemon's build
  String daemonVersion = ''; // its release, "" when it isn't one (API 74)

  /// The running daemon's build: its program's `<size>-<mtime in ms>`.
  String get daemonBuild => _build;

  /// The bundled daemon's build ([bundledBuild]): none on the phone, or
  /// when the app isn't packaged. Tests set one.
  late String? bundled = remote ? null : bundledBuild;

  /// What the daemon's restart into the bundled one waits for, as it last
  /// said (API 85): chats that run or wait, terminals running a command.
  List<RestartHold> restartHolds = const [];

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
  /// sessions, until [dismissRemoved].
  List<RemovedChat> removedChats = [];

  /// What the Mac's window shows, told to the daemon (not the phone's).
  late final macView = MacView(this);

  /// The open side chats, by id: not stored, not listed.
  final sides = <String, ChatState>{};
  String? selectedId;
  ChatState? get selected => chats[selectedId];

  connect.AnyFn<I, O> _auth<I extends Object, O extends Object>(
    connect.AnyFn<I, O> next,
  ) => (req) async {
    // Read at every call: the daemon writes it on its first start.
    final token = await File('$dataDir/token').readAsString();
    req.headers['authorization'] = 'Bearer ${token.trim()}';
    return await next(req);
  };

  /// What shows in the chat's place: the chat, Settings, Jira or GitHub.
  Place place = const ChatPlace();

  /// What Settings closes back to: the Jira or GitHub view it opened
  /// from, else the chat.
  Place _beforeSettings = const ChatPlace();

  /// The section Settings opens on: the last one shown while the app runs.
  SettingsSection lastSettings = SettingsSection.general;

  /// What the GitHub view is to show when it opens next (a chat's pull
  /// request or issue), taken by the view.
  GitHubPick? githubShow;

  /// The folder whose MCP servers Settings › MCP servers shows: the one
  /// picked there, else the open chat's, else the home folder.
  String? mcpFolder;

  /// The folder whose skills Settings › Skills shows, as [mcpFolder].
  String? skillsFolder;

  /// The agent whose skills show: Claude unless another was picked, or
  /// the view was opened from another agent's chat.
  String skillsAgent = 'claude';

  /// The chats' terminals.
  late final terminals = Terminals(client);

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

  /// Events that came while the chat list was on its way.
  List<EventsResponse>? _held;

  /// Sees each event before it's applied (the Mac's notifications).
  void Function(EventsResponse)? onEvent;

  /// How many of a chat's latest items the phone takes first.
  static const recentItems = 80;

  /// Takes the page of [chat]'s items before those it has, as the phone
  /// scrolls up (nothing when it has them all, or a page is on its way).
  Future<void> loadOlder(ChatState chat) async {
    if (chat.older == 0 || chat.loadingOlder || chat.items.isEmpty) return;
    chat
      ..loadingOlder = true
      ..notifyListeners();
    final before = chat.items.first.id;
    final snapshot = chat.snapshots;
    try {
      final page = await client.getChatItems(
        GetChatItemsRequest(
          chatId: chat.id,
          before: before,
          limit: recentItems,
        ),
      );
      // Only onto what it was asked for: a reload meanwhile (a reconnect,
      // a rewind) took another snapshot.
      if (chat.loaded &&
          chat.snapshots == snapshot &&
          chat.items.isNotEmpty &&
          chat.items.first.id == before) {
        chat.prepend(page.items, page.older);
      }
    } on Object {
      // Asked again on the next scroll up.
    } finally {
      chat
        ..loadingOlder = false
        ..notifyListeners();
    }
  }

  Timer? _loadRetry;

  /// The chats' list changed here ahead of the daemon's events (pins):
  /// whatever shows it builds again.
  void listChanged() => notifyListeners();

  /// [notifyListeners], for this library's extensions: it's protected, and an
  /// extension isn't a subclass.
  void _changed() => notifyListeners();

  /// How many chats keep their items in memory: the shown one and the
  /// ones shown just before it, quick to go back to. A long chat's items
  /// take from about half a megabyte to several (tool output, diffs,
  /// images); kept for every chat opened since launch, they added up.
  static const keptChats = 6;

  /// The chats picked since launch, the last picked last.
  final _picked = <String>[];

  /// The folder a chat is starting in ('' for none), while one is.
  String? starting;

  /// Why each agent whose last start failed in this run didn't start, as
  /// the daemon said ("couldn't start Ante: …"); a start that works clears
  /// it.
  final cantStart = <String, String>{};

  @override
  void dispose() {
    _timer?.cancel();
    _loadRetry?.cancel();
    unawaited(_events?.cancel());
    if (!remote) unawaited(_transport.close());
    super.dispose();
  }
}
