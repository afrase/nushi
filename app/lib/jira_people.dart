import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/jira_sources.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/settings.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

/// [name] as plain text for a line of its own: control and bidirectional
/// characters dropped (a name is anyone's text, and shouldn't reorder or
/// hide what's around it), line breaks and tabs as spaces.
String plainName(String name) => String.fromCharCodes([
  for (final r in name.trim().runes)
    if (r == 0x0A || r == 0x09 || r == 0x2028 || r == 0x2029)
      0x20
    else if (!(r < 0x20 ||
        (r >= 0x7F && r <= 0x9F) ||
        (r >= 0x200B && r <= 0x200F) ||
        (r >= 0x202A && r <= 0x202E) ||
        (r >= 0x2060 && r <= 0x2069) ||
        r == 0x061C ||
        r == 0xFEFF))
      r,
]);

/// A name's initials: the first letters of its first and last words
/// ("Ann Lee" AL, "Cher" C), upper case; "?" for none.
String initials(String name) {
  final words = plainName(name)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  String first(String w) => String.fromCharCode(w.runes.first);
  final out = words.length == 1
      ? first(words.first)
      : first(words.first) + first(words.last);
  return out.toUpperCase();
}

/// A person's color, the same for an account id every time (FNV-1a of
/// it, the name when there's no id): one of the theme's [Tokens.avatars].
Color personColor(Tokens t, String id) {
  var h = 0x811c9dc5;
  for (final u in id.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
  }
  return t.avatars[h % t.avatars.length];
}

/// An issue's assignee as a small round avatar: initials on the person's
/// color, the name on hover; "Unassigned" a muted dashed circle. Jira's
/// avatar images aren't fetched (`docs/facts/jira.md`).
class Avatar extends StatelessWidget {
  const new({required this.name, required this.id, super.key, this.size = 20});

  /// The person's name ("" for nobody) and account id.
  final String name;
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final shown = plainName(name);
    if (shown.isEmpty) {
      return Tooltip(
        message: 'Unassigned',
        child: CustomPaint(
          size: Size.square(size),
          painter: _Dashed(t.textMuted),
        ),
      );
    }
    return Tooltip(
      message: shown,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: personColor(t, id.isEmpty ? shown : id),
          shape: BoxShape.circle,
        ),
        child: Text(
          initials(shown),
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: theme.ui(
            t.monogramText,
            size: size * 0.42,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A dashed circle, for nobody.
class _Dashed extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final r = size.width / 2 - 0.6;
    final c = size.center(Offset.zero);
    const dashes = 10;
    const step = 2 * pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        i * step,
        step * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}

/// Whose issues a list shows: everyone's, mine, nobody's, or one
/// person's (by account id, with the name to say when they've left the
/// list).
@immutable
class Assignee {
  const new everyone() : kind = 'everyone', id = '', name = '';
  const new me() : kind = 'me', id = '', name = '';
  const new nobody() : kind = 'none', id = '', name = '';
  const new person(this.id, this.name) : kind = 'person';

  /// As [toList] made it; everyone for anything else.
  factory fromList(List<String>? saved) => switch (saved) {
    ['me'] => const .me(),
    ['none'] => const .nobody(),
    ['person', final id, final name] when id.isNotEmpty => .person(id, name),
    _ => const .everyone(),
  };

  final String kind;
  final String id;
  final String name;

  bool get everyone => kind == 'everyone';

  List<String> toList() => switch (kind) {
    'person' => ['person', id, name],
    _ => [kind],
  };

  /// What the menu's face says.
  String get label => switch (kind) {
    'me' => 'Me',
    'none' => 'Unassigned',
    'person' => plainName(name),
    _ => 'Everyone',
  };

  /// Whether [issue] is one of those shown; [site] says who I am.
  bool shows(JiraIssue issue, JiraSite site) => switch (kind) {
    'me' => mine(issue, site),
    'none' => issue.assignee.isEmpty && issue.assigneeId.isEmpty,
    'person' =>
      issue.assigneeId == id ||
          issue.assigneeId.isEmpty && issue.assignee == name,
    _ => true,
  };

  @override
  bool operator ==(Object other) =>
      other is Assignee && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Whether [issue] is assigned to the site's token's user (by name only
/// in a list kept from before Nushi knew account ids).
bool mine(JiraIssue issue, JiraSite site) => issue.assigneeId.isNotEmpty
    ? issue.assigneeId == site.accountId
    : issue.assignee.isNotEmpty && issue.assignee == site.name;

/// Where a list's assignee filter is remembered: the site and the list
/// ("sprint", "jql", a saved search by its JQL).
String filterPlace(JiraSite site, JiraList list) => switch (list) {
  MyIssues() => '${site.id} mine',
  Sprint() => '${site.id} sprint',
  Jql() => '${site.id} jql',
  Saved(:final jql) => '${site.id} search $jql',
};

/// The filter remembered for [place].
Assignee assigneeAt(String place) =>
    Assignee.fromList(jiraAssignee.value[place]);

/// Remembers [a] for [place] (everyone is no entry).
void setAssignee(String place, Assignee a) => jiraAssignee.value = {
  for (final e in jiraAssignee.value.entries)
    if (e.key != place) e.key: e.value,
  if (!a.everyone) place: a.toList(),
};

/// The bar's assignee filter: Everyone, Me, Unassigned, then the people
/// [issues] are assigned to (but me), by name, each with how many.
class AssigneeMenu extends StatelessWidget {
  const new({
    required this.site,
    required this.issues,
    required this.value,
    required this.onPick,
    super.key,
  });

  final JiraSite site;
  final List<JiraIssue> issues;
  final Assignee value;
  final ValueChanged<Assignee> onPick;

  @override
  Widget build(BuildContext context) {
    final people = <String, ({String name, int n})>{};
    var mineN = 0;
    var nobody = 0;
    for (final i in issues) {
      if (i.assignee.isEmpty && i.assigneeId.isEmpty) {
        nobody++;
      } else if (mine(i, site)) {
        mineN++;
      } else {
        final id = i.assigneeId.isEmpty ? i.assignee : i.assigneeId;
        final had = people[id];
        people[id] = (name: i.assignee, n: (had?.n ?? 0) + 1);
      }
    }
    final byName = people.entries.toList()
      ..sort(
        (a, b) =>
            a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()),
      );
    MenuEntry entry(Assignee a, int n) => MenuEntry(
      a.label,
      detail: '$n',
      checked: a == value,
      onPick: () => onPick(a),
    );
    final gone =
        value.kind == 'person' &&
        !people.containsKey(value.id) &&
        !people.containsKey(value.name);
    return MenuField(
      compact: true,
      tooltip: 'Whose issues',
      entries: [
        entry(const .everyone(), issues.length),
        entry(const .me(), mineN),
        entry(const .nobody(), nobody),
        if (byName.isNotEmpty || gone) MenuEntry.divider,
        for (final p in byName)
          entry(Assignee.person(p.key, p.value.name), p.value.n),
        if (gone) entry(value, 0),
      ],
      label: Text(value.label),
    );
  }
}
