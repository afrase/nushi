import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'gen/nushi/v1/nushi.pb.dart' as pb;
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
  const TerminalTabs({
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
  const _Tab({required this.info, required this.terms, required this.active});

  final pb.Terminal info;
  final Terminals terms;
  final bool active;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;
  TextEditingController? _rename; // while renaming
  DateTime _lastTap = DateTime(0);

  // A second click soon after the first renames; the first shows the tab
  // at once (a double-tap recognizer would hold every click back).
  void _tap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < kDoubleTapTimeout) {
      setState(
        () => _rename = TextEditingController(text: terminalName(widget.info))
          ..selection = TextSelection(
            baseOffset: 0,
            extentOffset: terminalName(widget.info).length,
          ),
      );
    }
    _lastTap = now;
    widget.terms.show(widget.info.chatId, widget.info.id);
  }

  void _done(bool save) {
    final name = _rename!.text.trim();
    setState(() => _rename = null);
    widget.terms.session(widget.info).focus.requestFocus();
    if (save && name != terminalName(widget.info)) {
      tryOrShow(context, () => widget.terms.rename(widget.info.id, name));
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
    final label = _rename != null
        ? SizedBox(
            width: 160,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    _done(false),
              },
              child: TextField(
                controller: _rename,
                autofocus: true,
                style: theme.ui(t.text, size: 12),
                decoration: const InputDecoration.collapsed(hintText: 'Name'),
                onSubmitted: (_) => _done(true),
                onTapOutside: (_) => _done(true),
              ),
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
