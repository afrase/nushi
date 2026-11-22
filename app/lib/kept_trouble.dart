import 'package:flutter/foundation.dart';

/// What went wrong reading a file the app keeps (`readKept`,
/// `file_mode.dart`): set aside whole (it didn't parse), copied aside
/// (some of its records didn't read and were dropped), or can't be read
/// at all (nothing is saved over it until it can).
enum KeptTroubleKind { setAside, copiedAside, unread }

/// One file's trouble: its name in the data folder, what happened, and
/// the name of the copy kept beside it, if one was.
typedef KeptTrouble = ({String file, KeptTroubleKind kind, String? aside});

/// The troubles met in this run, one a file and kind, in the order they
/// came: the Mac's and Linux's window says each once (`KeptNotices`).
final keptTroubles = ValueNotifier<List<KeptTrouble>>(const []);

/// Notes [kind] of trouble with the kept file [file] (its name), unless
/// it was noted already in this run.
void noteKeptTrouble(String file, KeptTroubleKind kind, {String? aside}) {
  if (keptTroubles.value.any((t) => t.file == file && t.kind == kind)) return;
  keptTroubles.value = [
    ...keptTroubles.value,
    (file: file, kind: kind, aside: aside),
  ];
}

/// Each kept file's plain name: what the app keeps in it.
const _named = {
  'app.json': 'settings',
  'drafts.json': 'drafts',
  'reviews.json': 'review comments',
  'comment_drafts.json': 'comment drafts',
};

/// What the window says of [t], in plain words.
String keptTroubleText(KeptTrouble t) {
  final what = _named[t.file] ?? t.file;
  final lost = t.file == 'app.json'
      ? 'settings are back to their defaults'
      : '$what start empty';
  return switch (t.kind) {
    KeptTroubleKind.setAside =>
      'Nushi couldn’t read its $what file, so $lost. '
          'The old file is kept as ${t.aside}.',
    KeptTroubleKind.copiedAside =>
      'Nushi couldn’t read some of its $what file, so some $what are '
          'missing. A copy of the file is kept as ${t.aside}.',
    KeptTroubleKind.unread =>
      'Nushi can’t read its $what file, so changes to $what won’t be '
          'saved until it can.',
  };
}

/// No trouble noted (tests: each starts with none).
@visibleForTesting
void forgetKeptTroubles() => keptTroubles.value = const [];
