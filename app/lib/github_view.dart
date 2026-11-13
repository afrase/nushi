import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/back_swipe.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_bar.dart';
import 'package:nushi/github_filters.dart';
import 'package:nushi/github_inbox.dart';
import 'package:nushi/github_issue.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/run_state.dart';
import 'package:nushi/send_to_agent.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/token_notices.dart';
import 'package:nushi/widgets.dart';

/// ⌘G shows GitHub in place of the chat, and back.
const githubKey = Cmd(LogicalKeyboardKey.keyG);

/// How often the inbox is asked for again while the view shows (a quiet
/// ask: the daemon holds it back while a rate limit runs low).
const githubPoll = Duration(minutes: 1);

/// A pull request or an issue the GitHub view shows the details of: which
/// it is goes with it, so the pane stays one whatever the inbox holds.
typedef GitHubPick = ({GitHubRef ref, bool pull});

/// What the view had last, while the app runs: the host, the item picked,
/// and the one whose details show: kept whatever the inbox holds, so a
/// pull request that leaves Review requested stays a pull request.
String? _host;
GitHubRef? _picked;
GitHubPick? _details;

/// Shows [ref] in the GitHub view: its details (a pull request's when
/// [pull]), whatever the inbox holds.
void showItem(Daemon daemon, GitHubRef ref, {required bool pull}) {
  _host = ref.host;
  _picked = ref;
  _details = (ref: ref, pull: pull);
  daemon.go(const GitHubPlace());
}

/// The cards whose older items show too ("Show"), until Nushi quits or
/// the span or host changes.
final Set<String> _wide = runSet();

/// Forgets what the view had (tests start afresh).
@visibleForTesting
void forgetGitHubView() {
  _host = _picked = null;
  _details = null;
  _wide.clear();
}

/// GitHub in the app, in the chat's place as Jira's view is (the sidebar
/// of chats stays): an inbox of pull requests whose review is asked of me
/// (or my teams too: the section's choice, remembered), mine, and issues
/// assigned to me, on a host, in the repositories of the folders Nushi
/// knows or all; an item's details in the list's place. Keys: ↑↓ (or
/// j k) pick, ⏎ the details, ⌘⏎ Start work, ⌘R asks again, Esc back to
/// the list, then closes.
class GitHubView extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<GitHubView> createState() => _GitHubViewState();
}

class _GitHubViewState extends State<GitHubView> {
  List<GitHubHost>? _hosts;
  List<GitHubRepo> _repos = const [];
  ListGitHubInboxResponse? _inbox;
  String? _error;
  bool _loading = false;
  int _asked = 0;
  Timer? _poll;

  /// Which inbox [_inbox] is (host, repositories, teams), and when GitHub
  /// said so if it's what the daemon kept from last time.
  String? _shown;
  DateTime? _cachedAt;

  /// A load has gone on 150 ms with nothing to show: the skeleton shows.
  bool _slow = false;
  Timer? _slowTimer;
  final _listFocus = FocusNode(debugLabel: 'github list');
  final _viewFocus = FocusNode(debugLabel: 'github view');

  /// The selected row's, to keep it in view.
  final GlobalKey _selectedRow = GlobalKey(debugLabel: 'github selected');

  /// The selected row's Start work menu, for ⌘⏎, and whose it is: the
  /// row registers it as it's built, and a row not built (scrolled away)
  /// can't, so it may be another's.
  (GitHubRef, OpenMenu)? _start;

  GitHubHost? get _hostNow {
    final hosts = _hosts ?? const <GitHubHost>[];
    return hosts.where((h) => h.host == _host).firstOrNull ??
        hosts.where((h) => h.problem.isEmpty).firstOrNull ??
        hosts.firstOrNull;
  }

  List<String> get _knownRepos => [
    for (final r in _repos)
      if (r.host == _hostNow?.host) r.repo,
  ];

