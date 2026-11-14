// The component gallery (docs/design.md): every shared control in every
// state, one sheet per group, drawn in a theme's set. `make gallery` writes
// every sheet in both brightnesses to app/build/gallery
// (`test/screenshots/gallery.dart`); `gallery_test.dart` keeps a few as
// goldens, so a change to a component shows in review. The states are
// forced with `ShowLook`, so a sheet holds them all at once.
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/cards.dart' show NeedsYou;
import 'package:nushi/chat.dart';
import 'package:nushi/chat_colors.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/github_card.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/phase_pill.dart';
import 'package:nushi/settings_rows.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

import '../harness.dart';

/// One sheet: its name (the PNG's), the window it's drawn in, what it
/// draws, and what opens on it once drawn (a menu, a dialog), if anything.
typedef Sheet = ({
  String name,
  Size size,
  Widget Function() build,
  Future<void> Function(WidgetTester tester)? open,
});

/// The states a control is drawn in, left to right.
const states = ['rest', 'hover', 'focused', 'pressed', 'disabled'];

/// A control that can be drawn pressable or not.
typedef Make = Widget Function({required bool on});

void _tap() {}

/// [make] in each of [states], under [label]'s name, in [size].
Widget stateRow(String label, Make make, {ControlSize? size}) {
  Widget cell(String s) {
    final control = ShowLook(
      look: (
        hover: s == 'hover',
        focus: s == 'focused',
        pressed: s == 'pressed',
      ),
      child: make(on: s != 'disabled'),
    );
    return SizedBox(
      width: 190,
      child: Align(
        alignment: Alignment.centerLeft,
        child: size == null
            ? control
            : ControlScale(size: size, child: control),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 200, child: _Label(label)),
        for (final s in states) cell(s),
      ],
    ),
  );
}

/// What things are side by side, with no states: [items], each named.
Widget plainRow(String label, List<(String, Widget)> items) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 200, child: _Label(label)),
      Expanded(
        child: Wrap(
          spacing: 24,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (name, w) in items)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [w, _Label(name, small: true)],
              ),
          ],
        ),
      ),
    ],
  ),
);

/// A group's heading on a sheet, with the states' names over their
/// columns when [columns].
Widget heading(String text, {bool columns = true}) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 6),
  child: Row(
    children: [
      SizedBox(width: 200, child: _Label(text, strong: true)),
      if (columns)
        for (final s in states)
          SizedBox(width: 190, child: _Label(s, small: true)),
    ],
  ),
);

class _Label extends StatelessWidget {
  const new(this.text, {this.strong = false, this.small = false});

  final String text;
  final bool strong;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Text(
      text,
      style: theme.ui(
        strong ? t.text : t.textMuted,
        size: small ? 11 : 12,
        weight: strong ? FontWeight.w600 : null,
      ),
    );
  }
}

/// A sheet's page: its title and [children] on a pane.
Widget page(String title, List<Widget> children) => Builder(
  builder: (context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return ColoredBox(
      color: t.base,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.ui(t.text, size: 16, weight: FontWeight.w600),
            ),
            ...children,
          ],
        ),
      ),
    );
  },
);

List<MenuEntry> _entries(bool on) => [
  if (on) ...[
    const MenuEntry('Opus', onPick: _tap, checked: true),
    const MenuEntry('Sonnet', onPick: _tap),
  ],
];

Widget _buttons() => page('Buttons', [
  for (final size in ControlSize.values) ...[
    heading('Button, ${size.name} (${size.height.round()})'),
    for (final kind in ButtonKind.values)
      stateRow(
        kind.name,
        ({required on}) => Button(
          label: kind == ButtonKind.primary ? 'Done' : 'Show logs',
          kind: kind,
          onPressed: on ? _tap : null,
        ),
        size: size,
      ),
  ],
  heading('Button parts (regular)'),
  stateRow(
    'icon',
    ({required on}) => Button(
      label: 'Open',
      icon: Icons.open_in_new,
      onPressed: on ? _tap : null,
    ),
  ),
  stateRow(
    'hint',
    ({required on}) => Button(
      label: 'Send',
      kind: ButtonKind.primary,
      hint: '⌘N',
      onPressed: on ? _tap : null,
    ),
  ),
  stateRow(
    'MenuButton',
    ({required on}) => MenuButton(label: 'Start work', entries: _entries(on)),
  ),
  stateRow(
    'SplitButton',
    ({required on}) => SplitButton(
      label: 'Squash and merge',
      entries: _entries(on),
      onPressed: on ? _tap : null,
    ),
  ),
  stateRow(
    'SendButton',
    ({required on}) =>
        SendButton(label: 'Send to agent', onPressed: on ? _tap : null),
  ),
  stateRow(
    'WideButton',
    ({required on}) => SizedBox(
      width: 170,
      child: WideButton(
        label: 'New chat',
        icon: Icons.edit_outlined,
        hint: '⌘N',
        onPressed: on ? _tap : null,
      ),
    ),
  ),
]);

