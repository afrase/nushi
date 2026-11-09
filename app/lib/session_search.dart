import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/agents.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The agents found to have no search of what was said in their sessions,
/// while the app runs: their field filters titles only.
final cantSearchSessions = <String>{};

/// A search of [agent]'s sessions in [folder] for what was said in them
/// (SearchAgentSessions, ADR 0035), for SessionList's field: asked once
/// typing pauses for [pause], or at once ([now]). An answer to text the
/// field no longer says is dropped.
class SessionSearch extends ChangeNotifier {
  new(this.daemon, this.agent, this.folder);

  final Daemon daemon;
  final String agent;
  final String folder;

  /// How long typing pauses before the search is asked.
  static const pause = Duration(milliseconds: 500);

  Timer? _wait;
  bool _gone = false;

  /// What the field says, trimmed.
  String text = '';

  /// The text last asked about, its answer and its error.
  String? asked;
  SearchAgentSessionsResponse? found;
  String? error;

  /// Whether the agent's sessions can be searched, as far as is known.
  bool get searches => !cantSearchSessions.contains(agent);

  /// The search shows: the field says something and the agent searches.
  bool get shown => text.isNotEmpty && searches;

  /// The field's text isn't answered yet: typed, or asked.
  bool get busy => shown && (asked != text || found == null && error == null);

  /// The field's text hasn't been asked about yet.
  bool get pending => shown && asked != text;

  /// The field says [typed].
  void typed(String typed) {
    final t = typed.trim();
    if (t == text) return; // the caret moved
    text = t;
    _wait?.cancel();
    if (shown) _wait = Timer(pause, now);
    notifyListeners();
  }

  /// Asks about what the field says now, if it isn't yet.
  void now() {
    _wait?.cancel();
    if (shown) unawaited(_ask(text));
  }

  /// Asks again after an error.
  void again() {
    if (shown) unawaited(_ask(text));
  }

  Future<void> _ask(String t) async {
    asked = t;
    found = null;
    error = null;
    notifyListeners();
    try {
      final r = await daemon.client.searchAgentSessions(
        SearchAgentSessionsRequest(agent: agent, folder: folder, text: t),
      );
      if (_gone || t != asked) return;
      if (!r.canSearch) cantSearchSessions.add(agent);
      found = r;
    } on Object catch (e) {
      if (_gone || t != asked) return;
      error = errorText(e);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    _wait?.cancel();
    super.dispose();
  }
}

/// The text around a search's first hit in a session, the hit marked.
class HitExcerpt extends StatelessWidget {
  const new(this.hit, {super.key});

  final SessionHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: hit.before),
            TextSpan(
              text: hit.match,
              style: TextStyle(
                color: t.text,
                backgroundColor: t.accentSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: hit.after),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.ui(t.textSecondary, size: 12),
      ),
    );
  }
}

/// A heading over a part of SessionList while its field says something:
/// the titles, or what was said.
class SessionsHeading extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Text(
        text,
        style: theme.ui(theme.t.textMuted, size: 11.5, weight: FontWeight.w600),
      ),
    );
  }
}

/// Where [search] stands when it has no sessions to show: searching, its
/// error with Try again, nothing found, or no search for the agent.
class SearchState extends StatelessWidget {
  const new(this.search, {super.key});

  final SessionSearch search;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final style = theme.ui(t.textMuted, size: 12.5);
    final error = search.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: switch (()) {
        _ when !search.searches => Text(
          "${agentTitle(search.agent)}'s sessions can't be searched for "
          'what was said: only titles are.',
          style: style,
        ),
        _ when search.busy => Row(
          children: [
            SizedBox.square(dimension: 12, child: Spinner(color: t.textMuted)),
            const SizedBox(width: 8),
            Text('Searching what was said…', style: style),
          ],
        ),
        _ when error != null => Wrap(
          children: [
            Text("Couldn't search: $error ", style: style),
            LinkText('Try again', size: 12.5, onTap: search.again),
          ],
        ),
        _ => Text('No sessions mention “${search.text}”.', style: style),
      },
    );
  }
}
