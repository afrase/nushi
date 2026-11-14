import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_items.dart';
import 'package:nushi/github_pull.dart' show openPullAt;
import 'package:nushi/pull_cache.dart';
import 'package:nushi/pull_lights.dart' show PullSection;
import 'package:nushi/pull_states.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

/// The daemon finds and links a chat's pull request (FindChatPull,
/// LinkChatPull, Chat.pull).
const chatPullApi = 81;

/// How often a chat's pull request is asked for while the chat is open:
/// an open one, or a branch without one yet, each minute; one merged or
/// closed every 15 minutes (as Orca does).
const pullWidgetPoll = Duration(minutes: 1);
const pullDonePoll = Duration(minutes: 15);

/// How long until [p] is asked for again: [pullDonePoll] once merged or
/// closed, else [pullWidgetPoll] (also before it's known).
Duration pullPoll(GitHubPull? p) {
  final state = p?.item.state;
  return state == 'merged' || state == 'closed' ? pullDonePoll : pullWidgetPoll;
}

/// When the chat's pull request was last looked for and how often it is,
/// as the widget's tooltip says it: "Checked 20 s ago · every minute".
String checkedWords(DateTime? checked, Duration every, DateTime now) {
  final m = every.inMinutes;
  final often = m == 1 ? 'every minute' : 'every $m minutes';
  if (checked == null) return 'Not checked yet · $often';
  final age = now.difference(checked);
  final when = switch (age) {
    _ when age.inSeconds < 60 => '${max(age.inSeconds, 0)} s',
    _ when age.inMinutes < 60 => '${age.inMinutes} min',
    _ => '${age.inHours} h',
  };
  return 'Checked $when ago · $often';
}

/// Whether a tool call may have pushed the chat's branch or opened its
/// pull request: `git push`, `gh pr create`, or a GitHub MCP server's
/// create_pull_request, once it completed.
bool pushedOrOpened(Item it) {
  if (it.kind != ItemKind.ITEM_KIND_TOOL_CALL || it.status != 'completed') {
    return false;
  }
  final what = '${it.title}\n${it.input}\n${it.tool}'.toLowerCase();
  return RegExp(r'\bgit\b[^\n|;&]*\spush\b').hasMatch(what) ||
      RegExp(r'\bgh\s+pr\s+create\b').hasMatch(what) ||
      what.contains('create_pull_request');
}

/// The times of a pull request's comments: its conversation's and its
/// review threads'.
Iterable<int> commentTimes(GitHubPull p) => [
  for (final c in p.conversation) c.createdMs.toInt(),
  for (final x in p.threads)
    for (final c in x.comments) c.createdMs.toInt(),
];

/// The comments of [chat]'s pull request newer than those seen (when its
/// tab last showed, or when the widget first saw it).
int unreadComments(String chat, GitHubPull p) {
  final times = commentTimes(p);
  final seen = pullSeen.value[chat];
  return seen == null ? 0 : times.where((ms) => ms > seen).length;
}

/// Marks [p]'s comments seen in [chat].
void markPullSeen(String chat, GitHubPull p) {
  final newest = commentTimes(p).fold(0, (a, b) => a > b ? a : b);
  if ((pullSeen.value[chat] ?? -1) >= newest) return;
  pullSeen.value = {...pullSeen.value, chat: newest};
}

/// [l] as the item store keys it.
GitHubAddress addressOf(GitHubLink l) =>
    GitHubAddress(host: l.host, repo: l.repo, number: l.number, pull: l.pull);

/// What tells two links apart: host, repository (any case) and number.
String pullKey(GitHubLink l) => addressOf(l).key;

/// A pull request read whole as a row's item, for a daemon before
/// GetGitHubItems: its size, base and head, and its checks counted.
GitHubItem rowItem(GitHubPull p) {
  var passed = 0;
  var failed = 0;
  var running = 0;
  var skipped = 0;
  for (final c in p.checks) {
    switch (c.state) {
      case 'success' || 'neutral':
        passed++;
      case 'pending':
        running++;
      case 'skipped' || 'stale':
        skipped++;
      default:
        failed++;
    }
  }
  return p.item.deepCopy()
    ..additions = p.additions
    ..deletions = p.deletions
    ..changedFiles = p.changedFiles
    ..mergeState = p.mergeState
    ..unresolved = p.threads.where((x) => !x.resolved).length
    ..base = p.base
    ..head = p.head
    ..checkCounts = GitHubCheckCounts(
      passed: passed,
      failed: failed,
      running: running,
      skipped: skipped,
    );
}

