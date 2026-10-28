import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/folder_button.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The skills (and Claude's plugins) an agent uses in a folder, from the
/// daemon (API 67), read from the agent's files each time the Skills view
/// opens or is refreshed: a skill added or a switch changed in a terminal
/// shows then. Shared skills (.agents/skills) come with every agent that
/// loads each. One per agent and folder while the app runs.
class SkillsList extends ChangeNotifier {
  factory of(Daemon daemon, String folder, String agent) =>
      _byKey[(agent, folder)] ??= SkillsList._(daemon, folder, agent);
  new _(this.daemon, this.folder, this.agent);

  static final _byKey = <(String, String), SkillsList>{};

  final Daemon daemon;
  final String folder;
  final String agent;
  ListSkillsResponse list = ListSkillsResponse();
  bool loaded = false;
  bool loading = false;
  String error = ''; // why listing failed

  bool _again = false; // refresh once the running one is done

  /// Lists them again; asked while a list is on its way (a switch changed
  /// as the view opened), once more after it, which may predate the change.
  Future<void> refresh() async {
    if (loading) {
      _again = true;
      return;
    }
    loading = true;
    notifyListeners();
    do {
      _again = false;
      try {
        list = await daemon.client.listSkills(
          ListSkillsRequest(folder: folder, agent: agent),
        );
        error = '';
        loaded = true;
      } on Object catch (e) {
        error = '$e';
      }
    } while (_again);
    loading = false;
    notifyListeners();
  }

  /// After a change here: other folders' and agents' lists may be out of
  /// date too.
  Future<void> changed() {
    _byKey.removeWhere((_, l) => l != this);
    return refresh();
  }

  /// [skills] by where they come from, in the view's order: yours, the
  /// project's, the shared ones, the agent's own, each plugin's (by its
  /// id).
  Map<String, List<Skill>> groups(Iterable<Skill> skills) {
    final out = <String, List<Skill>>{
      'user': [],
      'project': [],
      'shared': [],
      'system': [],
    };
    for (final s in skills) {
      (out[s.source == 'plugin' ? s.plugin : s.source] ??= []).add(s);
    }
    return out;
  }
}

/// Whether [s] matches what was typed in the search box: its name or its
/// description, in any case.
bool skillMatches(Skill s, String query) =>
    query.isEmpty ||
    s.name.toLowerCase().contains(query) ||
    s.description.toLowerCase().contains(query);

/// Whether [p] matches the search: its id or its description.
bool pluginMatches(Plugin p, String query) =>
    query.isEmpty ||
    p.id.toLowerCase().contains(query) ||
    p.description.toLowerCase().contains(query);

/// Opens a skill's SKILL.md in the default text editor (`open -t`: as
/// text, whatever the file turns out to be).
Future<void> openSkillFile(Skill s) =>
    Process.run('/usr/bin/open', ['-t', '${s.path}/SKILL.md']);

/// Shows [path] in Finder.
Future<void> revealInFinder(String path) =>
    Process.run('/usr/bin/open', ['-R', path]);

/// Where a skill's switch acts, as the agent keeps it.
String switchWhere(String agent, Skill s) => switch (agent) {
  'claude' when s.source == 'user' => 'everywhere',
  'claude' => 'in this project',
  'codex' => 'in config.toml',
  'pig' when s.source == 'user' || s.everywhere => 'in your settings',
  'pig' => 'in .pig/settings.json',
  _ => 'by name, everywhere',
};

/// Why a switch can't act: the agent's settings don't read, or another
/// file decides it.
String switchWhy(SkillsList list, String setIn) {
  if (list.list.noSwitch.isNotEmpty) return list.list.noSwitch;
  if (setIn.isNotEmpty) return 'Set in ${tildePath(setIn)}; change it there.';
  return '';
}

/// Turns [s] on or off for the list's agent.
Future<void> setSkillOn(SkillsList list, Skill s, {required bool on}) async {
  await list.daemon.client.setSkillOn(
    SetSkillOnRequest(
      folder: list.folder,
      source: s.source,
      name: s.name,
      on: on,
      agent: list.agent,
    ),
  );
  await list.changed();
}

/// Whether the skill at [path] is in one of [agent]'s own folders, which
/// Nushi deletes from, rather than another agent's it also reads (omp and
/// Ante read Claude's, omp Codex's and GitHub's). The agent's own built-in
/// ones aren't deleted either (it puts them back).
bool ownSkill(String agent, String path) {
  final others = {
    '/.claude/skills/': 'claude',
    '/.codex/skills/': 'codex',
    '/.github/skills/': '',
    '/.agent/skills/': '',
  };
  return !others.entries.any((e) => path.contains(e.key) && e.value != agent);
}