Widget _small() => page('Icon buttons, links, rows', [
  heading('IconTap (26; header 32)'),
  stateRow(
    'plain',
    ({required on}) =>
        IconTap(Icons.refresh, tooltip: 'Reload', onTap: on ? _tap : null),
  ),
  stateRow(
    'line, header',
    ({required on}) => IconTap.line(
      LineIcon.terminal,
      tooltip: 'Terminal',
      padding: IconTap.header,
      onTap: on ? _tap : null,
    ),
  ),
  stateRow(
    'held',
    ({required on}) => IconTap(
      Icons.push_pin_outlined,
      tooltip: 'Unpin',
      held: true,
      onTap: on ? _tap : null,
    ),
  ),
  stateRow(
    'lit',
    ({required on}) => IconTap.line(
      LineIcon.details,
      tooltip: 'Details',
      lit: true,
      onTap: on ? _tap : null,
    ),
  ),
  stateRow(
    'danger (Stop)',
    ({required on}) => IconTap(
      Icons.stop,
      tooltip: 'Stop',
      danger: true,
      onTap: on ? _tap : null,
    ),
  ),
  stateRow(
    'working',
    ({required on}) => IconTap.working(
      (size, color) => SizedBox.square(
        dimension: size,
        child: Spinner(color: color),
      ),
      Icons.close,
      tooltip: 'Stop',
      onTap: on ? _tap : null,
    ),
  ),
  stateRow(
    'MenuIcon',
    ({required on}) =>
        MenuIcon.line(LineIcon.more, tooltip: 'More', entries: _entries(on)),
  ),
  heading('Links'),
  stateRow(
    'LinkText',
    ({required on}) => LinkText('Settings › Agents', onTap: on ? _tap : null),
  ),
  stateRow(
    'PillLink',
    ({required on}) => PillLink('NUS-142', mono: true, onTap: on ? _tap : null),
  ),
  heading('Tap (rows and tabs)'),
  stateRow('plain', _row),
  stateRow('selected', ({required on}) => _row(on: on, selected: true)),
  stateRow(
    'fill',
    ({required on}) => Builder(
      builder: (context) =>
          _row(on: on, fill: NushiTheme.of(context).t.accentSoft),
    ),
  ),
  heading('Swatch'),
  stateRow(
    'color',
    ({required on}) => Builder(
      builder: (context) => Swatch(
        color: NushiTheme.of(context).t.avatars.first,
        tooltip: 'Blue',
        onTap: on ? _tap : null,
      ),
    ),
  ),
  stateRow(
    'none, picked',
    ({required on}) => Swatch(
      color: null,
      tooltip: 'No color',
      selected: true,
      onTap: on ? _tap : null,
    ),
  ),
  heading('Keys and grips', columns: false),
  plainRow('', [
    ('KeyCap', const KeyCap('⌘N')),
    ('keyHint', Builder(builder: (context) => keyHint(context, '⌘K'))),
    ('DragGrip', const DragGrip()),
  ]),
]);

Widget _row({required bool on, bool selected = false, Color? fill}) => SizedBox(
  width: 170,
  child: Tap(
    onTap: on ? _tap : null,
    selected: selected,
    fill: fill,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Builder(
      builder: (context) {
        final theme = NushiTheme.of(context);
        return Text('Paginate the feed', style: theme.ui(theme.t.text));
      },
    ),
  ),
);

