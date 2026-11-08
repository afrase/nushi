import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/back_swipe.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_people.dart';
import 'package:nushi/jira_sources.dart';
import 'package:nushi/jira_tasks.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/keys.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/token_notices.dart';
import 'package:nushi/widgets.dart';

/// ⌘J shows Jira in place of the chat, and back.
const jiraKey = Cmd(LogicalKeyboardKey.keyJ);

/// How often the open list is asked for again while the view shows.
const jiraPoll = Duration(minutes: 1);

/// What the view had last: the site (the one used last, kept), and while
/// the app runs every site's issues instead ([_all]), the list, the JQL
/// typed, the row picked and the issue whose details show (each with its
/// site): kept whatever the list holds, so an issue opened from a chat, a
/// subtask or one moved to Done stays open as the list is asked again.
String? get _site => lastJiraSite.value;
set _site(String? site) => lastJiraSite.value = site;
bool _all = false;
JiraList _list = const MyIssues();
String _jql = '';
IssueId? _picked;
IssueId? _details;

/// Forgets what the view had (tests start afresh).
@visibleForTesting
void forgetJiraView() {
  _all = false;
  _list = const MyIssues();
  _jql = '';
  _picked = null;
  _details = null;
}

/// Shows [key], an issue of [site], in the Jira view: its details.
void showIssue(Daemon daemon, String site, String key) {
  _site = site;
  _all = false;
  _details = _picked = (site: site, key: key);
  daemon.go(const JiraPlace());
}