  /// Only the repositories of the folders Nushi knows (remembered).
  bool get _known => githubKnownRepos.value;

  List<Section> get _sections => sectionsOf(_inbox);

  /// The items the keys move through: the open cards'.
  List<GitHubItem> get _items => visibleItems(_sections);

  @override
  void initState() {
    super.initState();
    unawaited(_loadHosts());
    _poll = Timer.periodic(githubPoll, (_) => unawaited(_load(quiet: true)));
    _underSettings = widget.daemon.settingsOpen != null;
    widget.daemon.addListener(_settingsShut);
  }

  // Settings opens over the view (ADR 0087), where a token can be added or
  // allowed: the hosts are read again when it shuts.
  bool _underSettings = false;

  void _settingsShut() {
    final under = widget.daemon.settingsOpen != null;
    if (_underSettings && !under && mounted) unawaited(_loadHosts());
    _underSettings = under;
  }

  @override
  void dispose() {
    widget.daemon.removeListener(_settingsShut);
    _hostsAgain.cancel();
    _poll?.cancel();
    _slowTimer?.cancel();
    _listFocus.dispose();
    _viewFocus.dispose();
    super.dispose();
  }

  // The hosts asked for while the daemon was gone: the inbox needs one.
  late final _hostsAgain = LoadAgain(widget.daemon, () {
    if (mounted) unawaited(_loadHosts());
  });