Widget _fields() => page('Fields and pickers', [
  heading('MenuField'),
  for (final size in ControlSize.values)
    stateRow(
      'MenuField, ${size.name}',
      ({required on}) =>
          MenuField(label: const Text('JetBrains Mono'), entries: _entries(on)),
      size: size,
    ),
  stateRow(
    'MenuField compact',
    ({required on}) => MenuField(
      compact: true,
      label: const Text('Only me'),
      entries: _entries(on),
    ),
  ),
  stateRow(
    'MenuField pill',
    ({required on}) => MenuField(
      pill: true,
      label: const Text('Accept edits'),
      entries: _entries(on),
    ),
  ),
  heading('Segmented'),
  for (final size in ControlSize.values)
    stateRow(
      size.name,
      ({required on}) => Segmented(
        value: 'user',
        segments: const [('user', 'User'), ('project', 'Project')],
        onChanged: (_) {},
      ),
      size: size,
    ),
  stateRow(
    'roomy (header)',
    ({required on}) => Segmented(
      value: 'chat',
      roomy: true,
      segments: const [('chat', 'Chat'), ('changes', 'Changes')],
      badges: const {'changes': '2'},
      onChanged: (_) {},
    ),
  ),
  heading('Text fields, switches, a slider', columns: false),
  plainRow('TextField', [
    ('value', _field(text: 'npx')),
    ('hint', _field(hint: 'my-server')),
    ('value, code', _field(text: 'npx', code: true)),
    ('hint, code', _field(hint: 'npx', code: true)),
    ('error', _field(text: 'my server', error: true)),
    ('disabled', _field(text: 'github', enabled: false)),
  ]),
  plainRow('switch', [
    ('on', const SettingsSwitch(value: true, onChanged: _toggle)),
    ('off', const SettingsSwitch(value: false, onChanged: _toggle)),
    ('disabled', const SettingsSwitch(value: true)),
  ]),
  plainRow('checkbox', [
    ('on', Checkbox(value: true, onChanged: (_) {})),
    ('off', Checkbox(value: false, onChanged: (_) {})),
  ]),
  plainRow('LineSlider', [
    (
      'half',
      SizedBox(
        width: 160,
        child: LineSlider(value: 0.5, label: 'Zoom', onChanged: (_) {}),
      ),
    ),
  ]),
]);

void _toggle(bool _) {}

Widget _field({
  String text = '',
  String? hint,
  bool error = false,
  bool enabled = true,
  bool code = false,
}) => Builder(
  builder: (context) {
    final theme = NushiTheme.of(context);
    return SizedBox(
      width: 170,
      child: TextField(
        controller: TextEditingController(text: text),
        enabled: enabled,
        // In the Code font, as the MCP form's command.
        style: code ? theme.code(theme.t.text) : null,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error ? '' : null,
        ),
      ),
    );
  },
);

Widget _pills() => page('Pills, chips, cards', [
  heading('PillButton (32; small 24)'),
  stateRow(
    'plain',
    ({required on}) => PillButton(
      label: 'Stop and send',
      icon: Icons.fast_forward,
      onPressed: on ? _tap : null,
    ),
  ),
  stateRow(
    'small',
    ({required on}) => PillButton(
      label: 'Preview',
      icon: Icons.visibility_outlined,
      small: true,
      onPressed: on ? _tap : null,
    ),
  ),
  stateRow(
    'small, on',
    ({required on}) => PillButton(
      label: 'Preview',
      icon: Icons.visibility_outlined,
      small: true,
      on: true,
      onPressed: on ? _tap : null,
    ),
  ),
  heading('RoundButton (32)'),
  for (final kind in RoundKind.values)
    stateRow(
      kind.name,
      ({required on}) => RoundButton(
        kind: kind,
        tooltip: 'Send',
        onPressed: on ? _tap : null,
        glyph: (color) => Icon(Icons.arrow_upward, size: 17, color: color),
      ),
    ),
  heading('States', columns: false),
  plainRow('PhasePill', [
    for (final p in ChatPhase.values) (p.name, PhasePill(p)),
  ]),
  plainRow('small', [
    ('NeedsYou', const NeedsYou()),
    (ChatPhase.done.name, const PhasePill(ChatPhase.done, small: true)),
  ]),
  plainRow('StatePill', [
    for (final (name, state, draft) in [
      ('open', 'open', false),
      ('draft', 'open', true),
      ('merged', 'merged', false),
      ('closed', 'closed', false),
    ])
      (name, ItemStatePill(_item(state, draft: draft))),
  ]),
  plainRow('ColorChip', [
    for (final c in ChatColor.values.take(5)) (c.label, ColorChip(c)),
  ]),
  heading('Surfaces', columns: false),
  plainRow('', [
    ('cardBox', _surface(cardBox)),
    ('floatBox', _surface(floatBox)),
    (
      'framed',
      Builder(
        builder: (context) => framed(
          border: NushiTheme.of(context).t.line,
          child: const SizedBox(width: 120, height: 56),
        ),
      ),
    ),
    (
      'codeBlock',
      _surface(
        (t) => BoxDecoration(
          color: t.codeBlock,
          borderRadius: BorderRadius.circular(NushiTheme.control),
        ),
      ),
    ),
  ]),
  plainRow('Notice', [
    (
      'with an action',
      const SizedBox(
        width: 420,
        child: Notice(
          'Updated 3m ago: GitHub didn’t answer.',
          action: 'Retry',
          onAction: _tap,
        ),
      ),
    ),
  ]),
]);