/// [links] in the widget's order (ADR 0117): as linked, except that a
/// stack (one's base is another's head, in one repository) lists its base
/// first, each pull request right after the one it's on.
List<GitHubLink> orderPulls(
  List<GitHubLink> links,
  GitHubItem? Function(GitHubLink) item,
) {
  GitHubLink? baseOf(GitHubLink l) {
    final it = item(l);
    if (it == null || it.base.isEmpty) return null;
    for (final o in links) {
      final oi = item(o);
      if (pullKey(o) != pullKey(l) &&
          oi != null &&
          oi.head == it.base &&
          o.host == l.host &&
          o.repo.toLowerCase() == l.repo.toLowerCase()) {
        return o;
      }
    }
    return null;
  }

  final bases = {for (final l in links) pullKey(l): baseOf(l)};
  final out = <GitHubLink>[];
  final done = <String>{};
  void add(GitHubLink l) {
    if (!done.add(pullKey(l))) return;
    out.add(l);
    for (final o in links) {
      if (bases[pullKey(o)] case final b? when pullKey(b) == pullKey(l)) {
        add(o);
      }
    }
  }

  // Each stack where its first linked one is, from its base.
  for (final l in links) {
    var root = l;
    final seen = {pullKey(l)};
    for (
      var b = bases[pullKey(root)];
      b != null && seen.add(pullKey(b));
      b = bases[pullKey(b)]
    ) {
      root = b;
    }
    add(root);
    add(l); // one in a cycle
  }
  return out;
}

/// A chat's pull request, as its widget and the header's tab show it: what
/// the daemon found of its folder (repository, branch) and the pull
/// request whole. It asks while the chat is open ([follow]), whether the
/// details panel shows or not: at once, then on [pullWidgetPoll] (quietly),
/// 3 s after a tool call pushed or opened one and after a turn ends, and
/// when the window comes to the front. Each ask that finds one links it
/// (the daemon's FindChatPull); only Unlink keeps that one off.
class ChatPull extends ChangeNotifier {
  /// The one of [chat].
  factory of(Daemon daemon, ChatState chat) =>
      (_all[chat] ??= ChatPull._(daemon, chat)).._seed();

  new _(this.daemon, this.chat);

  static final _all = Expando<ChatPull>();

  final Daemon daemon;
  final ChatState chat;

  /// What the daemon said of the chat's folder; null until it answered.
  FindChatPullResponse? found;

  /// The linked pull request whole; null until asked, or with none. Until
  /// the first ask answers, what was read last (`pull_cache.dart`), from
  /// [keptAt].
  GitHubPull? pull;

  /// When the pull request showing was read, while it's the one kept
  /// from before (null once asked).
  DateTime? keptAt;

  /// Whether it's being asked for now.
  bool get asking => _asking != null;

  /// What was read last of the linked pull request, until it's asked.
  void _seed() {
    final l = current;
    if (pull != null || l == null) return;
    if (cachedPull(l.asRef) case (final at, final p)) {
      pull = p;
      keptAt = at;
    }
  }

  /// Why the last ask failed (what shows stays).
  String? error;

  int _followers = 0;
  Timer? _timer;
  Timer? _soon;
  AppLifecycleListener? _front;
  bool _busy = false;
  final _seen = <String>{};
  Future<void>? _asking;
  DateTime? _asked;
  int _rechecks = 0;

  /// The tab's pull request ([current]).
  GitHubLink? get link => current;

  /// The chat's pull requests in the widget's order: as linked, a stack's
  /// base first (ADR 0117).
  List<GitHubLink> get links => orderPulls(chat.pulls, itemOf);

  /// The pull request the tab shows: the one picked there (remembered for
  /// the chat), else the primary.
  GitHubLink? get current {
    final picked = pickedPulls.value[chat.id];
    if (picked != null) {
      for (final l in chat.pulls) {
        if (pullKey(l) == picked) return l;
      }
    }
    return chat.pull;
  }

