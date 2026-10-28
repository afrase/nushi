import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/widgets.dart';

/// The daemon finds and links a chat's pull request (FindChatPull,
/// LinkChatPull, Chat.pull).
const chatPullApi = 81;

/// How often a chat's pull request is asked for while it shows: an open
/// one, or a branch without one yet, each minute; one merged or closed
/// every 15 minutes (as Orca does).
const pullCardPoll = Duration(minutes: 1);
const pullDonePoll = Duration(minutes: 15);

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
/// tab last showed, or when the card first saw it).
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

/// A chat's pull request, as its card and the phone's chip show it: what
/// the daemon found of its folder (repository, branch) and the pull
/// request whole. It asks while something watches it ([watch]): at once,
/// then on [pullCardPoll] (quietly), a few seconds after a tool call
/// pushed or opened one, and when a turn ends.
class ChatPull extends ChangeNotifier {
  /// The one of [chat].
  factory of(Daemon daemon, ChatState chat) =>
      _all[chat] ??= ChatPull._(daemon, chat);

  new _(this.daemon, this.chat);

  static final _all = Expando<ChatPull>();

  final Daemon daemon;
  final ChatState chat;

  /// What the daemon said of the chat's folder; null until it answered.
  FindChatPullResponse? found;

  /// The linked pull request whole; null until asked, or with none.
  GitHubPull? pull;

  /// Why the last ask failed (what shows stays).
  String? error;

  int _followers = 0;
  int _watchers = 0;
  Timer? _timer;
  Timer? _soon;
  bool _busy = false;
  final _seen = <String>{};
  Future<void>? _asking;
  DateTime? _asked;

  /// The chat's link: the daemon's last word, else the chat's.
  GitHubLink? get link => chat.pull;

  /// Follows the chat (its pane shows): asks now, after a tool call that
  /// pushed or opened a pull request, and when a turn ends; no timer.
  void follow() {
    if (_followers++ == 0) {
      _busy = chat.busy;
      _seen.addAll(chat.items.map((i) => i.id));
      chat.addListener(_chatChanged);
    }
    unawaited(refresh(again: false));
  }

  void unfollow() {
    if (--_followers > 0) return;
    chat.removeListener(_chatChanged);
    _soon?.cancel();
  }

  /// Follows the chat, and asks on [pullCardPoll] too (the card shows).
  void watch() {
    _watchers++;
    follow();
    if (_asking == null) _schedule();
  }

  void unwatch() {
    if (--_watchers == 0) _timer?.cancel();
    unfollow();
  }

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

  void _schedule() {
    _timer?.cancel();
    if (_watchers == 0) return;
    final state = pull?.item.state;
    final wait = state == 'merged' || state == 'closed'
        ? pullDonePoll
        : pullCardPoll;
    _timer = Timer(wait, () => unawaited(refresh(quiet: true)));
  }

  /// Asks the daemon for the chat's pull request (it looks on GitHub and
  /// links what it finds), then for the linked one whole; one ask at a
  /// time, and with [again] false none within 10 s of the last.
  Future<void> refresh({bool quiet = false, bool again = true}) {
    final asked = _asked;
    if (_asking case final a?) return a;
    if (!again &&
        asked != null &&
        DateTime.now().difference(asked) < const Duration(seconds: 10)) {
      return Future.value();
    }
    return _asking = _ask(quiet).whenComplete(() {
      _asking = null;
      _asked = DateTime.now();
    });
  }

  Future<void> _ask(bool quiet) async {
    if (daemon.daemonApi < chatPullApi) return;
    try {
      final f = await daemon.client.findChatPull(
        FindChatPullRequest(chatId: chat.id, quiet: quiet),
      );
      found = f;
      chat.linkPull(f.hasPull() ? f.pull : null);
      error = f.error.isEmpty ? null : f.error;
      final l = chat.pull;
      if (l == null) {
        pull = null;
      } else {
        final r = await daemon.client.getGitHubPull(
          GetGitHubPullRequest(
            ref: GitHubRef(host: l.host, repo: l.repo, number: l.number),
            quiet: quiet,
          ),
        );
        pull = r.pull;
        // The comments there when the chat first saw it aren't new.
        if (!pullSeen.value.containsKey(chat.id)) markPullSeen(chat.id, r.pull);
      }
    } on Object catch (e) {
      error = errorText(e);
    }
    _schedule();
    notifyListeners();
  }

  /// Links [link] by hand, or unlinks (null).
  Future<void> setLink(GitHubLink? link) async {
    await daemon.client.linkChatPull(
      LinkChatPullRequest(chatId: chat.id, pull: link),
    );
    chat.linkPull(link);
    pull = null;
    notifyListeners();
    await refresh();
  }
}
