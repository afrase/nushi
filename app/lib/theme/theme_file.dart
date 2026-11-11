import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:nushi/theme/diff_colors.dart';
import 'package:nushi/theme/terminal_colors.dart';
import 'package:nushi/theme/themes.dart';
import 'package:nushi/theme/tokens.dart';

/// A theme file read (ADR 0086): [theme] unless it couldn't be used at all,
/// and [notes], what was wrong with it (a key that's no token, a value
/// that's no color), each a line for Settings.
@immutable
class ThemeFile {
  const new({required this.file, required this.notes, this.theme});

  /// Its file name, `Midnight.json`.
  final String file;
  final ColorTheme? theme;
  final List<String> notes;
}

/// The most a theme file may hold: every token twice is about 9 KB.
const int themeFileLimit = 64 * 1024;

/// The names of chat colors in a theme file (`avatars.blue`), in
/// `ChatColor`'s order.
const List<String> avatarNames = [
  'blue',
  'teal',
  'violet',
  'amber',
  'rust',
  'magenta',
  'slate',
  'green',
];

/// Every color of [t] by its name in a theme file: the tokens by their
/// own names, then `avatars.<name>`, `syntax.<capture>`, `terminal.<ansi>`
/// and `diff.<part>`.
Map<String, Color> tokenColors(Tokens t) {
  final out = <String, Color>{};
  _rebuild(t, (name, c) => out[name] = c);
  return out;
}

/// [t] with [colors] (by [tokenColors]' names) in place of its own; a name
/// it doesn't have is left out.
///
/// A surface [colors] doesn't name follows the one it's drawn from when
/// they name that (ADR 0111): `window` follows `base`, `lifted` and
/// `segment` follow `raised` (a light set's `segment` its `base`), `line`
/// and `quote` follow `text`. So a file from before those tokens, which
/// names every color it knew, gets a window and a hairline of its own
/// palette rather than the built-in's it starts from.
Tokens withColors(Tokens t, Map<String, Color> colors) {
  bool follows(String name, List<String> sources) =>
      !colors.containsKey(name) && sources.any(colors.containsKey);
  return _rebuild(
    t,
    (name, c) => colors[name] ?? c,
    derived: {
      if (follows('window', ['base', 'text'])) 'window',
      if (follows('lifted', ['raised', 'text'])) 'lifted',
      if (follows('segment', ['raised', 'base', 'text'])) 'segment',
      if (follows('line', ['text'])) 'line',
      if (follows('quote', ['text'])) 'quote',
    },
  );
}

/// Reads a theme file: `{"name", "from", "dark", "light"}`, the sets
/// mapping token names to `#RRGGBB` or `#AARRGGBB`; `from` names the
/// built-in it starts from (Nushi's unless it says). Never throws: what's
/// wrong is in the notes, and a file that's no JSON object has no theme.
ThemeFile readThemeFile(String file, String text) {
  final stem = file.endsWith('.json')
      ? file.substring(0, file.length - 5)
      : file;
  final notes = <String>[];
  ThemeFile none(String why) => ThemeFile(file: file, notes: [why]);
  if (text.length > themeFileLimit) {
    return none('Over ${themeFileLimit ~/ 1024} KB: not read.');
  }
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    return none('Isn’t JSON: ${e.message}.');
  }
  if (json is! Map<String, Object?>) return none('Isn’t a JSON object.');
  final fields = json;
  var name = stem;
  var from = nushiTheme;
  for (final MapEntry(:key, :value) in fields.entries) {
    switch (key) {
      case 'name':
        if (value is String && value.trim().isNotEmpty) {
          name = _clip(value.trim(), 40);
        } else {
          notes.add('"name" isn’t text: the file’s name is used.');
        }
      case 'from':
        if (value is String && builtInTheme(value) != null) {
          from = builtInTheme(value)!;
        } else {
          final ids = [for (final t in builtInThemes) t.id].join(', ');
          notes.add(
            '"from" names no built-in theme ($ids): '
            'Nushi’s is used.',
          );
        }
      case 'dark' || 'light':
        break;
      default:
        notes.add('"${_clip(key, 40)}" means nothing here: ignored.');
    }
  }
  Tokens set(String which, Tokens base) {
    final given = fields[which];
    if (given == null) return base;
    if (given is! Map<String, Object?>) {
      notes.add('"$which" isn’t an object: ignored.');
      return base;
    }
    final known = tokenColors(base);
    final colors = <String, Color>{};
    for (final MapEntry(:key, :value) in given.entries) {
      final where = '$which.${_clip(key, 40)}';
      if (!known.containsKey(key)) {
        notes.add('"$where" is no token: ignored.');
      } else if (_color(value) case final c?) {
        colors[key] = c;
      } else {
        notes.add('"$where" isn’t #RRGGBB or #AARRGGBB: ignored.');
      }
    }
    return withColors(base, colors);
  }

  return ThemeFile(
    file: file,
    notes: notes,
    theme: ColorTheme(
      id: '${ColorTheme.customPrefix}$stem',
      name: name,
      dark: set('dark', from.dark),
      light: set('light', from.light),
    ),
  );
}