Widget _surface(BoxDecoration Function(Tokens t) box) => Builder(
  builder: (context) => Container(
    width: 120,
    height: 56,
    decoration: box(NushiTheme.of(context).t),
  ),
);

GitHubItem _item(String state, {bool draft = false}) => GitHubItem(
  ref: GitHubRef(host: 'github.com', repo: 'maya/shop', number: 12),
  pull: true,
  state: state,
  draft: draft,
  title: 'Paginate the feed',
  createdMs: Int64(fixtureNow.millisecondsSinceEpoch),
);

Widget _settings() => page('Text, settings rows, empty states', [
  // The greys, strongest to faintest (docs/design.md's Text).
  Builder(
    builder: (context) {
      final theme = NushiTheme.of(context);
      final t = theme.t;
      return Row(
        spacing: 24,
        children: [
          for (final (name, color) in [
            ('text', t.text),
            ('textSecondary', t.textSecondary),
            ('textMuted', t.textMuted),
            ('hint', t.hint),
          ])
            Text(name, style: theme.ui(color)),
        ],
      );
    },
  ),
  const SizedBox(height: 8),
  // The type scale, every step (docs/design.md's Type).
  Builder(
    builder: (context) {
      final theme = NushiTheme.of(context);
      return Row(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (name, size) in const [
            ('20', 20.0),
            ('15', 15.0),
            ('14', 14.0),
            ('13', 13.0),
            ('12', 12.0),
            ('11.5', 11.5),
          ])
            Text(name, style: theme.ui(theme.t.text, size: size)),
          Text('11 code', style: theme.code(theme.t.text, size: 11)),
        ],
      );
    },
  ),
  const SizedBox(height: 12),
  SizedBox(
    width: 640,
    child: SettingsGroup(
      title: 'Agents',
      about: 'What each agent runs with.',
      footer: Builder(
        builder: (context) {
          final theme = NushiTheme.of(context);
          return Text(
            'A footer says what the group does.',
            style: theme.ui(theme.t.textMuted, size: 12),
          );
        },
      ),
      children: [
        const SettingsRow(
          'Sleep idle chats',
          description: 'After 30 minutes without a turn.',
          control: SettingsSwitch(value: true, onChanged: _toggle),
        ),
        SettingsRow(
          'Default agent',
          control: MenuField(
            label: const Text('Claude'),
            entries: _entries(true),
          ),
        ),
        const SettingsRow(
          'Logs',
          description: 'nushid.log in the data folder.',
          control: Button(label: 'Show logs', onPressed: _tap),
        ),
      ],
    ),
  ),
  const SizedBox(height: 12),
  const SizedBox(
    width: 640,
    child: SettingsGroup(title: 'MCP servers', empty: 'None', children: []),
  ),
  const SizedBox(height: 8),
  // An empty state with what to do: a phrase, no full stop.
  Builder(
    builder: (context) {
      final theme = NushiTheme.of(context);
      return Text(
        'No inline comments: select lines in Files to add some',
        style: theme.ui(theme.t.textMuted),
      );
    },
  ),
]);

