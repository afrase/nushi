import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The first daemon that answers pull requests and issues by number
/// (GetGitHubItems, `Chat.pulls`; ADR 0117).
const githubItemsApi = 118;

/// A pull request's or an issue's address on GitHub, as a message links
/// it: `https://<host>/<owner>/<repo>/pull/<n>` or `/issues/<n>`, a
/// sub-path or a fragment after it allowed.
@immutable
class GitHubAddress {
  const new({
    required this.host,
    required this.repo,
    required this.number,
    required this.pull,
  });

  /// [ref]'s, a pull request or not.
  factory of(GitHubRef ref, {required bool pull}) => GitHubAddress(
    host: ref.host,
    repo: ref.repo,
    number: ref.number,
    pull: pull,
  );

  final String host;
  final String repo;
  final int number;
  final bool pull;

  /// `owner/repo#n`, as a chip shows it: from the address, so a title
  /// can't pose as another item.
  String get short => '$repo#$number';

  /// What the item is kept by: host, repository (any case) and number.
  String get key => '$host/${repo.toLowerCase()}#$number';

  /// The address on GitHub.
  String get url => 'https://$host/$repo/${pull ? 'pull' : 'issues'}/$number';

  GitHubRef get ref => GitHubRef(host: host, repo: repo, number: number);

  @override
  bool operator ==(Object other) => other is GitHubAddress && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

final _address = RegExp(
  r'^https://([a-z0-9.-]+(?::\d{1,5})?)/([A-Za-z0-9][A-Za-z0-9-]{0,38})/'
  r'([A-Za-z0-9._-]{1,100})/(pull|issues)/(\d{1,9})(?:[/?#][^\s]*)?$',
  caseSensitive: false,
);

/// [href] as a pull request's or an issue's address, or null.
GitHubAddress? githubAddress(String href) {
  final m = _address.firstMatch(href.trim());
  if (m == null) return null;
  final n = int.parse(m[5]!);
  final repo = m[3]!;
  if (n <= 0 || repo == '.' || repo == '..') return null;
  return GitHubAddress(
    host: m[1]!.toLowerCase(),
    repo: '${m[2]}/$repo',
    number: n,
    pull: m[4]!.toLowerCase() == 'pull',
  );
}

/// Whether a link's [text] is its address itself or names the same item
/// (`#n`, `owner/repo#n`, after "PR", "pull request" or "issue" or not):
/// such a link shows as a chip, one with words of its own stays words.
bool namesItem(String text, GitHubAddress a, String href) {
  final t = text.trim();
  if (t == href.trim() || githubAddress(t) == a) return true;
  final m = RegExp(
    r'^(?:(?:PR|pull request|issue)\s+)?([\w.-]+/[\w.-]+)?#(\d+)$',
    caseSensitive: false,
  ).firstMatch(t);
  if (m == null || int.parse(m[2]!) != a.number) return false;
  return m[1] == null || m[1]!.toLowerCase() == a.repo.toLowerCase();
}

/// What the app knows of one item: as GitHub said last ([at]), or that
/// GitHub doesn't show it to the account ([unseen]), or why it couldn't
/// be asked ([error], [signIn]).
@immutable
class GitHubLook {
  const new({
    this.item,
    this.unseen = false,
    this.at,
    this.error,
    this.signIn = false,
    this.asking = false,
  });

  final GitHubItem? item;
  final bool unseen;

  /// When GitHub last said; null before.
  final DateTime? at;
  final String? error;
  final bool signIn;
  final bool asking;

  GitHubLook copyWith({
    GitHubItem? item,
    bool? unseen,
    DateTime? at,
    String? error,
    bool clearError = false,
    bool? signIn,
    bool? asking,
  }) => GitHubLook(
    item: item ?? this.item,
    unseen: unseen ?? this.unseen,
    at: at ?? this.at,
    error: clearError ? null : error ?? this.error,
    signIn: signIn ?? this.signIn,
    asking: asking ?? this.asking,
  );
}

/// Pull requests and issues by number, for the app's session (never on
/// disk; ADR 0117): a chip asks once when first built (quiet), gathered
/// over 250 ms into one call a host; a hover asks again, not quiet, for
/// what's over a minute old; a chat's rows ask on their own clock. Never
/// polled here.
class GitHubItems extends ChangeNotifier {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= GitHubItems._(daemon);

