import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:nushi/chat_paths.dart';
import 'package:nushi/preview_entry.dart';

/// A chat's open files (ADR 0070): their tabs in the order opened and the
/// one that shows. With none showing the Files pane's viewer is blank (ADR
/// 0123); the tabs outlive the pane hiding, and Nushi quitting ([kept],
/// [restore]). A file opened without keeping it (a click in the tree, with
/// preview tabs on) is [provisional], as VS Code's preview tab: the next
/// such open takes its place, until it's kept.
final class FileTabs {
  /// The tabs, in the order opened.
  final tabs = ValueNotifier<List<PreviewFile>>(const []);

  /// The tab that shows; null with none open.
  final shown = ValueNotifier<PreviewFile?>(null);

  /// The tab the next open without keeping takes the place of, shown in
  /// italics; at most one.
  final provisional = ValueNotifier<PreviewFile?>(null);

  /// The files whose view shows its Source, while its tab is open: a
  /// file's view is made again each time it shows. Changed by [showSource].
  final sources = <String>{};

  /// The files whose view shows Blame (issue #78), by their tabs' paths:
  /// off as a tab opens, gone as it closes, never kept across launches.
  /// Changed by [blame].
  final blamed = ValueNotifier<Set<String>>(const {});

  /// Turns [path]'s Blame on or off.
  void blame(String path, {required bool on}) {
    final now = {...blamed.value};
    if (on ? now.add(path) : now.remove(path)) blamed.value = now;
  }

  /// Counts [showSource]'s changes, for [changes].
  final _sourced = ValueNotifier<int>(0);

  /// Tells of every change to what [kept] gives.
  late final Listenable changes = Listenable.merge([
    tabs,
    shown,
    provisional,
    _sourced,
  ]);

  /// Shows [path]'s Source, or its rendering again.
  void showSource(String path, {required bool on}) {
    if (on ? sources.add(path) : sources.remove(path)) _sourced.value++;
  }

  /// Shows [path]: the tab of the same file if it has one, however each is
  /// named ([relativeIn] in [folder]: relative or absolute, with `.`, `..`
  /// and doubled slashes), kept if [keep]; else a new one, last, or without
  /// [keep] in the [provisional] tab's place, provisional itself.
  void open(String path, {required String folder, bool keep = true}) {
    final file = relativeIn(folder, path);
    final open = tabs.value
        .where((f) => relativeIn(folder, f.path) == file)
        .firstOrNull;
    if (open != null) {
      if (keep) this.keep(open);
      return show(open);
    }
    final tab = PreviewFile(path);
    final old = provisional.value;
    final at = old == null ? -1 : tabs.value.indexOf(old);
    if (!keep && at >= 0) {
      sources.remove(old!.path);
      blame(old.path, on: false);
      provisional.value = tab;
      tabs.value = [...tabs.value]..[at] = tab;
      shown.value = tab;
      return;
    }
    show(tab);
    if (!keep) provisional.value = tab;
  }

  /// Keeps [tab]: no later open takes its place.
  void keep(PreviewFile tab) {
    if (provisional.value == tab) provisional.value = null;
  }

  /// Shows [tab], adding it last if it isn't open.
  void show(PreviewFile tab) {
    if (!tabs.value.contains(tab)) tabs.value = [...tabs.value, tab];
    shown.value = tab;
  }

  /// Closes [tab]. If it showed, the one after it shows, or the last; with
  /// none left none shows.
  void close(PreviewFile tab) {
    final at = tabs.value.indexOf(tab);
    if (at < 0) return;
    final rest = [...tabs.value]..removeAt(at);
    keep(tab);
    tabs.value = rest;
    sources.remove(tab.path);
    blame(tab.path, on: false);
    if (rest.isEmpty) {
      shown.value = null;
    } else if (shown.value == tab) {
      shown.value = rest[min(at, rest.length - 1)];
    }
  }

  /// The tabs to keep across launches, each named [relativeIn] [folder],
  /// so they're found again should the chat's folder move; null with none
  /// open.
  KeptTabs? kept(String folder) {
    if (tabs.value.isEmpty) return null;
    String? name(PreviewFile? f) =>
        f == null ? null : relativeIn(folder, f.path);
    return KeptTabs(
      [for (final f in tabs.value) name(f)!],
      shown: name(shown.value),
      provisional: name(provisional.value),
      sources: [
        for (final f in tabs.value)
          if (sources.contains(f.path)) name(f)!,
      ],
    );
  }

  /// Puts back [kept]'s tabs of the files still [there] (the others are
  /// gone), before any opened since, and shows the one that showed, or the
  /// nearest left: the next, else the last. A tab opened since keeps
  /// showing, and stands for a kept one of the same file.
  void restore(KeptTabs kept, Set<String> there, {required String folder}) {
    final open = {for (final f in tabs.value) relativeIn(folder, f.path)};
    final back = [
      for (final p in kept.tabs)
        if (there.contains(p) && !open.contains(p)) PreviewFile(p),
    ];
    if (back.isEmpty) return;
    sources.addAll([
      for (final p in kept.sources)
        if (back.contains(PreviewFile(p))) p,
    ]);
    tabs.value = [...back, ...tabs.value];
    if (kept.provisional case final p?
        when provisional.value == null && back.contains(PreviewFile(p))) {
      provisional.value = PreviewFile(p);
    }
    if (shown.value != null) return;
    if (kept.shown case final was?) {
      final at = kept.tabs.indexOf(was);
      shown.value =
          back.where((f) => kept.tabs.indexOf(f.path) >= at).firstOrNull ??
          back.last;
    }
  }
}

/// A chat's file tabs as kept across launches (`fileTabsKept`): their
/// names in order (relative to the chat's folder when inside it), the one
/// that shows, the provisional one, and those showing their Source. Not
/// where each is scrolled, nor unsaved edits.
@immutable
final class KeptTabs {
  const new(this.tabs, {this.shown, this.provisional, this.sources = const []});

  final List<String> tabs;
  final String? shown;
  final String? provisional;
  final List<String> sources;

  /// What's saved, as JSON.
  Map<String, Object?> get json => {
    'tabs': tabs,
    'shown': ?shown,
    'provisional': ?provisional,
    if (sources.isNotEmpty) 'sources': sources,
  };

  /// [saved] read: null unless it's a map with a tab's name; a part of
  /// the wrong type, or naming no tab, is left out.
  static KeptTabs? read(Object? saved) {
    if (saved is! Map) return null;
    List<String> names(Object? v) => [
      if (v is List) ...v.whereType<String>().where((s) => s.isNotEmpty),
    ];
    final tabs = names(saved['tabs']).toSet().toList();
    if (tabs.isEmpty) return null;
    String? one(Object? v) => v is String && tabs.contains(v) ? v : null;
    return KeptTabs(
      tabs,
      shown: one(saved['shown']),
      provisional: one(saved['provisional']),
      sources: [...names(saved['sources']).where(tabs.contains)],
    );
  }
}
