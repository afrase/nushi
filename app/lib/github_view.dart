import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_issue.dart';
import 'package:nushi/github_parts.dart';
import 'package:nushi/github_pull.dart';
import 'package:nushi/github_settings.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘G shows GitHub in place of the chat, and back.
const githubKey = SingleActivator(LogicalKeyboardKey.keyG, meta: true);

/// How often the inbox is asked for again while the view shows (a quiet
/// ask: the daemon holds it back while a rate limit runs low).
const githubPoll = Duration(minutes: 1);

/// What the view had last, while the app runs: the host, whether the
/// inbox is only the repositories of folders Nushi knows, the item picked
/// and whether its details show.
String? _host;
bool _known = false;
GitHubRef? _picked;
bool _details = false;

/// Forgets what the view had (tests start afresh).
@visibleForTesting
void forgetGitHubView() {
  _host = _picked = null;
  _known = _details = false;
}

/// An inbox's section: its title, items, and how many GitHub found.
typedef Section = ({String title, List<GitHubItem> items, int total});

/// GitHub in the app, in the chat's place as Jira's view is (the sidebar
/// of chats stays): an inbox of pull requests whose review is asked of me
/// (or my teams too: the section's choice, remembered), mine, and issues
/// assigned to me, on a host, in the repositories of the folders Nushi
/// knows or all; an item's details in the list's place. Keys: ↑↓ (or
/// j k) pick, ⏎ the details, ⌘⏎ Start work, ⌘R asks again, Esc back to
/// the list, then closes.
class GitHubView extends StatefulWidget {
  const new(this.daemon, {super.key, this.now});

  final Daemon daemon;

  /// The time ages are counted from (tests); now when null.
  final DateTime? now;

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
  final _listFocus = FocusNode(debugLabel: 'github list');
  final _viewFocus = FocusNode(debugLabel: 'github view');

  /// The selected row's Start work menu, for ⌘⏎.
  OpenMenu? _start;

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

  List<Section> get _sections {
    final i = _inbox;
    if (i == null) return const [];
    return [
      (title: 'Review requested', items: i.review, total: i.reviewTotal),
      (title: 'My pull requests', items: i.mine, total: i.mineTotal),
      (title: 'Assigned issues', items: i.assigned, total: i.assignedTotal),
    ];
  }

  List<GitHubItem> get _items => [for (final s in _sections) ...s.items];

