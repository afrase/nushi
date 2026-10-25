import 'dart:async';

import 'package:connectrpc/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_view_parts.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/settings_dialog.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// The New chat dialog's issue step: a field for an issue's link (pasted),
/// its key (on the site used last) or words of it, and the issues that
/// match on every site added (FindJiraIssues), for [onPick]. The arrows
/// move, Enter picks, Esc goes [onBack]. A link matching several sites
/// lists the issue on each, to pick from.
class IssuePicker extends StatefulWidget {
  const new({
    required this.daemon,
    required this.sites,
    required this.onPick,
    required this.onBack,
    this.text = '',
    super.key,
  });

  final Daemon daemon;

  /// The sites added: a row names its site when there are several.
  final List<JiraSite> sites;
  final ValueChanged<FoundJiraIssue> onPick;
  final VoidCallback onBack;

  /// What the field starts with (a link pasted into the dialog).
  final String text;

  @override
  State<IssuePicker> createState() => _IssuePickerState();
}

class _IssuePickerState extends State<IssuePicker> {
  late final _text = TextEditingController(text: widget.text);
  FindJiraIssuesResponse? _found;
  String? _error;
  int _at = 0;
  Timer? _wait;

  /// The text of the newest search, so an older answer is dropped.
  String? _asked;

  @override
  void initState() {
    super.initState();
    _text.addListener(_typed);
    unawaited(_find());
  }

  @override
  void dispose() {
    _wait?.cancel();
    _text.dispose();
    super.dispose();
  }

  String _last = '';

  void _typed() {
    if (_text.text == _last) return; // the caret moved
    _last = _text.text;
    _wait?.cancel();
    _wait = Timer(const Duration(milliseconds: 250), () => unawaited(_find()));
  }

  Future<void> _find() async {
    final text = _asked = _text.text.trim();
    try {
      final r = await widget.daemon.client.findJiraIssues(
        FindJiraIssuesRequest(text: text, site: lastJiraSite.value ?? ''),
      );
      if (!mounted || text != _asked) return;
      setState(() {
        _found = r;
        _error = null;
        _at = 0;
      });
    } on Object catch (e) {
      if (!mounted || text != _asked) return;
      setState(() => _error = e is ConnectException ? e.message : '$e');
    }
  }

  List<FoundJiraIssue> get _issues => _found?.issues ?? const [];

  void _pick(int i) {
    final f = _issues[i];
    lastJiraSite.value = f.site;
    widget.onPick(f);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final n = _issues.length;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onBack();
      case LogicalKeyboardKey.arrowDown when n > 0:
        setState(() => _at = (_at + 1) % n);
      case LogicalKeyboardKey.arrowUp when n > 0:
        setState(() => _at = (_at - 1 + n) % n);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when n > 0 && _asked == _text.text.trim():
        _pick(_at);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final found = _found;
    final unknown = found?.unknownSite ?? '';
    final note = switch (()) {
      _ when _error != null => _error,
      _ when found == null => 'Looking…',
      _ when unknown.isNotEmpty => null,
      _ when found.issues.isEmpty =>
        _asked!.isEmpty ? 'No issues looked at lately.' : 'No issues match.',
      _ => null,
    };
    final sites = {for (final f in _issues) f.site};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 8, 6),
          child: Row(
            children: [
              IconTap(Icons.arrow_back, tooltip: 'Back', onTap: widget.onBack),
              const SizedBox(width: 4),
              Text(
                'Jira issue',
                style: theme.ui(t.text, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Focus(
            onKeyEvent: _key,
            child: TextField(
              controller: _text,
              autofocus: true,
              style: theme.ui(t.text),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'A link, a key, or words',
              ),
            ),
          ),
        ),
        if (unknown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Tap(
              onTap: () =>
                  showSettings(context, widget.daemon.client, jira: true),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${Uri.tryParse(unknown)?.host ?? unknown} '
                          "isn't added. ",
                    ),
                    TextSpan(
                      text: 'Settings › Jira',
                      style: TextStyle(color: t.link),
                    ),
                  ],
                ),
                style: theme.ui(t.textMuted, size: 12.5),
              ),
            ),
          )
        else if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: Text(note, style: theme.ui(t.textMuted, size: 12.5)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final (i, f) in _issues.indexed)
                  _row(
                    theme,
                    i,
                    f,
                    site: widget.sites.length > 1 || sites.length > 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(NushiTheme theme, int i, FoundJiraIssue f, {required bool site}) {
    final t = theme.t;
    final is_ = f.issue;
    return Tap(
      onTap: () => _pick(i),
      selected: i == _at,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(is_.key, style: theme.code(t.textSecondary, size: 11.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  site ? f.site : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.textMuted, size: 11.5),
                ),
              ),
              Text(
                is_.status,
                style: theme.ui(statusColor(t, is_.statusCategory), size: 11.5),
              ),
            ],
          ),
          Text(
            is_.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(t.text),
          ),
        ],
      ),
    );
  }
}