/// A theme file holding every token of [theme], named [name], to edit:
/// `from` is the built-in it is, or Nushi's for one of the user's (every
/// token is there anyway).
String writeThemeFile(ColorTheme theme, String name) {
  Map<String, String> colors(Tokens t) => {
    for (final MapEntry(:key, :value) in tokenColors(t).entries)
      key: hexColor(value),
  };
  final file = {
    'name': name,
    'from': theme.custom ? nushiTheme.id : theme.id,
    'dark': colors(theme.dark),
    'light': colors(theme.light),
  };
  return '${const JsonEncoder.withIndent('  ').convert(file)}\n';
}

/// [c] as a theme file writes it: `#RRGGBB`, or `#AARRGGBB` when it's not
/// opaque.
String hexColor(Color c) {
  final v = c.toARGB32();
  final hex = v.toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${hex.startsWith('FF') ? hex.substring(2) : hex}';
}

final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

Color? _color(Object? v) {
  if (v is! String || !_hex.hasMatch(v)) return null;
  final digits = v.substring(1);
  return Color(int.parse(digits.length == 6 ? 'FF$digits' : digits, radix: 16));
}

String _clip(String s, int n) {
  final shown = shownText(s);
  return shown.length > n ? '${shown.substring(0, n)}…' : shown;
}

final _hidden = RegExp(r'[\p{Cc}\p{Cf}]', unicode: true);

/// [s] without control and format characters (bidi marks among them): a
/// theme file's words as Settings shows them.
String shownText(String s) => s.replaceAll(_hidden, '');