  /// Shows [link] in the tab from now on; with [files] or [checks], at
  /// that section.
  void pick(GitHubLink link, {bool files = false, bool checks = false}) {
    if (files || checks) {
      openPullAt(link.asRef, files ? PullSection.files : PullSection.checks);
    }
    final was = current;
    if (was != null && pullKey(was) == pullKey(link)) return;
    pickedPulls.value = {...pickedPulls.value, chat.id: pullKey(link)};
    pull = null;
    keptAt = null;
    _seed();
    notifyListeners();
    unawaited(refresh());
  }

  /// [link]'s pull request as a row shows it (GetGitHubItems'; the one
  /// read whole, from a daemon before them).
  GitHubItem? itemOf(GitHubLink link) {
    final kept = GitHubItems.of(daemon).look(addressOf(link)).item;
    if (kept != null) return kept;
    final p = pull;
    final l = current;
    if (p == null || l == null || pullKey(l) != pullKey(link)) return null;
    return rowItem(p);
  }

  /// [link]'s new comments: known for the one read whole.
  int unreadOf(GitHubLink link) {
    final p = pull;
    final l = current;
    if (p == null || l == null || pullKey(l) != pullKey(link)) return 0;
    return unreadComments(chat.id, p);
  }

  /// [link]'s pull request whole, for Fix checks, Merge…, Clean up…: the
  /// tab's when it's that one, else asked of GitHub now; null, said under
  /// [context], when it can't be.
  Future<GitHubPull?> whole(BuildContext context, GitHubLink link) async {
    final l = current;
    if (pull case final p? when l != null && pullKey(l) == pullKey(link)) {
      return p;
    }
    try {
      final r = await daemon.client.getGitHubPull(
        GetGitHubPullRequest(ref: link.asRef),
      );
      return r.pull;
    } on Object catch (e) {
      if (context.mounted) showError(context, e);
      return null;
    }
  }

