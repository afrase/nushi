import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nushi/chat_paths.dart';
import 'package:nushi/fnv.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/run_state.dart';

/// A code review's findings that an agent wrote as JSON in a message (a
/// fenced block, or a bare array), with the text around them and the
/// block as written ([json], fences included).
typedef FindingsInText = ({
  String before,
  Findings findings,
  String json,
  String after,
});

final _fence = RegExp(
  r'^```[ \t]*(json)?[ \t]*\n([\s\S]*?)\n```[ \t]*$',
  multiLine: true,
);

/// The findings in an agent's message, if it holds a review's: a fenced
/// block (```json or ```), or else a bare JSON array starting a line, that
/// decodes to a list of objects each with a `file`, a `line` and a
/// `summary`. Only decoded, never run or fetched.
FindingsInText? findingsInText(String text) {
  // Cheap checks first: this runs on every streamed chunk of a message.
  if (text.length > 256 << 10 ||
      !text.contains('"summary"') ||
      !text.contains('"file"')) {
    return null;
  }
  for (final m in _fence.allMatches(text)) {
    if (_decode(m.group(2)!) case final f?) {
      return (
        before: text.substring(0, m.start).trimRight(),
        findings: f,
        json: m.group(0)!,
        after: text.substring(m.end).trimLeft(),
      );
    }
  }
  final start = text.startsWith('[') ? 0 : text.indexOf('\n[') + 1;
  final end = text.lastIndexOf(']') + 1;
  if (start == 0 && !text.startsWith('[') || end <= start) return null;
  final f = _decode(text.substring(start, end));
  if (f == null) return null;
  return (
    before: text.substring(0, start).trimRight(),
    findings: f,
    json: '```json\n${text.substring(start, end)}\n```',
    after: text.substring(end).trimLeft(),
  );
}

Findings? _decode(String json) {
  final Object? list;
  try {
    list = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (list is! List || list.isEmpty) return null;
  final out = Findings();
  for (final e in list) {
    if (e is! Map ||
        e['file'] is! String ||
        e['summary'] is! String ||
        !e.containsKey('line') ||
        e['line'] is! int?) {
      return null;
    }
    String s(String key) => switch (e[key]) {
      final String v => v,
      _ => '',
    };
    final line = e['line'] as int? ?? 0;
    out.items.add(
      Finding(
        file: s('file'),
        line: line > 0 && line < 1 << 31 ? line : 0,
        summary: s('summary'),
        shortSummary: s('short_summary'),
        failureScenario: s('failure_scenario'),
        category: s('category'),
        verdict: s('verdict'),
        outcome: s('outcome'),
      ),
    );
  }
  return out;
}

/// Each finding's id, the same however it reached the app and after a
/// reload: from its file, line and summary (a repeated finding gets `-2`,
/// `-3`). For later steps that pick findings, to send back to the agent or
/// to show as comments in the diff.
List<String> findingIds(List<Finding> findings) {
  final seen = <String, int>{};
  String numbered(String id) {
    final n = seen[id] = (seen[id] ?? 0) + 1;
    return n == 1 ? id : '$id-$n';
  }

  return [
    for (final f in findings)
      numbered(
        fnv1a(utf8.encode('${f.file}\n${f.line}\n${f.summary}'))
            .toRadixString(16)
            .padLeft(8, '0'),
      ),
  ];
}

/// Whether relative [path] climbs above its start with `..` at any point,
/// even to come back: such a finding names no file of the chat's.
bool _climbsOut(String path) {
  var depth = 0;
  for (final s in path.split('/')) {
    if (s == '..') {
      if (--depth < 0) return true;
    } else if (s.isNotEmpty && s != '.') {
      depth++;
    }
  }
  return false;
}

final Map<String, String?> _real = runMap();

/// [folder] with its links resolved (`/tmp` is `/private/tmp` on macOS),
/// as the agent may write it; null if it can't be, whatever the reason:
/// it runs in a card's build, which must not throw.
String? _realFolder(String folder) => _real.putIfAbsent(folder, () {
  try {
    return Directory(folder).resolveSymbolicLinksSync();
  } on Object {
    return null;
  }
});

/// A finding's [file] relative to the chat's [folder], to open there: a
/// relative path, or an absolute one inside the folder (or its real path).
/// Null for anything outside it, a `..` climbing out included. On the
/// phone the folder is the Mac's, matched only as written: the phone has
/// no such path to resolve, and dart:io throws on the web.
String? findingPath(String folder, String file) {
  if (!file.startsWith('/')) {
    // A relative name needs no folder: cleaned as from the root.
    return _climbsOut(file) ? null : insideOf('/', file);
  }
  for (final root in {folder, if (!kIsWeb) ?_realFolder(folder)}) {
    if (insideOf(root, file) case final inside?) return inside;
  }
  return null;
}

/// [file] shortened for a row: its last two segments, `…/` before them
/// when there were more.
String shortPath(String file) {
  final parts = file.split('/').where((s) => s.isNotEmpty).toList();
  return parts.length <= 2
      ? file
      : '…/${parts.sublist(parts.length - 2).join('/')}';
}
