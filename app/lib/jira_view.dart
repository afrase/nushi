import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/bundled_daemon.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/jira_sources.dart';
import 'package:nushi/jira_tasks.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘J shows Jira in place of the chat, and back.
const jiraKey = SingleActivator(LogicalKeyboardKey.keyJ, meta: true);

/// How often the open list is asked for again while the view shows.
const jiraPoll = Duration(minutes: 1);

/// What the view had last: the site (the one used last, kept), and while
/// the app runs every site's issues instead ([_all]), the list, the JQL
/// typed, the issue picked and whether its details show.
String? get _site => lastJiraSite.value;
set _site(String? site) => lastJiraSite.value = site;
bool _all = false;
String _list = 'mine';
String _jql = '';
String? _key;
bool _details = false;

/// Forgets what the view had (tests start afresh).
@visibleForTesting
void forgetJiraView() {
  _all = _details = false;
  _list = 'mine';
  _jql = '';
  _key = null;
}

/// Shows [key], an issue of [site], in the Jira view: its details.
void showIssue(Daemon daemon, String site, String key) {
  _site = site;
  _all = false;
  _key = key;
  _details = true;
  daemon.showJira(open: true);
}

/// Jira in the app, in the chat's place as the MCP view is (the sidebar of
/// chats stays): a task list, as Orca's task drawer (TaskList), of my
/// open issues (on a site, or every site), the active sprint of a board,
/// a saved search or JQL; a row's details (JiraIssuePane) in the list's
/// place. Keys: ↑↓ (or j k) pick, ⏎ the details, ⌘⏎ Start work, ⌘R asks
/// again, ⌥⌘1–9 a list, / the JQL, Esc back to the list, then closes.
class JiraView extends StatefulWidget {
  const new(this.daemon, {super.key, this.now});

  final Daemon daemon;

  /// The time ages are counted from (tests); now when null.
  final DateTime? now;

  @override
  State<JiraView> createState() => _JiraViewState();
}

class _JiraViewState extends State<JiraView> {
  List<JiraSite>? _sites;
  List<Task> _tasks = const [];
  String _sprint = '';
  String? _error;
  bool _loading = false;
  int _asked = 0;
  Timer? _poll;

  /// Which list [_tasks] are ([_listKey]), and when Jira said so if they
  /// are what the daemon kept from last time (shown while it's asked).
  String? _shown;
  DateTime? _cachedAt;

  /// A load has gone on a while (150 ms) with nothing to show: the
  /// skeleton shows.
  bool _slow = false;
  Timer? _slowTimer;
  final _listFocus = FocusNode(debugLabel: 'jira list');
  final _viewFocus = FocusNode(debugLabel: 'jira view');
  final _jqlFocus = FocusNode(debugLabel: 'jql');
  final _jqlText = TextEditingController(text: _jql);
  final _scroll = ScrollController();

  /// The selected row's Start work menu, for ⌘⏎.
  OpenMenu? _start;

  JiraSite? get _siteNow {
    final sites = _sites ?? const <JiraSite>[];
    return sites.where((s) => s.id == _site).firstOrNull ?? sites.firstOrNull;
  }

  /// Every site's issues show: only my open ones, the one list they share.
  bool get _every => _all && (_sites?.length ?? 0) > 1;

  /// Where the list's groups are remembered: the site, or `*` for all.
  String get _place => _every ? '*' : _siteNow?.id ?? '';

  /// The rows the keys move through (not in collapsed groups).
  List<Task> get _visible => visibleTasks(_tasks, _place);

  @override
  void initState() {
    super.initState();
    unawaited(_loadSites());
    _poll = Timer.periodic(jiraPoll, (_) => unawaited(_load(quiet: true)));
    jiraCollapsed.addListener(_keepVisible);
  }

