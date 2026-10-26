import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:nushi/daemon.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';

/// The skills and plugins Claude uses in a folder, from the daemon (API
/// 66), read from Claude's files each time the Skills view opens or is
/// refreshed: a skill added or a plugin turned on in a terminal shows
/// then. One per folder while the app runs.
class SkillsList extends ChangeNotifier {
  factory of(Daemon daemon, String folder) =>
      _byFolder[folder] ??= SkillsList._(daemon, folder);
  new _(this.daemon, this.folder);

  static final _byFolder = <String, SkillsList>{};

  final Daemon daemon;
  final String folder;
  ListSkillsResponse list = ListSkillsResponse();
  bool loaded = false;
  bool loading = false;
  String error = ''; // why listing failed

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      list = await daemon.client.listSkills(ListSkillsRequest(folder: folder));
      error = '';
      loaded = true;
    } on Object catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  /// After a change here: other folders' lists may be out of date too.
  Future<void> changed() {
    _byFolder.removeWhere((_, l) => l != this);
    return refresh();
  }

  /// [skills] by where they come from, in the view's order: yours, the
  /// project's, each plugin's (by its id).
  Map<String, List<Skill>> groups(Iterable<Skill> skills) {
    final out = <String, List<Skill>>{'user': [], 'project': []};
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
