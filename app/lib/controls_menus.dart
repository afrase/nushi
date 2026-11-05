part of 'controls.dart';

/// Says the compact [MenuField]s below end flush with their room: a
/// panel widget's values, so a menu's ▾ lines up with the text values'
/// right edge.
class FlushMenus extends InheritedWidget {
  const new({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlushMenus>() != null;

  @override
  bool updateShouldNotify(FlushMenus oldWidget) => false;
}

/// A value picked from a list ([entries]) that looks it: [label] and a ▾
/// in a bordered box, the whole box the target. [compact], for a picker in
/// a header or a row ("Only me ▾"), drops the box but keeps the ▾ and a
/// tint under the pointer. With no [entries] it's disabled.
class MenuField extends StatelessWidget {
  const new({
    required this.label,
    required this.entries,
    super.key,
    this.compact = false,
    this.tooltip = '',
    this.digits = false,
    this.onOpen,
    this.onClose,
  });

  /// The value, usually a [Text]; styled as a field's unless it says.
  final Widget label;
  final List<MenuEntry> entries;
  final bool compact;
  final String tooltip;
  final bool digits;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final flush = compact && FlushMenus.of(context);
    final caret = Icon(
      Icons.keyboard_arrow_down,
      size: compact ? 14 : 15,
      color: t.textSecondary,
    );
    return Menu(
      entries: entries,
      digits: digits,
      onOpen: onOpen,
      onClose: onClose,
      builder: (context, open) => Pressable(
        onTap: entries.isEmpty ? null : open,
        tooltip: tooltip,
        builder: (context, look) {
          final face = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: DefaultTextStyle(
                  style: compact
                      ? theme.ui(t.textSecondary, size: 12)
                      : theme.ui(t.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: label,
                ),
              ),
              SizedBox(width: compact ? 1 : 6),
              // Flush, the glyph's own margin goes past the edge too.
              if (flush)
                Transform.translate(offset: const Offset(2, 0), child: caret)
              else
                caret,
            ],
          );
          return _faded(
            look,
            Container(
              height: compact ? null : controlHeight,
              padding: compact
                  ? EdgeInsets.fromLTRB(5, 1, flush ? 0 : 3, 1)
                  : const EdgeInsets.fromLTRB(8, 0, 5, 0),
              decoration: BoxDecoration(
                color: compact
                    ? (look.hover ? _tint(t, look) : null)
                    : (look.hover
                          ? Color.alphaBlend(_tint(t, look), t.fieldFill)
                          : t.fieldFill),
                border: compact
                    ? null
                    : Border.all(
                        color: look.hover ? t.fieldBorderHover : t.fieldBorder,
                      ),
                borderRadius: BorderRadius.circular(NushiTheme.control),
              ),
              foregroundDecoration: focusRing(t, look),
              child: face,
            ),
          );
        },
      ),
    );
  }
}

/// A button that opens a menu of what it can do ("Start work ▾");
/// [onOpener] takes the menu's opener (for a shortcut that opens it too).
class MenuButton extends StatelessWidget {
  const new({
    required this.label,
    required this.entries,
    super.key,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.tooltip = '',
    this.onOpener,
  });

  final String label;
  final List<MenuEntry> entries;
  final ButtonKind kind;
  final IconData? icon;
  final String tooltip;

  /// Given the menu's opener on each build.
  final void Function(OpenMenu open)? onOpener;

  @override
  Widget build(BuildContext context) => Menu(
    entries: entries,
    builder: (context, open) {
      onOpener?.call(open);
      return Button(
        label: label,
        kind: kind,
        icon: icon,
        tooltip: tooltip,
        menu: true,
        onPressed: entries.isEmpty ? null : open,
      );
    },
  );
}

/// An icon that opens a menu ("More": ⋯).
class MenuIcon extends StatelessWidget {
  const new(
    IconData this.icon, {
    required this.tooltip,
    required this.entries,
    super.key,
    this.size = 16,
    this.onClose,
    this.filter = true,
  }) : line = null;

  /// The same button with a drawn [LineIcon].
  const new line(
    LineIcon this.line, {
    required this.tooltip,
    required this.entries,
    super.key,
    this.size = 16,
    this.onClose,
    this.filter = true,
  }) : icon = null;

  final IconData? icon;
  final LineIcon? line;
  final String tooltip;
  final List<MenuEntry> entries;
  final double size;
  final VoidCallback? onClose;

  /// Whether a long list gets a filter field ([Menu.filter]).
  final bool filter;

  @override
  Widget build(BuildContext context) => Menu(
    entries: entries,
    onClose: onClose,
    filter: filter,
    builder: (context, open) {
      final onTap = entries.isEmpty ? null : open;
      return switch (line) {
        final line? => IconTap.line(
          line,
          tooltip: tooltip,
          size: size,
          onTap: onTap,
        ),
        null => IconTap(icon!, tooltip: tooltip, size: size, onTap: onTap),
      };
    },
  );
}