/// Jira in the app, in the chat's place as the MCP view is (the sidebar of
/// chats stays): a task list, as Orca's task drawer (TaskList), of my
/// open issues (on a site, or every site), the active sprint of a board,
/// a saved search or JQL; a row's details (JiraIssuePane) in the list's
/// place. Keys: ↑↓ (or j k) pick, ⏎ the details, ⌘⏎ Start work, ⌘R asks
/// again, ⌥⌘1–9 a list, / the JQL, Esc back to the list, then closes.
class JiraView extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

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

  /// The selected row's, to keep it in view.
  final GlobalKey _selectedRow = GlobalKey(debugLabel: 'jira selected');

  /// The selected row's Start work menu, for ⌘⏎, and whose it is: the
  /// row registers it as it's built, and a row not built (scrolled away)
  /// can't, so it may be another's.
  (IssueId, OpenMenu)? _start;

  JiraSite? get _siteNow {
    final sites = _sites ?? const <JiraSite>[];
    return sites.where((s) => s.id == _site).firstOrNull ?? sites.firstOrNull;
  }

  /// Every site's issues show: only my open ones, the one list they share.
  bool get _every => _all && (_sites?.length ?? 0) > 1;

  /// Where the list's groups are remembered: the site, or `*` for all.
  String get _place => _every ? '*' : _siteNow?.id ?? '';

  /// Whose issues show: everyone's in Mine and every site's list, else as
  /// picked for the site and list.
  Assignee get _assignee => switch (_siteNow) {
    final site? when _list is! MyIssues && !_every => assigneeAt(
      filterPlace(site, _list),
    ),
    _ => const .everyone(),
  };

  /// The rows the filter leaves.
  List<Task> get _filtered {
    final (who, site) = (_assignee, _siteNow);
    return who.everyone || site == null
        ? _tasks
        : [
            for (final x in _tasks)
              if (who.shows(x.issue, site)) x,
          ];
  }

  /// The rows the keys move through (not in collapsed groups).
  List<Task> get _visible => visibleTasks(_filtered, _place);

  @override
  void initState() {
    super.initState();
    unawaited(_loadSites());
    _poll = Timer.periodic(jiraPoll, (_) => unawaited(_load(quiet: true)));
    _underSettings = widget.daemon.settingsOpen != null;
    widget.daemon.addListener(_settingsShut);
    jiraCollapsed.addListener(_keepVisible);
    jiraAssignee.addListener(_keepVisible);
  }

  /// A group collapsed over the selected row: the selection moves to the
  /// next row shown (or the last).
  void _keepVisible() {
    final visible = _visible;
    if (!mounted || visible.any((x) => idOf(x) == _picked)) return;
    final all = grouped(_tasks, _place);
    final at = all.indexWhere((x) => idOf(x) == _picked);
    // A row the filter hid: the first shown.
    if (!_filtered.any((x) => idOf(x) == _picked)) {
      setState(() => _picked = visible.map(idOf).firstOrNull);
      return;
    }
    setState(() {
      _picked =
          all.skip(at + 1).where(visible.contains).map(idOf).firstOrNull ??
          visible.map(idOf).lastOrNull;
    });
  }

  // Settings opens over the view (ADR 0087), where a site can be added or
  // its token allowed: the sites are read again when it shuts.
  bool _underSettings = false;

  void _settingsShut() {
    final under = widget.daemon.settingsOpen != null;
    if (_underSettings && !under && mounted) unawaited(_loadSites());
    _underSettings = under;
  }

  @override
  void dispose() {
    widget.daemon.removeListener(_settingsShut);
    _sitesAgain.cancel();
    _poll?.cancel();
    _slowTimer?.cancel();
    jiraCollapsed.removeListener(_keepVisible);
    jiraAssignee.removeListener(_keepVisible);
    _listFocus.dispose();
    _viewFocus.dispose();
    _jqlFocus.dispose();
    _jqlText.dispose();
    super.dispose();
  }

  // The sites asked for while the daemon was gone: without them the view
  // would say there are none.
  late final _sitesAgain = LoadAgain(widget.daemon, () {
    if (mounted) unawaited(_loadSites());
  });

  Future<void> _loadSites() async {
    _sitesAgain.cancel();
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
          _error = errorText(e);
        });
        _sitesAgain.failed(e);
      }
    }
  }

  /// Asks for the list again; [quiet] keeps what shows until it answers
  /// (the poll), and an error then leaves the list as it was. Another
  /// list than the one shown shows what the daemon kept of it meanwhile.
  Future<void> _load({bool quiet = false}) async {
    final site = _siteNow;
    if (_list case final Saved s when site == null || !s.on(site)) {
      _list = const MyIssues(); // a search removed, or another site's
    }
    if (_every) _list = const MyIssues();
    // Nothing to ask yet: the line above the list says what to do.
    if (site == null ||
        _list is Jql && _jql.isEmpty ||
        _list is Sprint && site.board == 0) {
      _asked++; // a list still asked for is no longer wanted
      setState(() {
        _tasks = const [];
        _error = null;
        _shown = _cachedAt = null;
        _loading = _slow = false;
      });
      return;
    }
    final n = ++_asked;
    ListJiraIssuesRequest ask(String id) => switch (_list) {
      MyIssues() => ListJiraIssuesRequest(site: id, list: 'mine'),
      Sprint() => ListJiraIssuesRequest(site: id, list: 'sprint'),
      Jql() => ListJiraIssuesRequest(site: id, jql: _jql),
      Saved(:final jql) => ListJiraIssuesRequest(site: id, jql: jql),
    };

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
          _error = errorText(e);
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
    // The details stay as they are: the list moves only the row picked.
    if (!_visible.any((t) => idOf(t) == _picked)) {
      _picked = _visible.map(idOf).firstOrNull;
    }
  }

  void _pickList(JiraList list) {
    setState(() {
      _list = list;
      _details = null; // a list asked for shows
    });
    unawaited(_load());
    if (list is Jql) _jqlFocus.requestFocus();
  }

  void _move(int by) {
    final visible = _visible;
    if (visible.isEmpty) return;
    final i = visible.indexWhere((x) => idOf(x) == _picked);
    final next = (i + by).clamp(0, visible.length - 1);
    setState(() => _picked = idOf(visible[next]));
    revealRow(_selectedRow, down: by > 0);
  }

  /// ⌘⏎: the selected row's Start work, once it's in view (its menu opens
  /// by it).
  void _startWork() => revealRow(
    _selectedRow,
    down: true,
    then: () {
      if (_start case (final id, final open)
          when id == _picked && _selectedRow.currentContext != null) {
        open();
      }
    },
  );

  void _open(Task task) {
    setState(() => _details = _picked = idOf(task));
    _viewFocus.requestFocus(); // the list, which had it, goes
  }

  void _back() {
    setState(() {
      // The issue last shown is picked, when the list has it.
      if (_details case final shown?
          when _visible.any((t) => idOf(t) == shown)) {
        _picked = shown;
      }
      _details = null;
    });
    // Once the list is back, where it was scrolled (CardList.keepScrollAs),
    // the picked row in view.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listFocus.requestFocus(),
    );
    revealRow(
      _selectedRow,
      down: true,
      then: () => revealRow(_selectedRow, down: false),
    );
  }

  Future<void> _pickBoard(JiraSite site) => tryOrShow(context, () async {
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
  });

  Future<void> _saveSearch(JiraSite site) async {
    final n = await askName(context);
    if (n == null || n.isEmpty) return;
    final search = JiraSearch(name: n, jql: _jql);
    final searches = [...site.searches, search];
    if (!mounted) {
      // The view went while the name was asked (a chat picked from the
      // menu bar): saved all the same, with nowhere to say it failed.
      await widget.daemon.client
          .setJiraSearches(
            SetJiraSearchesRequest(site: site.id, searches: searches),
          )
          .then<void>((_) {}, onError: (Object _) {});
      return;
    }
    await _setSearches(site, searches);
    if (mounted) _pickList(Saved(search));
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
    final meta = cmdPressed();
    final at = _visible.where((x) => idOf(x) == _picked).firstOrNull;
    if (k == LogicalKeyboardKey.enter && at != null) {
      meta ? _startWork() : _open(at);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyJ && !meta) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyK && !meta) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.slash) {
      _pickList(const Jql());
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
    final details = _details;
    final lists = <JiraList>[
      const MyIssues(),
      if (!_every) ...[
        const Sprint(),
        for (final s in site?.searches ?? const <JiraSearch>[]) Saved(s),
        const Jql(),
      ],
    ];
    return CallbackShortcuts(
      bindings: {
        const Cmd(LogicalKeyboardKey.keyR): _load,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            details != null ? _back() : widget.daemon.back(),
        // ⌥⌘ (Alt on Linux): ⌘1–9 switch chats.
        for (var i = 0; i < lists.length && i < 9; i++)
          altDigitKey(i + 1): () => _pickList(lists[i]),
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
              onSite: (id) {
                setState(() {
                  _all = id == null;
                  if (id != null) _site = id;
                  _details = null; // its list shows
                });
                unawaited(_load());
              },
              onRefresh: _load,
              onClose: widget.daemon.back,
            ),
            Expanded(
              child: sites == null
                  ? const SizedBox()
                  : site == null
                  // With an error, listing the sites failed.
                  ? NoSite(widget.daemon, error: _error, onRetry: _loadSites)
                  : details != null
                  ? BackSwipe(
                      onBack: _back,
                      child: Column(
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
                              key: ValueKey('${details.site} ${details.key}'),
                              daemon: widget.daemon,
                              site: details.site,
                              issueKey: details.key,
                              // A subtask or link: of the same site.
                              onOpen: (key) => setState(
                                () => _details = (site: details.site, key: key),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _lists(NushiTheme theme, JiraSite site, List<JiraList> lists) {
    final t = theme.t;
    final who = _assignee;
    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TokenNotices(
          needsOk: site.needsOk,
          needsRestart: site.needsRestart,
          problem: site.problem,
          onAllow: () => tryOrShow(context, () async {
            await widget.daemon.client.allowJiraToken(
              AllowJiraTokenRequest(site: site.id),
            );
            await _loadSites();
          }),
          onRestart: () => tryOrShow(context, () async {
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
          onRemoveSearch: (gone) {
            final i = site.searches.indexWhere((s) => Saved(s) == gone);
            unawaited(_setSearches(site, [...site.searches]..removeAt(i)));
          },
          onRunJql: (jql) {
            _jql = jql;
            unawaited(_load());
            _listFocus.requestFocus();
          },
          onSave: () => _saveSearch(site),
          filter: _list is MyIssues || _every || _tasks.isEmpty && who.everyone
              ? null
              : AssigneeMenu(
                  site: site,
                  issues: [for (final x in _tasks) x.issue],
                  value: who,
                  onPick: (a) {
                    setAssignee(filterPlace(site, _list), a);
                    setState(() {}); // the rows it leaves
                  },
                ),
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
                    tasks: rows,
                    place: _place,
                    selected: _picked,
                    sites: _every,
                    people: _list is! MyIssues,
                    onOpen: (task) {
                      _listFocus.requestFocus();
                      _open(task);
                    },
                    onMoved: _load,
                    selectedRow: _selectedRow,
                    startMenu: (id, open) => _start = (id, open),
                  ),
          ),
        ),
        if (rows.isEmpty && _error == null && !_loading)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              _list is Jql && _jql.isEmpty
                  ? 'Type JQL, then Enter'
                  : _tasks.isEmpty
                  ? 'Nothing here'
                  : 'Nothing here for ${who.label}',
              style: theme.ui(t.textMuted, size: 12),
            ),
          ),
      ],
    );
  }
}