  /// Unlinks [link] from the chat: never found or opened again for it.
  Future<void> unlink(GitHubLink link) async {
    if (daemon.daemonApi < githubItemsApi) {
      await setLink(null);
      return;
    }
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, unlink: link),
    );
    chat.linkPull(
      chat.pull != null && pullKey(chat.pull!) == pullKey(link)
          ? chat.pulls.where((l) => pullKey(l) != pullKey(link)).firstOrNull
          : chat.pull,
      all: [
        for (final l in chat.pulls)
          if (pullKey(l) != pullKey(link)) l,
      ],
    );
    notifyListeners();
    await again();
  }

  /// When it was last looked for and how often, as the widget's tooltip
  /// says it: "Checked 20 s ago · every minute".
  String get checkedText => checkedWords(_asked, every, clock());

  /// How long until the next ask on the timer: a minute, or 15 for a
  /// pull request merged or closed.
  Duration get every => pullPoll(pull);

  /// Follows the chat (its pane shows): asks now, on [pullWidgetPoll], after
  /// a tool call that pushed or opened a pull request, when a turn ends
  /// and when the window comes to the front.
  void follow() {
    if (_followers++ == 0) {
      _busy = chat.busy;
      _seen.addAll(chat.items.map((i) => i.id));
      chat.addListener(_chatChanged);
      _front = AppLifecycleListener(
        onResume: () => unawaited(refresh(again: false)),
      );
    }
    unawaited(refresh(again: false));
    if (_asking == null) _schedule(); // asked within 10 s: none now
  }

  void unfollow() {
    if (--_followers > 0) return;
    chat.removeListener(_chatChanged);
    _front?.dispose();
    _front = null;
    _soon?.cancel();
    _timer?.cancel();
    _back.cancel();
  }

  // An ask the daemon was gone for, made again once it is back rather than
  // on the timer (a quarter of an hour for a merged pull request).
  late final _back = LoadAgain(daemon, () {
    if (_followers > 0) unawaited(refresh(quiet: true));
  });

  /// A turn ended, or a tool call pushed or opened a pull request: ask
  /// again in a moment (GitHub takes a moment to list a new one).
  void _chatChanged() {
    final ended = _busy && !chat.busy;
    _busy = chat.busy;
    var pushed = false;
    for (final it in chat.items.reversed.take(8)) {
      if (pushedOrOpened(it) && _seen.add(it.id)) pushed = true;
    }
    if (ended || pushed) {
      _soon?.cancel();
      _soon = Timer(const Duration(seconds: 3), () => unawaited(refresh()));
    }
  }

  /// The next ask on the timer: [every] after the last.
  void _schedule() {
    _timer?.cancel();
    if (_followers == 0) return;
    final at = clock();
    final due = (_asked ?? at).add(every).difference(at);
    _timer = Timer(
      due.isNegative ? Duration.zero : due,
      () => unawaited(refresh(quiet: true)),
    );
  }

  /// Asks the daemon for the chat's pull request (it looks on GitHub and
  /// links what it finds), then for the linked one whole; one ask at a
  /// time, and with [again] false none within 10 s of the last.
  Future<void> refresh({bool quiet = false, bool again = true}) {
    final asked = _asked;
    if (_asking case final a?) return a;
    if (!again &&
        asked != null &&
        clock().difference(asked) < const Duration(seconds: 10)) {
      return Future.value();
    }
    return _asking = _ask(quiet).whenComplete(() {
      _asking = null;
      _asked = clock();
      _schedule();
      notifyListeners();
    });
  }

  /// Asks again after a change made here: an ask under way may have started
  /// before it, so another follows that one.
  Future<void> again() async {
    if (asking) await refresh();
    await refresh();
  }

  Future<void> _ask(bool quiet) async {
    if (daemon.daemonApi < chatPullApi) return;
    _back.cancel();
    try {
      final f = await daemon.client.findChatPull(
        FindChatPullRequest(chatId: chat.id, quiet: quiet),
      );
      found = f;
      chat.linkPull(
        f.hasPull() ? f.pull : null,
        // A daemon before API 118 says only the primary.
        all: f.pulls.isNotEmpty ? f.pulls : null,
      );
      error = f.error.isEmpty ? null : f.error;
      await _rows(quiet);
      final l = current;
      if (l == null) {
        pull = null;
        keptAt = null;
      } else {
        final ref = l.asRef;
        final r = await daemon.client.getGitHubPull(
          GetGitHubPullRequest(ref: ref, quiet: quiet),
        );
        pull = r.pull;
        keptAt = null;
        keepPull(ref, r.pull);
        PullStates.of(daemon).put(r.pull.item);
        _recheck(r.pull);
        // The comments there when the chat first saw it aren't new.
        if (!pullSeen.value.containsKey(chat.id)) markPullSeen(chat.id, r.pull);
      }
    } on Object catch (e) {
      error = errorText(e);
      _back.failed(e);
    }
  }

  /// The rows' items, all in one call a host (GetGitHubItems), from a
  /// daemon that has it.
  Future<void> _rows(bool quiet) async {
    if (daemon.daemonApi < githubItemsApi || chat.pulls.isEmpty) return;
    await GitHubItems.of(daemon)
        .ask([for (final l in chat.pulls) addressOf(l)], quiet: quiet);
  }

  /// GitHub works out whether a pull request merges when it's asked, so
  /// "unknown" usually lasts seconds, not until the next minute's ask: asked
  /// again soon, three times at most in a row.
  void _recheck(GitHubPull p) {
    if (!p.merge.blocks.contains('unknown') || p.item.state != 'open') {
      _rechecks = 0;
    } else if (_followers > 0 && _rechecks < 3) {
      _rechecks++;
      _soon?.cancel();
      _soon = Timer(
        const Duration(seconds: 5),
        () => unawaited(refresh(quiet: true)),
      );
    }
  }

  /// Marks the pull request's comments seen: its Pull request tab shows
  /// them.
  void markSeen() {
    if (pull case final p?) markPullSeen(chat.id, p);
  }

  /// Adds [link] by hand after the chat's others (Link another pull
  /// request…, a chip's Link to this chat; ADR 0117).
  Future<void> addLink(GitHubLink link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, pull: link, add: true),
    );
    await again();
  }

  /// Links [link] by hand, or unlinks (null).
  Future<void> setLink(GitHubLink? link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, pull: link),
    );
    chat.linkPull(link);
    pull = null;
    keptAt = null;
    _seed();
    notifyListeners();
    await refresh();
  }
}