Widget _dialogs() => page('Dialogs', [
  const SizedBox(height: 12),
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 20,
    children: [
      nushiDialog('Rename chat', _field(text: 'Paginate the feed'), const [
        Button(label: 'Cancel', onPressed: _tap),
        Button(label: 'Rename', kind: ButtonKind.primary, onPressed: _tap),
      ]),
      nushiDialog(
        'Allowed sites',
        Builder(
          builder: (context) {
            final theme = NushiTheme.of(context);
            return Text(
              'A list to manage has a × at its title’s end.',
              style: theme.ui(theme.t.textSecondary),
            );
          },
        ),
        const [
          Button(label: 'Clear all', kind: ButtonKind.danger, onPressed: _tap),
          Button(label: 'Done', kind: ButtonKind.primary, onPressed: _tap),
        ],
        onClose: _tap,
        actionsAlignment: MainAxisAlignment.spaceBetween,
      ),
    ],
  ),
]);

/// confirm(), opened as the app opens it, over an empty pane.
Future<void> _openConfirm(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold));
  // The answer is never given: the sheet is drawn with it open.
  unawaited(
    confirm(
      context,
      'Delete this chat?',
      'Its transcript and its worktree go. The branch stays.',
      'Delete',
      destructive: true,
    ),
  );
  await tester.pumpAndSettle();
}

/// A menu open from its field, a tooltip with a key, and a toast.
Future<void> _openFloats(WidgetTester tester) async {
  await tester.tap(find.text('Opus').first);
  await tester.pumpAndSettle();
  tester
      .state<TooltipState>(
        find.descendant(
          of: find.byKey(const ValueKey('tip')),
          matching: find.byType(Tooltip),
        ),
      )
      .ensureTooltipVisible();
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold))).showSnackBar(
    const SnackBar(
      content: Text('Archived “Paginate the feed”'),
      action: SnackBarAction(label: 'Undo', onPressed: _tap),
      duration: Duration(days: 1),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _floats() => page('Menus, tooltips, toasts', [
  const SizedBox(height: 16),
  Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 260,
    children: [
      const MenuField(
        label: Text('Opus'),
        entries: [
          MenuEntry.heading('Model'),
          MenuEntry(
            'Opus',
            onPick: _tap,
            checked: true,
            detail: 'Most capable',
          ),
          MenuEntry('Sonnet', onPick: _tap, shortcut: '⌘2'),
          MenuEntry('Archive', icon: Icons.archive_outlined, onPick: _tap),
          MenuEntry('Delete…', onPick: _tap, danger: true),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: KeyedSubtree(
          key: const ValueKey('tip'),
          child: Builder(
            builder: (context) => tooltip(
              context,
              withKey('Stop', 'Esc'),
              const Text('A tooltip with its key'),
            ),
          ),
        ),
      ),
    ],
  ),
]);

/// Every sheet, in the order the gallery shows them.
final List<Sheet> sheets = [
  (name: 'buttons', size: const Size(1200, 1080), build: _buttons, open: null),
  (name: 'small', size: const Size(1200, 820), build: _small, open: null),
  (name: 'fields', size: const Size(1200, 940), build: _fields, open: null),
  (name: 'pills', size: const Size(1200, 860), build: _pills, open: null),
  (name: 'settings', size: const Size(760, 540), build: _settings, open: null),
  (name: 'dialogs', size: const Size(1340, 340), build: _dialogs, open: null),
  (
    name: 'confirm',
    size: const Size(760, 420),
    build: () =>
        page('confirm(destructive: true): Cancel has the focus', const []),
    open: _openConfirm,
  ),
  (
    name: 'floats',
    size: const Size(900, 420),
    build: _floats,
    open: _openFloats,
  ),
];

/// The Mac, where the gallery's controls are drawn: a menu's rows, a
/// tooltip's wait and a field's look are the platform's.
final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

/// [sheet] drawn in [tokens] at its size, and what it opens, opened: on a
/// pane, as `themed` draws a widget but without the debug banner, nothing
/// moving.
Future<void> drawSheet(WidgetTester tester, Sheet sheet, Tokens tokens) async {
  viewport(tester, sheet.size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: NushiTheme(tokens).toThemeData(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Scaffold(body: sheet.build()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await sheet.open?.call(tester);
}