  /// A group collapsed over the selected row: the selection moves to the
  /// next row shown (or the last).
  void _keepVisible() {
    final visible = _visible;
    if (!mounted || visible.any((x) => x.issue.key == _key)) return;
    final all = grouped(_tasks, _place);
    final at = all.indexWhere((x) => x.issue.key == _key);
    setState(() {
      _start = null;
      _key =
          all.skip(at + 1).where(visible.contains).firstOrNull?.issue.key ??
          visible.lastOrNull?.issue.key;
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _slowTimer?.cancel();
    jiraCollapsed.removeListener(_keepVisible);
    _listFocus.dispose();
    _viewFocus.dispose();
    _jqlFocus.dispose();
    _jqlText.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      final r = await widget.daemon.client.listJiraSites(
        ListJiraSitesRequest(),
      );
      if (!mounted) return;
      setState(() => _sites = r.sites);
      _site = _siteNow?.id;
      await _load();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _sites = const [];
          _error = jiraError(e);
        });
      }
    }
  }

  /// Asks for the list again; [quiet] keeps what shows until it answers
  /// (the poll), and an error then leaves the list as it was. Another
  /// list than the one shown shows what the daemon kept of it meanwhile.
  Future<void> _load({bool quiet = false}) async {
    final site = _siteNow;
    if (int.tryParse(_list) case final i?
        when i >= (site?.searches.length ?? 0)) {
      _list = 'mine'; // a search removed, or another site's
    }
    if (_every) _list = 'mine';
    // Nothing to ask yet: the line above the list says what to do.
    if (site == null ||
        _list == 'jql' && _jql.isEmpty ||
        _list == 'sprint' && site.board == 0) {
      setState(() {
        _tasks = const [];
        _error = null;
        _shown = _cachedAt = null;
      });
      return;
    }
    final n = ++_asked;
    ListJiraIssuesRequest ask(String id) {
      final req = ListJiraIssuesRequest(site: id);
      switch (_list) {
        case 'mine' || 'sprint':
          req.list = _list;
        case 'jql':
          req.jql = _jql;
        default:
          req.jql = site.searches[int.parse(_list)].jql;
      }
      return req;
    }

    final on = _every ? [for (final s in _sites!) s.id] : [site.id];
    final key = _listKey(on, ask(on.first));
    if (!quiet) {
      setState(() {
        _loading = true;
        _slow = false;
      });
      _slowTimer?.cancel();
      _slowTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted && n == _asked && _loading) setState(() => _slow = true);
      });
      if (_shown != key) unawaited(_showKept(n, key, on, ask));
    }
    try {
      final got = await Future.wait([
        for (final id in on) widget.daemon.client.listJiraIssues(ask(id)),
      ]);
      if (n != _asked || !mounted) return;
      setState(() {
        _show(key, on, got);
        _cachedAt = null;
        _error = null;
      });
    } on Object catch (e) {
      if (n == _asked && mounted && !quiet) {
        setState(() {
          if (_shown != key) {
            _tasks = const [];
            _shown = _cachedAt = null;
          }
          _error = jiraError(e);
        });
      }
    } finally {
      if (n == _asked && mounted) setState(() => _loading = false);
    }
  }

  /// A list's key: its sites and what is asked of them.
  static String _listKey(List<String> on, ListJiraIssuesRequest req) =>
      '${on.join(' ')}\n${req.list}\n${req.jql}';

  /// Shows what the daemon kept of the list asked for, until Jira answers.
  Future<void> _showKept(
    int n,
    String key,
    List<String> on,
    ListJiraIssuesRequest Function(String) ask,
  ) async {
    try {
      final got = await Future.wait([
        for (final id in on)
          widget.daemon.client.listJiraIssues(ask(id)..cached = true),
      ]);
      final at = [
        for (final r in got)
          if (r.atMs > 0) r.atMs.toInt(),
      ];
      // Jira answered first, or nothing was kept.
      if (n != _asked || !mounted || !_loading || at.isEmpty) return;
      setState(() {
        _show(key, on, got);
        _cachedAt = DateTime.fromMillisecondsSinceEpoch(at.reduce(min));
      });
    } on Object {
      // Nothing kept: Jira's answer decides.
    }
  }

  void _show(String key, List<String> on, List<ListJiraIssuesResponse> got) {
    _shown = key;
    _tasks = ordered([
      for (final (i, r) in got.indexed)
        for (final is_ in r.issues) (site: on[i], issue: is_),
    ]);
    _sprint = got.first.sprint;
    if (!_tasks.any((t) => t.issue.key == _key)) {
      _key = _visible.firstOrNull?.issue.key;
      _details = false;
    }
  }

  void _pickList(String list) {
    setState(() => _list = list);
    unawaited(_load());
    if (list == 'jql') _jqlFocus.requestFocus();
  }

  void _move(int by) {
    final visible = _visible;
    if (visible.isEmpty) return;
    final i = visible.indexWhere((x) => x.issue.key == _key);
    final next = (i + by).clamp(0, visible.length - 1);
    setState(() => _key = visible[next].issue.key);
  }

  void _open(Task task) {
    setState(() {
      _key = task.issue.key;
      _details = true;
    });
    _viewFocus.requestFocus(); // the list, which had it, goes
  }

  void _back() {
    setState(() => _details = false);
    // Once the list is back.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listFocus.requestFocus(),
    );
  }

  Future<void> _pickBoard(JiraSite site) async {
    final r = await widget.daemon.client.listJiraBoards(
      ListJiraBoardsRequest(site: site.id),
    );
    if (!mounted) return;
    final board = await pickBoard(context, r.boards);
    if (board == null) return;
    await widget.daemon.client.setJiraBoard(
      SetJiraBoardRequest(site: site.id, board: board),
    );
    await _loadSites();
  }

  Future<void> _saveSearch(JiraSite site) async {
    final n = await askName(context);
    if (n == null || n.isEmpty) return;
    await _setSearches(site, [
      ...site.searches,
      JiraSearch(name: n, jql: _jql),
    ]);
    _pickList('${site.searches.length}');
  }

  Future<void> _setSearches(JiraSite site, List<JiraSearch> searches) =>
      tryOrShow(context, () async {
        await widget.daemon.client.setJiraSearches(
          SetJiraSearchesRequest(site: site.id, searches: searches),
        );
        await _loadSites();
      });

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final at = _visible.where((x) => x.issue.key == _key).firstOrNull;
    if (k == LogicalKeyboardKey.enter && at != null) {
      meta ? _start?.call() : _open(at);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyJ && !meta) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyK && !meta) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.slash) {
      _pickList('jql');
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final sites = _sites;
    final site = _siteNow;
    // The site of the issue whose details show.
    final shown = _tasks
        .where((x) => x.issue.key == _key)
        .map((x) => x.site)
        .firstWhere((_) => true, orElse: () => site?.id ?? '');
    final lists = [
      'mine',
      if (!_every) 'sprint',
      if (!_every) ...[
        for (var i = 0; i < (site?.searches.length ?? 0); i++) '$i',
        'jql',
      ],
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _load,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _details ? _back() : widget.daemon.showJira(open: false),
        // ⌥⌘: ⌘1–9 switch chats.
        for (var i = 0; i < lists.length && i < 9; i++)
          SingleActivator(
            LogicalKeyboardKey(0x31 + i),
            meta: true,
            alt: true,
          ): () =>
              _pickList(lists[i]),
      },
      child: Focus(
        focusNode: _viewFocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JiraBar(
              sites: sites ?? const [],
              site: _every ? null : site,
              loading: _loading,
              updated: _cachedAt,
              now: widget.now,
              onSite: (id) {
                setState(() {
                  _all = id == null;
                  if (id != null) _site = id;
                });
                unawaited(_load());
              },
              onRefresh: _load,
              onClose: () => widget.daemon.showJira(open: false),
            ),
            Expanded(
              child: sites == null
                  ? const SizedBox()
                  : site == null
                  ? NoSite(widget.daemon)
                  : _details && _key != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                          child: Row(
                            children: [
                              IconTap(
                                Icons.arrow_back,
                                tooltip: 'The list (Esc)',
                                onTap: _back,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: JiraIssuePane(
                            key: ValueKey('$shown $_key'),
                            daemon: widget.daemon,
                            site: shown,
                            issueKey: _key!,
                            onOpen: (key) => setState(() => _key = key),
                            now: widget.now,
                          ),
                        ),
                      ],
                    )
                  : _lists(theme, site, lists),
            ),
          ],
        ),
      ),
    );
  }

  String _sprintLine() =>
      _sprint.isEmpty && !_loading ? 'no active sprint' : _sprint;

  Widget _lists(NushiTheme theme, JiraSite site, List<String> lists) {
    final t = theme.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (site.needsOk)
          NeedsOk(
            onAllow: () => tryOrShow(context, () async {
              await widget.daemon.client.allowJiraToken(
                AllowJiraTokenRequest(site: site.id),
              );
              await _loadSites();
            }),
          ),
        if (site.needsRestart)
          Notice(
            '${site.problem}. Restarting stops running turns and closes '
            'terminals.',
            action: bundledDaemon == null ? null : 'Restart daemon',
            onAction: () => tryOrShow(context, () async {
              await widget.daemon.restartDaemon();
              if (mounted) await _loadSites();
            }),
          ),
        JiraSources(
          daemon: widget.daemon,
          site: site,
          lists: lists,
          list: _list,
          sprint: _sprintLine(),
          jql: _jql,
          jqlText: _jqlText,
          jqlFocus: _jqlFocus,
          onPick: _pickList,
          onPickBoard: () => _pickBoard(site),
          onRemoveSearch: (i) => _setSearches(site, [
            ...site.searches.take(i),
            ...site.searches.skip(i + 1),
          ]),
          onRunJql: (jql) {
            _jql = jql;
            unawaited(_load());
            _listFocus.requestFocus();
          },
          onSave: () => _saveSearch(site),
        ),
        // The banner above says why, and what to do.
        if (_error case final e? when !site.needsOk && !site.needsRestart)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: _tasks.isEmpty && _loading && _slow
                ? const RowsLoading()
                : TaskList(
                    daemon: widget.daemon,
                    tasks: _tasks,
                    place: _place,
                    selected: _key,
                    sites: _every,
                    onOpen: (task) {
                      _listFocus.requestFocus();
                      _open(task);
                    },
                    onMoved: _load,
                    startMenu: (open) => _start = open,
                  ),
          ),
        ),
        if (_tasks.isEmpty && _error == null && !_loading)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _list == 'jql' && _jql.isEmpty
                  ? 'Type JQL, then Enter'
                  : 'Nothing here',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
      ],
    );
  }
}
