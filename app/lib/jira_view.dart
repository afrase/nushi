import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_issue.dart';
import 'package:nushi/jira_jql.dart';
import 'package:nushi/jira_settings.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// ⌘J shows Jira in place of the chat, and back.
const jiraKey = SingleActivator(LogicalKeyboardKey.keyJ, meta: true);

/// How often the open list is asked for again while the view shows.
const jiraPoll = Duration(minutes: 1);

/// What the view had last (while the app runs): the site, the list, the
/// JQL typed, and the issue picked.
String? _site;
String _list = 'mine';
String _jql = '';
String? _key;

/// Shows [key], an issue of [site], in the Jira view.
void showIssue(Daemon daemon, String site, String key) {
  _site = site;
  _key = key;
  daemon.showJira(open: true);
}

/// A list's tab: "mine", "sprint", "jql", or a saved search's index.
String _label(String list, JiraSite site) => switch (list) {
  'mine' => 'Mine',
  'sprint' => 'Sprint',
  'jql' => 'JQL',
  _ => site.searches[int.parse(list)].name,
};

/// Jira in the app: a site's lists (my open issues, the active sprint of
/// a board, saved searches, JQL) on the left, the issue picked on the
/// right. It takes the chat's place, as the MCP view does; the sidebar of
/// chats stays. Keys: ↑↓ (or j k) pick, ⌘R asks again, ⌘1–9 a list, /
/// the JQL, Esc closes.
class JiraView extends StatefulWidget {
  const new(this.daemon, {super.key});

  final Daemon daemon;

  @override
  State<JiraView> createState() => _JiraViewState();
}

class _JiraViewState extends State<JiraView> {
  List<JiraSite>? _sites;
  List<JiraIssue> _issues = const [];
  String _sprint = '';
  String? _error;
  bool _loading = false;
  int _asked = 0;
  Timer? _poll;
  final _listFocus = FocusNode(debugLabel: 'jira list');
  final _jqlFocus = FocusNode(debugLabel: 'jql');
  final _jqlText = TextEditingController(text: _jql);
  final _scroll = ScrollController();

  JiraSite? get _siteNow {
    final sites = _sites ?? const <JiraSite>[];
    return sites.where((s) => s.id == _site).firstOrNull ?? sites.firstOrNull;
  }

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
    if (site == null || _list == 'jql' && _jql.isEmpty) {
      setState(() {
        _issues = const [];
        _error = null;
      });
      return;
    }
    final n = ++_asked;
    if (!quiet) setState(() => _loading = true);
    final req = ListJiraIssuesRequest(site: site.id);
    switch (_list) {
      case 'mine' || 'sprint':
        req.list = _list;
      case 'jql':
        req.jql = _jql;
      default:
        req.jql = site.searches[int.parse(_list)].jql;
    }
    try {
      final r = await widget.daemon.client.listJiraIssues(req);
      if (n != _asked || !mounted) return;
      setState(() {
        _issues = r.issues;
        _sprint = r.sprint;
        _error = null;
        _key ??= _issues.firstOrNull?.key;
      });
    } on Object catch (e) {
      if (n == _asked && mounted && !quiet) {
        setState(() {
          _issues = const [];
          _error = jiraError(e);
        });
      }
    } finally {
      if (n == _asked && mounted) setState(() => _loading = false);
    }
  }

  void _pickList(String list) {
    setState(() => _list = list);
    unawaited(_load());
    if (list == 'jql') _jqlFocus.requestFocus();
  }

  void _move(int by) {
    if (_issues.isEmpty) return;
    final i = _issues.indexWhere((x) => x.key == _key);
    final next = (i + by).clamp(0, _issues.length - 1);
    setState(() => _key = _issues[next].key);
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
    if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyJ && !meta) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.keyK && !meta) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.slash) {
      _pickList('jql');
    } else if (k == LogicalKeyboardKey.escape) {
      widget.daemon.showJira(open: false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final sites = _sites;
    final site = _siteNow;
    final lists = [
      'mine',
      'sprint',
      for (var i = 0; i < (site?.searches.length ?? 0); i++) '$i',
      'jql',
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _load,
        for (var i = 0; i < lists.length && i < 9; i++)
          SingleActivator(LogicalKeyboardKey(0x31 + i), meta: true): () =>
              _pickList(lists[i]),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JiraBar(
            sites: sites ?? const [],
            site: site,
            loading: _loading,
            onSite: (id) {
              setState(() => _site = id);
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
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 380, child: _lists(theme, site, lists)),
                      VerticalDivider(width: 1, color: t.borderSubtle),
                      Expanded(
                        child: _key == null
                            ? Center(
                                child: Text(
                                  _error == null ? 'No issue picked' : '',
                                  style: theme.ui(t.textMuted),
                                ),
                              )
                            : JiraIssuePane(
                                key: ValueKey('${site.id} $_key'),
                                daemon: widget.daemon,
                                site: site.id,
                                issueKey: _key!,
                                onOpen: (key) => setState(() => _key = key),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
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
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final l in lists)
                Menu(
                  entries: [
                    if (l == 'sprint')
                      MenuEntry(
                        'Pick the board…',
                        onPick: () => _pickBoard(site),
                      ),
                    if (int.tryParse(l) case final i?)
                      MenuEntry(
                        'Remove the search',
                        onPick: () => _setSearches(site, [
                          ...site.searches.take(i),
                          ...site.searches.skip(i + 1),
                        ]),
                      ),
                  ],
                  builder: (context, open) => GestureDetector(
                    onSecondaryTapUp: (d) => open(d.localPosition),
                    child: Tap(
                      selected: l == _list,
                      onTap: () => _pickList(l),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        _label(l, site),
                        style: theme.ui(
                          l == _list ? t.text : t.textSecondary,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_list == 'sprint')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 10, 4),
            child: site.board == 0
                ? Tap(
                    onTap: () => _pickBoard(site),
                    child: Text(
                      'Pick the board',
                      style: theme.ui(t.link, size: 12),
                    ),
                  )
                : Text(
                    '${site.boardName} · ${_sprintLine()}',
                    style: theme.ui(t.textMuted, size: 12),
                  ),
          ),
        if (_list == 'jql')
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JqlField(
                  client: widget.daemon.client,
                  site: site.id,
                  controller: _jqlText,
                  focusNode: _jqlFocus,
                  onRun: (jql) {
                    _jql = jql;
                    unawaited(_load());
                    _listFocus.requestFocus();
                  },
                ),
                if (_jql.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Button(
                      label: 'Save…',
                      kind: ButtonKind.ghost,
                      onPressed: () => _saveSearch(site),
                    ),
                  ),
              ],
            ),
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
            child: ListView.builder(
              controller: _scroll,
              itemCount: _issues.length,
              itemBuilder: (context, i) => IssueRow(
                _issues[i],
                selected: _issues[i].key == _key,
                onTap: () {
                  _listFocus.requestFocus();
                  setState(() => _key = _issues[i].key);
                },
              ),
            ),
          ),
        ),
        if (_issues.isEmpty && _error == null && !_loading)
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
