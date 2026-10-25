import 'dart:async';

import 'package:flutter/material.dart';

import 'gen/nushi/v1/nushi.pb.dart' as pb;
import 'inline_edit.dart';
import 'terminals.dart';
import 'theme/theme.dart';
import 'widgets.dart';

/// Closes a terminal, asking first when a program other than the shell
/// runs in it.
Future<void> closeTerminal(
  BuildContext context,
  Terminals terms,
  pb.Terminal t,
) async {
  if (t.program.isNotEmpty &&
      !t.exited &&
      !await confirm(
        context,
        'Close this terminal?',
        '“${t.program}” is still running in it. Closing the terminal ends it.',
        'Close',
      )) {
    return;
  }
  if (context.mounted) await tryOrShow(context, () => terms.close(t.id));
}

/// The panel's tab bar: a tab per terminal (drag to reorder, double-click
/// to rename), "+" for a new one, and a button that hides the panel.
class TerminalTabs extends StatelessWidget {
  const new({
    super.key,
    required this.chatId,
    required this.terms,
    required this.list,
    required this.onHide,
  });

  final String chatId;
  final Terminals terms;
  final List<pb.Terminal> list;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => child,
              itemCount: list.length,
              onReorderItem: (from, to) => terms.move(chatId, from, to),
              footer: IconTap(
                Icons.add,
                tooltip: 'New terminal  ⌘T',
                onTap: () => tryOrShow(context, () => terms.open(chatId)),
              ),
              itemBuilder: (context, i) => ReorderableDragStartListener(
                key: ValueKey(list[i].id),
                index: i,
                child: _Tab(
                  info: list[i],
                  terms: terms,
                  active: list[i].id == terms.active[chatId],
                ),
              ),
            ),
          ),
          IconTap(
            Icons.keyboard_arrow_down,
            tooltip: 'Hide terminal  ⌃`',
            onTap: onHide,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const new({required this.info, required this.terms, required this.active});

  final pb.Terminal info;
  final Terminals terms;
  final bool active;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;
  bool _renaming = false;
  final _double = DoubleClick();

  // The first click shows the tab at once; a second renames (without
  // showing it again, which would hand the keyboard to the shell).
  void _tap() {
    if (_double()) return setState(() => _renaming = true);
    widget.terms.show(widget.info.chatId, widget.info.id);
  }

  void _done(String? name) {
    setState(() => _renaming = false);
    widget.terms.session(widget.info).focus.requestFocus();
    if (name != null && name != terminalName(widget.info)) {
      unawaited(
        tryOrShow(context, () => widget.terms.rename(widget.info.id, name)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final info = widget.info;
    final color = info.exited
        ? t.textMuted
        : widget.active
        ? t.text
        : t.textSecondary;
    final label = _renaming
        ? SizedBox(
            width: 160,
            child: InlineEdit(
              text: terminalName(info),
              style: theme.ui(t.text, size: 12),
              decoration: const InputDecoration.collapsed(hintText: 'Name'),
              onDone: _done,
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              terminalName(info),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.ui(color, size: 12),
            ),
          );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
        child: Tap(
          selected: widget.active,
          onTap: _tap,
          padding: const EdgeInsets.only(left: 9, right: 2),
          child: Row(
            children: [
              if (info.program.isNotEmpty && !info.exited) ...[
                // A command runs: not the agent, so only here.
                Tooltip(
                  message: 'A command is running',
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: t.running,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              label,
              if (info.exited) ...[
                const SizedBox(width: 6),
                Text(
                  info.exitCode < 0 ? 'killed' : 'exit ${info.exitCode}',
                  style: theme.code(t.textMuted, size: 11),
                ),
              ],
              Opacity(
                opacity: _hover || widget.active ? 1 : 0,
                child: IconTap(
                  Icons.close,
                  size: 12,
                  tooltip: 'Close  ⌘W',
                  onTap: () => closeTerminal(context, widget.terms, info),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
