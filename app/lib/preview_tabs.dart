import 'package:flutter/material.dart';

import 'package:nushi/chat.dart';
import 'package:nushi/chat_files.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// A chat's preview tabs in its header (ChatHeader): what each says, and
// which fit. A tab's view is PreviewPane's.

/// What the tab of [file] says: its name, with as much of its folder as
/// tells it from the others of that name in [files] ("plan.md · docs").
String tabLabel(String file, List<String> files) {
  final name = baseName(file);
  final others = [
    for (final f in files)
      if (f != file && baseName(f) == name) folderOf(f),
  ];
  final folder = folderOf(file);
  if (others.isEmpty || folder.isEmpty) return name;
  final parts = folder.split('/');
  for (var n = 1; n < parts.length; n++) {
    final hint = parts.sublist(parts.length - n).join('/');
    if (!others.any((o) => o == hint || o.endsWith('/$hint'))) {
      return '$name · $hint';
    }
  }
  return '$name · $folder';
}

/// How wide the tab saying [label] is in the header's [Segmented].
double tabWidth(BuildContext context, String label) {
  final theme = NushiTheme.of(context);
  final text = TextPainter(
    text: TextSpan(text: label, style: theme.ui(theme.t.text, size: 12)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = text.width.ceilToDouble();
  text.dispose();
  return width.clamp(0, Segmented.closableLabel) + Segmented.closableRest;
}

/// The room the "+2" overflow takes in the header.
const tabOverflowWidth = 40.0;

/// The preview tabs that fit in the header (`shown`, with the overflow if
/// there's any, `width` wide) and those that go in the overflow (`over`).
typedef FittedTabs = ({List<String> shown, List<String> over, double width});

/// None of the tabs, with no overflow.
const FittedTabs noTabs = (shown: [], over: [], width: 0);

/// As many of [files] in order as fit in [room], the [current] one always
/// among them: it's in place of those it doesn't fit beside. [widthOf] is
/// each one's width.
FittedTabs fitTabs(
  List<String> files,
  String? current,
  double Function(String file) widthOf,
  double room,
) {
  final widths = {for (final f in files) f: widthOf(f)};
  final all = widths.values.fold(0.0, (a, b) => a + b);
  if (all <= room) return (shown: files, over: const [], width: all);
  final most = room - tabOverflowWidth;
  final shown = <String>[];
  var used = 0.0;
  for (final f in files) {
    if (used + widths[f]! > most) break;
    shown.add(f);
    used += widths[f]!;
  }
  if (widths[current] case final w? when !shown.contains(current)) {
    while (shown.isNotEmpty && used + w > most) {
      used -= widths[shown.removeLast()]!;
    }
    shown.add(current!);
    used += w;
  }
  return (
    shown: shown,
    over: [
      for (final f in files)
        if (!shown.contains(f)) f,
    ],
    width: used + tabOverflowWidth,
  );
}

/// The close button of [file]'s row in a menu of tabs.
Widget closeTabMark(ChatState chat, String file) => IconTap(
  Icons.close,
  size: 13,
  padding: 3,
  tooltip: 'Close tab',
  onTap: () => chat.closeTab(file),
);