  new _(this.daemon) {
    daemon.whenDisposed(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
  }

  static final _all = Expando<GitHubItems>();

  /// How long the gathering waits for more chips before it asks.
  // design: a batch of asks, not motion
  static const gather = Duration(milliseconds: 250);

  final Daemon daemon;
  final _looks = <String, GitHubLook>{};
  final _want = <String, Map<String, (GitHubAddress, bool quiet)>>{};
  final _timers = <String, Timer>{};

  /// The hosts Nushi gives a token to, as Settings › GitHub lists them;
  /// github.com until it answered.
  Set<String> _hosts = const {'github.com'};
  Future<void>? _listing;

  /// Whether [host] is one Nushi gives a token to: a link to another gets
  /// no chip and no request.
  bool knows(String host) {
    unawaited(_listHosts());
    return _hosts.contains(host);
  }

  Future<void> _listHosts() => _listing ??= () async {
    if (daemon.daemonApi < githubItemsApi) return;
    try {
      final r = await daemon.client.listGitHubHosts(ListGitHubHostsRequest());
      final hosts = {'github.com', for (final h in r.hosts) h.host};
      if (!setEquals(hosts, _hosts)) {
        _hosts = hosts;
        notifyListeners();
      }
    } on Object {
      _listing = null; // asked again by the next chip
    }
  }();

  /// What's known of [a].
  GitHubLook look(GitHubAddress a) => _looks[a.key] ?? const GitHubLook();

  /// Takes [it] as current: what a chat's rows read.
  void put(GitHubItem it) {
    final key = GitHubAddress.of(it.ref, pull: it.pull).key;
    _looks[key] = GitHubLook(item: it, at: clock());
    notifyListeners();
  }

  /// Asks for [a] unless known within [fresh] (null: known at all): a
  /// chip's first build ([quiet]), a hover's (a minute, not quiet).
  void want(GitHubAddress a, {bool quiet = true, Duration? fresh}) {
    if (daemon.daemonApi < githubItemsApi || !_hosts.contains(a.host)) return;
    final l = look(a);
    if (l.asking) return;
    final at = l.at;
    if (at != null && (fresh == null || clock().difference(at) < fresh)) {
      return;
    }
    if (fresh == null && l.error != null) return; // a chip asks once
    final host = _want.putIfAbsent(a.host, () => {});
    final was = host[a.key];
    host[a.key] = (a, quiet && (was?.$2 ?? true));
    _timers[a.host] ??= Timer(gather, () => unawaited(_ask(a.host)));
  }

  /// Asks for [refs] now and waits for the answer (a chat's rows).
  Future<void> ask(Iterable<GitHubAddress> refs, {bool quiet = true}) async {
    final byHost = <String, List<GitHubAddress>>{};
    for (final a in refs) {
      byHost.putIfAbsent(a.host, () => []).add(a);
    }
    await Future.wait([
      for (final MapEntry(key: host, value: list) in byHost.entries)
        _call(host, list, quiet: quiet),
    ]);
  }

  Future<void> _ask(String host) async {
    _timers.remove(host);
    final wanted = _want.remove(host);
    if (wanted == null || wanted.isEmpty) return;
    await _call(host, [
      for (final w in wanted.values) w.$1,
    ], quiet: wanted.values.every((w) => w.$2));
  }

  Future<void> _call(
    String host,
    List<GitHubAddress> list, {
    required bool quiet,
  }) async {
    if (list.isEmpty || daemon.daemonApi < githubItemsApi) return;
    for (final a in list) {
      _looks[a.key] = look(a).copyWith(asking: true);
    }
    notifyListeners();
    try {
      final r = await daemon.client.getGitHubItems(
        GetGitHubItemsRequest(
          refs: [for (final a in list) a.ref],
          quiet: quiet,
        ),
      );
      final now = clock();
      final answered = <String>{};
      for (final it in r.items) {
        final a = GitHubAddress.of(it.ref, pull: it.pull);
        answered.add(a.key);
        _looks[a.key] = GitHubLook(item: it, at: now);
      }
      for (final ref in r.unseen) {
        final a = GitHubAddress.of(ref, pull: false);
        answered.add(a.key);
        _looks[a.key] = GitHubLook(unseen: true, at: now);
      }
      for (final a in list) {
        if (answered.contains(a.key)) continue;
        _looks[a.key] = look(a).copyWith(
          asking: false,
          error: r.error.isEmpty ? null : r.error,
          clearError: r.error.isEmpty,
          signIn: r.signIn,
        );
      }
    } on Object catch (e) {
      for (final a in list) {
        _looks[a.key] = look(a).copyWith(asking: false, error: errorText(e));
      }
    }
    notifyListeners();
  }
}
