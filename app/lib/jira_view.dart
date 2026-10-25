import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// again, ⌘1–9 a list, / the JQL, Esc back to the list, then closes.
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadSites());
    _poll = Timer.periodic(jiraPoll, (_) => unawaited(_load(quiet: true)));
  }

  @override
  void dispose() {
    _poll?.cancel();
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
  /// (the poll), and an error then leaves the list as it was.
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
      });
      return;
    }
    final n = ++_asked;
    if (!quiet) setState(() => _loading = true);
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

    try {
      final on = _every ? [for (final s in _sites!) s.id] : [site.id];
      final got = await Future.wait([
        for (final id in on) widget.daemon.client.listJiraIssues(ask(id)),
      ]);
      if (n != _asked || !mounted) return;
      setState(() {
        _tasks = ordered([
          for (final (i, r) in got.indexed)
            for (final is_ in r.issues) (site: on[i], issue: is_),
        ]);
        _sprint = got.first.sprint;
        _error = null;
        if (!_tasks.any((t) => t.issue.key == _key)) {
          _key = _tasks.firstOrNull?.issue.key;
          _details = false;
        }
      });
    } on Object catch (e) {
      if (n == _asked && mounted && !quiet) {
        setState(() {
          _tasks = const [];
          _error = jiraError(e);
        });
      }
    } finally {
      if (n == _asked && mounted) setState(() => _loading = false);
    }
  }

  int get _at => max(0, _tasks.indexWhere((x) => x.issue.key == _key));

  void _pickList(String list) {
    setState(() => _list = list);
    unawaited(_load());
    if (list == 'jql') _jqlFocus.requestFocus();
  }

  void _move(int by) {
    if (_tasks.isEmpty) return;
    final i = _tasks.indexWhere((x) => x.issue.key == _key);
    final next = (i + by).clamp(0, _tasks.length - 1);
    setState(() => _key = _tasks[next].issue.key);
  }

  void _open(int i) {
    setState(() {
      _key = _tasks[i].issue.key;
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
    if (k == LogicalKeyboardKey.enter && _tasks.isNotEmpty) {
      meta ? _start?.call() : _open(_at);
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
        for (var i = 0; i < lists.length && i < 9; i++)
          SingleActivator(LogicalKeyboardKey(0x31 + i), meta: true): () =>
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
        if (_error case final e?)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(e, style: theme.ui(t.crashed, size: 12)),
          ),
        Expanded(
          child: Focus(
            focusNode: _listFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: TaskList(
              daemon: widget.daemon,
              tasks: _tasks,
              selected: _tasks.indexWhere((x) => x.issue.key == _key),
              sites: _every,
              onOpen: (i) {
                _listFocus.requestFocus();
                _open(i);
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
