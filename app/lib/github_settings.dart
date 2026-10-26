import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/gen/nushi/v1/nushi.connect.client.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a failed GitHub call says: the daemon's message.
String githubError(Object e) => e is ConnectException ? e.message : '$e';

/// Where GitHub makes tokens.
final Uri githubTokensPage = Uri.parse('https://github.com/settings/tokens');

/// Where a token comes from, as Settings says it.
String tokenSource(GitHubHost h) => switch (h.source) {
  'gh' => "gh's login",
  'token' => 'a pasted token',
  final s => s, // GH_TOKEN and the like, from the environment
};

/// A token's kind, as Settings says it.
String tokenKind(String kind) => switch (kind) {
  'oauth' => 'OAuth token',
  'classic' => 'classic token',
  'fine-grained' => 'fine-grained token: no Checks, one owner',
  'app' => "a GitHub App's token",
  _ => '',
};

/// What's left of a host's rate limits: REST, GraphQL and search.
String budgetLine(GitHubHost h, DateTime now) {
  String one(String name, String label) {
    final b = h.budget.where((b) => b.name == name).firstOrNull;
    if (b == null || b.limit == 0) return '';
    return '$label ${b.remaining} of ${b.limit}';
  }

  final parts = [
    one('core', 'REST'),
    one('graphql', 'GraphQL'),
    one('search', 'search'),
  ].where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final reset = h.budget
      .where((b) => b.name == 'graphql')
      .map((b) => DateTime.fromMillisecondsSinceEpoch(b.resetMs.toInt()))
      .firstOrNull;
  final mins = reset?.difference(now).inMinutes;
  return 'Left this hour: ${parts.join(' · ')}'
      '${mins != null && mins >= 0 ? ' (GraphQL resets in ${mins}m)' : ''}';
}

/// Settings › GitHub: each host gh is signed in to or given a token, who
/// its token is (gh's login, or a pasted one, in the keychain), and what's
/// left of its rate limits (shared with gh in a terminal and agents that
/// run gh); Add a token, for a host without gh, or instead of gh's.
class GitHubPage extends StatefulWidget {
  const new(this.client, {super.key, this.now});

  final NushiServiceClient client;

  /// The time resets are counted from (tests); now when null.
  final DateTime? now;

  @override
  State<GitHubPage> createState() => _GitHubPageState();
}

class _GitHubPageState extends State<GitHubPage> {
  List<GitHubHost>? _hosts;
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await widget.client.listGitHubHosts(ListGitHubHostsRequest());
      if (!mounted) return;
      setState(() {
        _hosts = r.hosts;
        _error = null;
        _adding = _adding || r.hosts.isEmpty;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _hosts = const [];
          _error = githubError(e);
        });
      }
    }
  }

  Future<void> _remove(GitHubHost h) async {
    if (!await confirm(
          context,
          'Remove the token for ${h.host}?',
          "Nushi deletes it from the keychain, and uses gh's login for "
              '${h.host} if gh has one.',
          'Remove',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    await tryOrShow(context, () async {
      await widget.client.removeGitHubToken(
        RemoveGitHubTokenRequest(host: h.host),
      );
      await _load();
    });
  }

  Future<void> _allow(GitHubHost h) => tryOrShow(context, () async {
    await widget.client.allowGitHubToken(AllowGitHubTokenRequest(host: h.host));
    await _load();
  });

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final hosts = _hosts;
    if (hosts == null) return const SizedBox(height: 40);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in hosts)
            _HostRow(
              h,
              now: widget.now ?? DateTime.now(),
              onAllow: () => _allow(h),
              onRemove: () => _remove(h),
            ),
          if (_error case final e?)
            Text(e, style: theme.ui(t.crashed, size: 12)),
          if (hosts.isEmpty && !_adding)
            Text(
              'No GitHub host. Sign in with gh auth login in a terminal, '
              'or add a token.',
              style: theme.ui(t.textMuted, size: 12),
            ),
          const SizedBox(height: 8),
          if (_adding)
            _AddToken(
              widget.client,
              onAdded: () {
                setState(() => _adding = false);
                unawaited(_load());
              },
              onCancel: hosts.isEmpty
                  ? null
                  : () => setState(() => _adding = false),
            )
          else
            Row(
              children: [
                Button(
                  label: 'Add a token',
                  icon: Icons.add,
                  onPressed: () => setState(() => _adding = true),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Nushi asks GitHub only while its view, a pull request or a '
            "chat's status shows, and writes only what you send.",
            style: theme.ui(t.textMuted, size: 11.5),
          ),
        ],
      ),
    );
  }
}