  @override
  void initState() {
    super.initState();
    if (widget.daemon.githubShow case final ref?) {
      _picked = ref;
      _details = true;
      _host = ref.host;
      widget.daemon.githubShow = null;
    }
    unawaited(_loadHosts());
    _poll = Timer.periodic(githubPoll, (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _listFocus.dispose();
    _viewFocus.dispose();
    super.dispose();
  }

  Future<void> _loadHosts() async {
    try {
      final r = await widget.daemon.client.listGitHubHosts(
        ListGitHubHostsRequest(),
      );
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
          _error = githubError(e);
        });
      }
    }
  }

  /// Asks for the inbox again; [quiet] (the timer) keeps what shows until
  /// it answers, and an error then leaves it as it was.
  Future<void> _load({bool quiet = false}) async {
    final host = _hostNow;
    if (host == null || host.needsOk) return; // its token can't be read yet
    final n = ++_asked;
    if (!quiet) setState(() => _loading = true);
    try {
      final r = await widget.daemon.client.listGitHubInbox(
        ListGitHubInboxRequest(
          host: host.host,
          repos: _known ? _knownRepos : const [],
          quiet: quiet,
          teams: githubTeamReviews.value,
        ),
      );
      if (n != _asked || !mounted) return;
      setState(() {
        _inbox = r;
        _error = r.stale.isEmpty ? null : r.stale;
        if (!_details && !_items.any((x) => _same(x.ref, _picked))) {
          _picked = _items.firstOrNull?.ref;
        }
      });
    } on Object catch (e) {
      if (n == _asked && mounted && !quiet) {
        setState(() => _error = githubError(e));
      }
    } finally {
      if (n == _asked && mounted) setState(() => _loading = false);
    }
  }

  static bool _same(GitHubRef a, GitHubRef? b) =>
      b != null && a.host == b.host && a.repo == b.repo && a.number == b.number;

  int get _at => _items.indexWhere((x) => _same(x.ref, _picked));

  void _move(int by) {
    final items = _items;
    if (items.isEmpty) return;
    final next = (_at + by).clamp(0, items.length - 1);
    setState(() => _picked = items[next].ref);
  }

  void _open(GitHubItem it) {
    setState(() {
      _picked = it.ref;
      _details = true;
    });
    _viewFocus.requestFocus(); // the list, which had it, goes
  }

  void _back() {
    setState(() => _details = false);
    unawaited(_load(quiet: true));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listFocus.requestFocus(),
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final items = _items;
    if (k == LogicalKeyboardKey.enter && items.isNotEmpty && _at >= 0) {
      meta ? _start?.call() : _open(items[_at]);
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

  /// Review requested of me only, or of my teams too: remembered, and
  /// asked again.
  void _whose(bool teams) {
    if (teams == githubTeamReviews.value) return;
    setState(() => githubTeamReviews.value = teams);
    unawaited(_load());
  }

  void _settings() => unawaited(
    showSettings(context, widget.daemon.client, github: true).then((_) {
      if (mounted) unawaited(_loadHosts());
    }),
  );

  @override
  Widget build(BuildContext context) {
    final hosts = _hosts;
    final host = _hostNow;
    final picked = _picked;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _load,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _details ? _back() : widget.daemon.showGitHub(open: false),
      },
      child: Focus(
        focusNode: _viewFocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Bar(
              hosts: hosts ?? const [],
              host: host,
              known: _known,
              knownRepos: _knownRepos.length,
              loading: _loading,
              onHost: (h) {
                setState(() {
                  _host = h;
                  _inbox = null;
                  _details = false;
                });
                unawaited(_load());
              },
              onKnown: (known) {
                setState(() => _known = known);
                unawaited(_load());
              },
              onRefresh: _load,
              onClose: () => widget.daemon.showGitHub(open: false),
            ),
            Expanded(
              child: hosts == null
                  ? const SizedBox()
                  : host == null
                  ? NoHost(onSettings: _settings, error: _error)
                  : _details && picked != null
                  ? _detailsPane(picked)
                  : _list(host),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsPane(GitHubRef ref) {
    final item = _items.where((x) => _same(x.ref, ref)).firstOrNull;
    final pull =
        item?.pull ??
        widget.daemon.chats.values.any(
          (c) =>
              (c.github?.pull ?? false) &&
              c.github?.number == ref.number &&
              c.github?.repo == ref.repo,
        );
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
                  now: widget.now,
                )
              : GitHubIssuePane(
                  key: ValueKey('${ref.host} ${ref.repo} ${ref.number}'),
                  daemon: widget.daemon,
                  ref: ref,
                  now: widget.now,
                ),
        ),
      ],
    );
  }

  Widget _list(GitHubHost host) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final now = widget.now ?? DateTime.now();
    final rows = <Widget>[];
    for (final s in _sections) {
      final title = Text(
        '${s.title}  '
        '${s.total > s.items.length ? '${s.items.length} of ' : ''}'
        '${s.total > s.items.length ? s.total : s.items.length}',
        style: theme.ui(t.textSecondary, size: 12, weight: FontWeight.w600),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.fromLTRB(18, rows.isEmpty ? 10 : 18, 18, 4),
          child:
              rows
                  .isEmpty // Review requested: whose
              ? Row(
                  children: [
                    title,
                    const SizedBox(width: 12),
                    _Whose(onPick: _whose),
                  ],
                )
              : title,
        ),
      );
      if (s.items.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 2),
            child: Text('None', style: theme.ui(t.textMuted, size: 12)),
          ),
        );
      }
      for (final it in s.items) {
        final selected = _same(it.ref, _picked);
        rows.add(
          ItemRow(
            key: ValueKey('${s.title} ${it.id}'),
            daemon: widget.daemon,
            item: it,
            selected: selected,
            now: now,
            onOpen: () {
              _listFocus.requestFocus();
              _open(it);
            },
            startMenu: (open) => _start = open,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (host.needsOk)
          _Notice(
            'This build of Nushi needs your OK to read the token from the '
            'keychain; macOS asks for your password.',
            action: 'Allow…',
            onAction: () => tryOrShow(context, () async {
              await widget.daemon.client.allowGitHubToken(
                AllowGitHubTokenRequest(host: host.host),
              );
              await _loadHosts();
            }),
          )
        else if (host.problem.isNotEmpty)
          _Notice(host.problem, action: 'Settings…', onAction: _settings),
        if (_error case final e?)
          _Notice(
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
                ? const SizedBox()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: rows,
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

/// Review requested's choice: "Only me" (pull requests asking me by
/// name) or "Me and my teams" (a team of mine asked too).
class _Whose extends StatelessWidget {
  const new({required this.onPick});

  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final teams = githubTeamReviews.value;
    return Menu(
      entries: [
        MenuEntry('Only me', checked: !teams, onPick: () => onPick(false)),
        MenuEntry(
          'Me and my teams',
          checked: teams,
          onPick: () => onPick(true),
        ),
      ],
      child: Text(
        '${teams ? 'Me and my teams' : 'Only me'} ▾',
        style: theme.ui(theme.t.textMuted, size: 12),
      ),
    );
  }
}

/// A line above the list: a problem, or what shows is old.
class _Notice extends StatelessWidget {
  const new(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(10),
      decoration: box(t.needs, fill: t.needsSoft),
      child: Row(
        children: [
          Expanded(child: Text(text, style: theme.ui(t.needs, size: 12))),
          if (action case final a?) ...[
            const SizedBox(width: 8),
            Button(label: a, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// The view's bar: the host shown (a menu of the others), whether the
/// inbox is the known folders' repositories or all, Refresh, Close.
class _Bar extends StatelessWidget {
  const new({
    required this.hosts,
    required this.host,
    required this.known,
    required this.knownRepos,
    required this.loading,
    required this.onHost,
    required this.onKnown,
    required this.onRefresh,
    required this.onClose,
  });

  final List<GitHubHost> hosts;
  final GitHubHost? host;
  final bool known;
  final int knownRepos;
  final bool loading;
  final ValueChanged<String> onHost;
  final ValueChanged<bool> onKnown;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final h = host;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('GitHub', style: theme.ui(t.text, weight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (hosts.length > 1)
            Menu(
              entries: [
                for (final x in hosts)
                  MenuEntry(
                    x.host,
                    detail: x.login,
                    checked: x.host == h?.host,
                    onPick: () => onHost(x.host),
                  ),
              ],
              child: Text(
                '${h?.host ?? ''} ▾',
                style: theme.ui(t.textSecondary, size: 12),
              ),
            )
          else if (h != null)
            Text(
              [h.host, if (h.login.isNotEmpty) h.login].join(' · '),
              style: theme.ui(t.textSecondary, size: 12),
            ),
          const SizedBox(width: 12),
          if (h != null)
            Menu(
              entries: [
                MenuEntry(
                  'All repositories',
                  checked: !known,
                  onPick: () => onKnown(false),
                ),
                MenuEntry(
                  "My folders' repositories",
                  detail: '$knownRepos',
                  checked: known,
                  onPick: knownRepos == 0 ? null : () => onKnown(true),
                ),
              ],
              child: Text(
                '${known ? "My folders' repositories" : 'All repositories'} ▾',
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ),
          const Spacer(),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Loading…', style: theme.ui(t.textMuted, size: 12)),
            ),
          IconTap(Icons.refresh, tooltip: 'Refresh (⌘R)', onTap: onRefresh),
          IconTap(Icons.close, tooltip: 'Close (⌘G)', onTap: onClose),
        ],
      ),
    );
  }
}