  Future<void> _loadHosts() async {
    _hostsAgain.cancel();
    try {
      final r = await widget.daemon.client.listGitHubHosts(
        ListGitHubHostsRequest(),
      );
      keepGitHubLogins(r.hosts);
      if (!mounted) return;
      setState(() => _hosts = r.hosts);
      _host = _hostNow?.host;
      try {
        _repos = await loadRepos(widget.daemon);
      } on Object {
        _repos = const []; // the filter then has nothing to offer
      }
      await _load();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _hosts = const [];
          _error = errorText(e);
        });
        _hostsAgain.failed(e);
      }
    }
  }

  /// Asks for the inbox again; [quiet] (the timer) keeps what shows until
  /// it answers, and an error then leaves it as it was. Another inbox than
  /// the one shown shows what the daemon kept of it meanwhile.
  Future<void> _load({bool quiet = false}) async {
    final host = _hostNow;
    if (host == null || host.needsOk || host.needsRestart) {
      // Its token can't be read yet (the notice says why), and an inbox
      // still asked for is another host's.
      _asked++;
      if (_loading) setState(() => _loading = _slow = false);
      return;
    }
    final n = ++_asked;
    final req = ListGitHubInboxRequest(
      host: host.host,
      repos: _known ? _knownRepos : const [],
      quiet: quiet,
      teams: githubTeamReviews.value,
      updatedDays: githubDays.value,
      wide: _wide.toList()..sort(),
      hide: _hidden,
      owners: _known ? const [] : _owners,
    );
    // Every part of the filter, so another's kept inbox never shows.
    final key = [
      req.host,
      req.repos.join(' '),
      req.teams,
      req.updatedDays,
      req.wide.join(' '),
      req.hide.join(' '),
      req.owners.join(' '),
    ].join('\n');
    if (!quiet) {
      setState(() {
        _loading = true;
        _slow = false;
      });
      _slowTimer?.cancel();
      _slowTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && n == _asked && _loading) setState(() => _slow = true);
      });
      if (_shown != key) unawaited(_showKept(n, key, req));
    }
    try {
      final r = await widget.daemon.client.listGitHubInbox(req);
      if (n != _asked || !mounted) return;
      setState(() {
        _show(key, r);
        _cachedAt = null;
        _error = r.stale.isEmpty ? null : r.stale;
      });
    } on Object catch (e) {
      if (n == _asked && mounted && !quiet) {
        setState(() {
          // Another filter's rows aren't what this one asked for.
          if (_shown != key) _inbox = _shown = null;
          _error = errorText(e);
        });
      }
    } finally {
      if (n == _asked && mounted) setState(() => _loading = false);
    }
  }

  /// Shows the inbox the daemon kept from last time, until GitHub answers.
  Future<void> _showKept(int n, String key, ListGitHubInboxRequest req) async {
    try {
      final r = await widget.daemon.client.listGitHubInbox(
        req.deepCopy()..cached = true,
      );
      // GitHub answered first, or nothing was kept.
      if (n != _asked || !mounted || !_loading || r.atMs == 0) return;
      setState(() {
        _show(key, r);
        _cachedAt = DateTime.fromMillisecondsSinceEpoch(r.atMs.toInt());
      });
    } on Object {
      // Nothing kept: GitHub's answer decides.
    }
  }

  void _show(String key, ListGitHubInboxResponse r) {
    _shown = key;
    _inbox = r;
    if (_details == null && !_items.any((x) => sameRef(x.ref, _picked))) {
      _picked = _items.firstOrNull?.ref;
    }
  }

  int get _at => _items.indexWhere((x) => sameRef(x.ref, _picked));

  void _move(int by) {
    final items = _items;
    if (items.isEmpty) return;
    final next = (_at + by).clamp(0, items.length - 1);
    setState(() => _picked = items[next].ref);
    revealRow(_selectedRow, down: by > 0);
  }

  /// ⌘⏎: the selected row's Start work, once it's in view (its menu opens
  /// by it).
  void _startWork() => revealRow(
    _selectedRow,
    down: true,
    then: () {
      if (_start case (final ref, final open)
          when sameRef(ref, _picked) && _selectedRow.currentContext != null) {
        open();
      }
    },
  );

  void _open(GitHubItem it) {
    setState(() {
      _picked = it.ref;
      _details = (ref: it.ref, pull: it.pull);
    });
    _viewFocus.requestFocus(); // the list, which had it, goes
  }

  void _back() {
    setState(() => _details = null);
    unawaited(_load(quiet: true));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listFocus.requestFocus(),
    );
    _revealPicked();
  }

  /// Brings the picked row into view once the list is back, where it was
  /// scrolled (CardList.keepScrollAs): above or below it, whichever it is.
  void _revealPicked() => revealRow(
    _selectedRow,
    down: true,
    then: () => revealRow(_selectedRow, down: false),
  );

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final meta = cmdPressed();
    final items = _items;
    if (k == LogicalKeyboardKey.enter && items.isNotEmpty && _at >= 0) {
      meta ? _startWork() : _open(items[_at]);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyJ && !meta) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyK && !meta) {
      _move(-1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  List<String> get _hidden => githubHidden.value[_hostNow?.host] ?? const [];
  List<String> get _owners => githubOwners.value[_hostNow?.host] ?? const [];

  void _setHidden(List<String> hidden) {
    final host = _hostNow?.host;
    if (host == null) return;
    setState(() => githubHidden.value = {...githubHidden.value, host: hidden});
    unawaited(_load());
  }

  void _setOwners(List<String> owners) {
    final host = _hostNow?.host;
    if (host == null || listEquals(owners, _owners)) return;
    setState(() => githubOwners.value = {...githubOwners.value, host: owners});
    unawaited(_load());
  }

  void _setDays(int days) {
    if (days == githubDays.value) return;
    setState(() {
      githubDays.value = days;
      _wide.clear();
    });
    unawaited(_load());
  }

  /// Review requested of me only, or of my teams too: remembered, and
  /// asked again.
  void _whose(bool teams) {
    if (teams == githubTeamReviews.value) return;
    setState(() => githubTeamReviews.value = teams);
    unawaited(_load());
  }

  /// Starts the daemon again (from the app, in the login session, as
  /// this build), so it can reach the keychain.
  void _restart() => unawaited(
    tryOrShow(context, () async {
      await widget.daemon.restartDaemon();
      if (mounted) await _loadHosts();
    }),
  );

  // Its hosts are read again when Settings shuts ([_settingsShut]).
  void _settings() =>
      widget.daemon.openSettings(section: SettingsSection.github);

  @override
  Widget build(BuildContext context) {
    final hosts = _hosts;
    final host = _hostNow;
    final details = _details;
    return CallbackShortcuts(
      bindings: {
        const Cmd(LogicalKeyboardKey.keyR): _load,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            details != null ? _back() : widget.daemon.back(),
      },
      child: Focus(
        focusNode: _viewFocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GitHubBar(
              hosts: hosts ?? const [],
              host: host,
              known: _known,
              knownRepos: _knownRepos.length,
              owners: _owners,
              hidden: _hidden,
              seen: reposIn(_inbox),
              onOwners: _setOwners,
              onHidden: _setHidden,
              onDays: _setDays,
              loading: _loading,
              updated: _cachedAt,
              onHost: (h) {
                setState(() {
                  _host = h;
                  _inbox = null;
                  _details = null;
                  _wide.clear();
                });
                unawaited(_load());
              },
              onKnown: (known) {
                if (known == _known) return;
                setState(() => githubKnownRepos.value = known);
                unawaited(_load());
              },
              onRefresh: _load,
              onClose: widget.daemon.back,
            ),
            Expanded(
              child: hosts == null
                  ? const SizedBox()
                  : host == null
                  ? NoHost(onSettings: _settings, error: _error)
                  : details != null
                  ? BackSwipe(onBack: _back, child: _detailsPane(details))
                  : _list(host),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsPane(GitHubPick details) {
    final (:ref, :pull) = details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            children: [
              IconTap(
                Icons.arrow_back,
                tooltip: 'The inbox (Esc)',
                onTap: _back,
              ),
            ],
          ),
        ),
        Expanded(
          child: pull
              ? GitHubPullPane(
                  key: ValueKey('${ref.host} ${ref.repo} ${ref.number}'),
                  daemon: widget.daemon,
                  ref: ref,
                )
              : GitHubIssuePane(
                  key: ValueKey('${ref.host} ${ref.repo} ${ref.number}'),
                  daemon: widget.daemon,
                  ref: ref,
                ),
        ),
      ],
    );
  }

  Widget _list(GitHubHost host) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (host.needsOk || host.needsRestart)
          TokenNotices(
            needsOk: host.needsOk,
            needsRestart: host.needsRestart,
            problem: host.problem,
            onAllow: () => tryOrShow(context, () async {
              await widget.daemon.client.allowGitHubToken(
                AllowGitHubTokenRequest(host: host.host),
              );
              await _loadHosts();
            }),
            onRestart: _restart,
          )
        else if (host.problem.isNotEmpty)
          Notice(host.problem, action: 'Settings…', onAction: _settings),
        if (_error case final e?)
          Notice(
            _inbox == null
                ? e
                : 'Showing what GitHub said at '
                      '${_time(_inbox!.atMs.toInt())}: $e',
          ),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: _inbox == null
                ? _loading && _slow
                      ? const RowsLoading()
                      : const SizedBox()
                : ListenableBuilder(
                    listenable: Listenable.merge([
                      githubCardOrder,
                      githubCollapsed,
                    ]),
                    builder: (context, _) => InboxCards(
                      daemon: widget.daemon,
                      sections: _sections,
                      picked: _picked,
                      days: githubDays.value,
                      whose: Whose(onPick: _whose),
                      onOpen: (it) {
                        _listFocus.requestFocus();
                        _open(it);
                      },
                      onOlder: (id) {
                        setState(() => _wide.add(id));
                        unawaited(_load());
                      },
                      onHide: (repo) => _setHidden({..._hidden, repo}.toList()),
                      selectedRow: _selectedRow,
                      startMenu: (ref, open) => _start = (ref, open),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  static String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour}:${'${d.minute}'.padLeft(2, '0')}';
  }
}