class _HostRow extends StatelessWidget {
  const new(
    this.host, {
    required this.now,
    required this.onAllow,
    required this.onRemove,
  });

  final GitHubHost host;
  final DateTime now;
  final VoidCallback onAllow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final h = host;
    final who = h.login.isEmpty
        ? null
        : 'Signed in as ${h.login}${h.name.isEmpty ? '' : ' (${h.name})'}';
    final status = h.needsOk
        ? 'This build of Nushi needs your OK to read the token: macOS asks '
              'for your password.'
        : h.problem.isNotEmpty
        ? h.problem
        : who ?? 'Checking…';
    final statusColor = h.needsOk
        ? t.needs
        : h.problem.isNotEmpty
        ? t.crashed
        : t.textSecondary;
    final kind = tokenKind(h.kind);
    final budget = budgetLine(h, now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.host, style: theme.ui(t.text, weight: FontWeight.w600)),
                Text(status, style: theme.ui(statusColor, size: 12)),
                if (h.source.isNotEmpty)
                  Text(
                    [
                      'From ${tokenSource(h)}',
                      if (kind.isNotEmpty) kind,
                      if (h.scopes.isNotEmpty) 'scopes ${h.scopes.join(', ')}',
                    ].join(' · '),
                    style: theme.ui(t.textMuted, size: 12),
                  ),
                if (budget.isNotEmpty)
                  Text(budget, style: theme.ui(t.textMuted, size: 12)),
              ],
            ),
          ),
          if (h.needsOk)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Button(label: 'Allow…', onPressed: onAllow),
            ),
          if (h.pasted)
            Button(
              label: 'Remove',
              kind: ButtonKind.destructive,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// The form for a token: the host (github.com, or an Enterprise server's)
/// and the token, checked with GitHub before it's kept.
class _AddToken extends StatefulWidget {
  const new(this.client, {required this.onAdded, required this.onCancel});

  final NushiServiceClient client;
  final VoidCallback onAdded;
  final VoidCallback? onCancel;

  @override
  State<_AddToken> createState() => _AddTokenState();
}

class _AddTokenState extends State<_AddToken> {
  final _host = TextEditingController(text: 'github.com');
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.addGitHubToken(
        AddGitHubTokenRequest(
          host: _host.text.trim(),
          token: _token.text.trim(),
        ),
      );
      _token.clear();
      widget.onAdded();
    } on Object catch (e) {
      if (mounted) setState(() => _error = githubError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final mono = theme.code(t.text, size: 12);
    Widget field(
      String label,
      TextEditingController c,
      String hint, {
      bool secret = false,
      bool autofocus = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: theme.ui(t.textSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: c,
              obscureText: secret,
              autofocus: autofocus,
              enabled: !_busy,
              style: mono,
              decoration: InputDecoration(hintText: hint, isDense: true),
              onSubmitted: (_) => _add(),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: box(t.borderSubtle, fill: t.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a GitHub token',
            style: theme.ui(t.text, weight: FontWeight.w600),
          ),
          Text(
            "Used for its host instead of gh's login, until removed. A "
            'classic token with repo and read:org covers what Nushi does.',
            style: theme.ui(t.textMuted, size: 12),
          ),
          field('Host', _host, 'github.com'),
          field(
            'Token',
            _token,
            'ghp_… or github_pat_…',
            secret: true,
            autofocus: true,
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(e, style: theme.ui(t.crashed, size: 12)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              LinkText(
                'Make a token',
                size: 12,
                onTap: () => unawaited(launchUrl(githubTokensPage)),
              ),
              const Spacer(),
              if (widget.onCancel case final cancel?)
                Button(label: 'Cancel', onPressed: _busy ? null : cancel),
              const SizedBox(width: 6),
              Button(
                label: _busy ? 'Checking…' : 'Add',
                kind: ButtonKind.primary,
                onPressed: _busy ? null : _add,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How long ago a GitHub time (ms) was, as lists say it.
String githubAgo(int ms, DateTime now) {
  final when = DateTime.fromMillisecondsSinceEpoch(ms);
  return ago(now.difference(when), when);
}