/// [t] built again, each color what [pick] makes of its name and its value
/// in [t]: one list of the tokens for [tokenColors] and [withColors]. A
/// surface named in [derived] is left for the set to work out from the
/// others ([Tokens.window] and the like).
Tokens _rebuild(
  Tokens t,
  Color Function(String name, Color c) pick, {
  Set<String> derived = const {},
}) {
  final a = t.terminal;
  final d = t.diff;
  Color? surface(String name, Color c) =>
      derived.contains(name) ? null : pick(name, c);
  return Tokens(
    brightness: t.brightness,
    window: surface('window', t.window),
    base: pick('base', t.base),
    raised: pick('raised', t.raised),
    lifted: surface('lifted', t.lifted),
    segment: surface('segment', t.segment),
    line: surface('line', t.line),
    selected: pick('selected', t.selected),
    borderSubtle: pick('borderSubtle', t.borderSubtle),
    borderStrong: pick('borderStrong', t.borderStrong),
    text: pick('text', t.text),
    textSecondary: pick('textSecondary', t.textSecondary),
    textMuted: pick('textMuted', t.textMuted),
    link: pick('link', t.link),
    onAccent: pick('onAccent', t.onAccent),
    fieldFill: pick('fieldFill', t.fieldFill),
    fieldBorder: pick('fieldBorder', t.fieldBorder),
    fieldBorderHover: pick('fieldBorderHover', t.fieldBorderHover),
    grip: pick('grip', t.grip),
    accent: pick('accent', t.accent),
    accentSoft: pick('accentSoft', t.accentSoft),
    accentInk: pick('accentInk', t.accentInk),
    running: pick('running', t.running),
    needs: pick('needs', t.needs),
    needsSoft: pick('needsSoft', t.needsSoft),
    done: pick('done', t.done),
    doneSoft: pick('doneSoft', t.doneSoft),
    idle: pick('idle', t.idle),
    crashed: pick('crashed', t.crashed),
    crashedSoft: pick('crashedSoft', t.crashedSoft),
    shine: pick('shine', t.shine),
    shineBand: pick('shineBand', t.shineBand),
    userBand: pick('userBand', t.userBand),
    userBandBorder: pick('userBandBorder', t.userBandBorder),
    userBandText: pick('userBandText', t.userBandText),
    userBandMuted: pick('userBandMuted', t.userBandMuted),
    userBandCode: pick('userBandCode', t.userBandCode),
    userBandCodeBlock: pick('userBandCodeBlock', t.userBandCodeBlock),
    agentText: pick('agentText', t.agentText),
    inlineCode: pick('inlineCode', t.inlineCode),
    inlineCodeText: pick('inlineCodeText', t.inlineCodeText),
    codeBlock: pick('codeBlock', t.codeBlock),
    toolTint: pick('toolTint', t.toolTint),
    toolBorder: pick('toolBorder', t.toolBorder),
    toolAccent: pick('toolAccent', t.toolAccent),
    subagentTint: pick('subagentTint', t.subagentTint),
    subagentBorder: pick('subagentBorder', t.subagentBorder),
    subagentAccent: pick('subagentAccent', t.subagentAccent),
    findingsTint: pick('findingsTint', t.findingsTint),
    findingsBorder: pick('findingsBorder', t.findingsBorder),
    findingsAccent: pick('findingsAccent', t.findingsAccent),
    selectionBar: pick('selectionBar', t.selectionBar),
    selectionBarText: pick('selectionBarText', t.selectionBarText),
    selectionBarBorder: pick('selectionBarBorder', t.selectionBarBorder),
    selectionBarDivider: pick('selectionBarDivider', t.selectionBarDivider),
    shadow: pick('shadow', t.shadow),
    scrim: pick('scrim', t.scrim),
    stop: pick('stop', t.stop),
    onStop: pick('onStop', t.onStop),
    claude: pick('claude', t.claude),
    ante: pick('ante', t.ante),
    ompPlug: pick('ompPlug', t.ompPlug),
    pi: pick('pi', t.pi),
    pig: pick('pig', t.pig),
    monogramText: pick('monogramText', t.monogramText),
    hover: pick('hover', t.hover),
    pressed: pick('pressed', t.pressed),
    quote: surface('quote', t.quote),
    avatars: [
      for (final (i, c) in t.avatars.indexed)
        pick('avatars.${avatarNames[i]}', c),
    ],
    syntax: {
      for (final MapEntry(key: k, value: ink) in t.syntax.entries)
        k: CodeInk(
          pick('syntax.${k.name}', ink.color),
          italic: ink.italic,
          bold: ink.bold,
        ),
    },
    terminal: TerminalColors(
      black: pick('terminal.black', a.black),
      red: pick('terminal.red', a.red),
      green: pick('terminal.green', a.green),
      yellow: pick('terminal.yellow', a.yellow),
      blue: pick('terminal.blue', a.blue),
      magenta: pick('terminal.magenta', a.magenta),
      cyan: pick('terminal.cyan', a.cyan),
      white: pick('terminal.white', a.white),
      brightBlack: pick('terminal.brightBlack', a.brightBlack),
      brightRed: pick('terminal.brightRed', a.brightRed),
      brightGreen: pick('terminal.brightGreen', a.brightGreen),
      brightYellow: pick('terminal.brightYellow', a.brightYellow),
      brightBlue: pick('terminal.brightBlue', a.brightBlue),
      brightMagenta: pick('terminal.brightMagenta', a.brightMagenta),
      brightCyan: pick('terminal.brightCyan', a.brightCyan),
      brightWhite: pick('terminal.brightWhite', a.brightWhite),
    ),
    diff: DiffColors(
      background: pick('diff.background', d.background),
      text: pick('diff.text', d.text),
      gutterBackground: pick('diff.gutterBackground', d.gutterBackground),
      gutterText: pick('diff.gutterText', d.gutterText),
      gutterTextChanged: pick('diff.gutterTextChanged', d.gutterTextChanged),
      insertedLine: pick('diff.insertedLine', d.insertedLine),
      insertedWord: pick('diff.insertedWord', d.insertedWord),
      deletedLine: pick('diff.deletedLine', d.deletedLine),
      deletedWord: pick('diff.deletedWord', d.deletedWord),
      modifiedLine: pick('diff.modifiedLine', d.modifiedLine),
      modifiedWord: pick('diff.modifiedWord', d.modifiedWord),
      ribbonInserted: pick('diff.ribbonInserted', d.ribbonInserted),
      ribbonDeleted: pick('diff.ribbonDeleted', d.ribbonDeleted),
      ribbonModified: pick('diff.ribbonModified', d.ribbonModified),
      dividerBackground: pick('diff.dividerBackground', d.dividerBackground),
      selection: pick('diff.selection', d.selection),
      selectionOverCap: pick('diff.selectionOverCap', d.selectionOverCap),
      foldPlaceholderBackground: pick(
        'diff.foldPlaceholderBackground',
        d.foldPlaceholderBackground,
      ),
      foldPlaceholderText: pick(
        'diff.foldPlaceholderText',
        d.foldPlaceholderText,
      ),
      loadingBar: pick('diff.loadingBar', d.loadingBar),
      hoverAffordance: pick('diff.hoverAffordance', d.hoverAffordance),
    ),
  );
}
