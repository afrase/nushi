import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/settings.dart';

/// How often a chat's pull requests are asked for (ADR 0140): an open one,
/// or a branch without one yet, each minute; merged or closed every 15
/// minutes (as Orca does); while the window isn't in front, every
/// [pullAwayPoll] at most.
const pullWidgetPoll = Duration(minutes: 1);
const pullDonePoll = Duration(minutes: 15);
const pullAwayPoll = Duration(minutes: 5);

/// Whether the app's window is in front (focused): the polls slow down
/// while it isn't (ADR 0140). A test's binding, which says nothing, is.
bool get inFront {
  final s = WidgetsBinding.instance.lifecycleState;
  return s == null || s == AppLifecycleState.resumed;
}

/// [every], or [pullAwayPoll] while the window isn't in front, whichever
/// is longer.
Duration polledEvery(Duration every) =>
    inFront || every > pullAwayPoll ? every : pullAwayPoll;

/// How long until [p] is asked for again: [pullDonePoll] once merged or
/// closed, else [pullWidgetPoll] (also before it's known).
Duration pullPoll(GitHubPull? p) => itemPoll(p?.item);

/// [pullPoll] of a pull request's row item.
Duration itemPoll(GitHubItem? it) {
  final state = it?.state;
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

/// The comments [it] (a row's item, which counts them) has that [chat]
/// hasn't seen: those since its tab last showed it, or since the chat
/// first knew it (ADR 0140: the widget doesn't read the pull request
/// whole). 0 until it's known.
int unreadCount(String chat, GitHubItem it) {
  final seen = pullSeenComments.value[chat]?[it.id];
  return seen == null ? 0 : max(0, it.comments - seen);
}

/// Takes [it]'s comments as seen in [chat]: [always] (its tab shows
/// them), or only when the chat hasn't known it before (what's there then
/// isn't new).
void seenComments(String chat, GitHubItem it, {bool always = false}) {
  if (it.id.isEmpty) return;
  final kept = pullSeenComments.value[chat] ?? const <String, int>{};
  if (kept[it.id] == it.comments || (!always && kept.containsKey(it.id))) {
    return;
  }
  pullSeenComments.value = {
    ...pullSeenComments.value,
    chat: {...kept, it.id: it.comments},
  };
}
