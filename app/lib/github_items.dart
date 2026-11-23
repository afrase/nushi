import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

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

/// The hosts Nushi gives a token to (ListGitHubHosts), one owner a daemon:
/// GitHubItems reads it for which links get chips and asks, and Settings ›
/// GitHub lists again after it adds, removes or allows a token, so a host
/// changed there shows in the GitHub views at once. It lists only when
/// asked: a listing asks GitHub for each host's limits.
class GitHubHosts extends ChangeNotifier {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= GitHubHosts._(daemon);

  new _(this.daemon);

  static final _all = Expando<GitHubHosts>();

  final Daemon daemon;

  /// As the daemon listed them last; null before a listing answered.
  List<GitHubHost>? hosts;

  /// Why the last listing failed; null once one answered.
  Object? error;

  Future<void>? _listing;
  Future<void>? _next;

  /// github.com and each listed host.
  Set<String> get known => {'github.com', ...?hosts?.map((h) => h.host)};

  /// Lists the hosts unless listed or listing (a chip's first look; one
  /// that failed is asked again by the next).
  void want() {
    if (hosts == null && _listing == null) unawaited(load());
  }

  /// Lists the hosts now. One asked while a listing runs waits for it and
  /// lists again after, so it sees what changed since that one was sent.
  Future<void> load() {
    if (_listing case final now?) {
      return _next ??= now.then((_) {
        _next = null;
        return load();
      });
    }
    return _listing = _list().whenComplete(() => _listing = null);
  }

  Future<void> _list() async {
    try {
      final r = await daemon.client.listGitHubHosts(ListGitHubHostsRequest());
      hosts = r.hosts;
      error = null;
      notifyListeners();
    } on Object catch (e) {
      error = e; // told to whoever awaited; listeners keep what they had
    }
  }
}

/// Pull requests and issues by number, for the app's session (never on
/// disk; ADR 0117): a chip asks once when first built (quiet), gathered
/// over 250 ms into one call a host; a hover asks again, not quiet, for
/// what's over a minute old; a chat's rows ask on their own clock. Never
/// polled here.
class GitHubItems extends ChangeNotifier {
  /// The one of [daemon].
  factory of(Daemon daemon) => _all[daemon] ??= GitHubItems._(daemon);

  new _(this.daemon) : _hosts = GitHubHosts.of(daemon) {
    _known = _hosts.known;
    _hosts.addListener(_hostsChanged);
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

  /// The hosts Nushi gives a token to, as Settings › GitHub last listed
  /// them; github.com until then.
  final GitHubHosts _hosts;
  late Set<String> _known;

  void _hostsChanged() {
    final known = _hosts.known;
    if (setEquals(known, _known)) return;
    _known = known;
    notifyListeners();
  }

  /// Whether [host] is one Nushi gives a token to: a link to another gets
  /// no chip and no request. The first asks for the list.
  bool knows(String host) {
    _hosts.want();
    return _known.contains(host);
  }

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
    if (!_known.contains(a.host)) return;
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

  /// Asks for [refs] now and waits for the answer (a chat's rows: of
  /// [chat], whose found pull requests opened outside its life the daemon
  /// then drops; ADR 0059's amendment).
  Future<void> ask(
    Iterable<GitHubAddress> refs, {
    bool quiet = true,
    String chat = '',
  }) async {
    final byHost = <String, List<GitHubAddress>>{};
    for (final a in refs) {
      byHost.putIfAbsent(a.host, () => []).add(a);
    }
    await Future.wait([
      for (final MapEntry(key: host, value: list) in byHost.entries)
        _call(host, list, quiet: quiet, chat: chat),
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
    String chat = '',
  }) async {
    if (list.isEmpty) return;
    for (final a in list) {
      _looks[a.key] = look(a).copyWith(asking: true);
    }
    notifyListeners();
    try {
      final r = await daemon.client.getGitHubItems(
        GetGitHubItemsRequest(
          refs: [for (final a in list) a.ref],
          quiet: quiet,
          chatId: chat,
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
