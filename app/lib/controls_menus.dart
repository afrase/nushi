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
/// on the lifted fill (ADR 0111), the whole box the target. [compact], for
/// a picker in a header or a row ("Only me ▾"), drops the fill but keeps
/// the ▾ and a tint under the pointer; [pill], the composer's, is that as
/// a pill [PillButton.height] high. With no [entries] it's disabled.
class MenuField extends StatelessWidget {
  const new({
    required this.label,
    required this.entries,
    super.key,
    this.compact = false,
    this.pill = false,
    this.tooltip = '',
    this.digits = false,
    this.onOpen,
    this.onClose,
  });

  /// The value, usually a [Text]; styled as a field's unless it says.
  final Widget label;
  final List<MenuEntry> entries;
  final bool compact;
  final bool pill;
  final String tooltip;
  final bool digits;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final compact = this.compact || pill;
    final size = ControlSize.of(context);
    final flush = compact && !pill && FlushMenus.of(context);
    final caret = Icon(
      Icons.keyboard_arrow_down,
      size: compact ? 14 : 15,
      color: t.textSecondary,
    );
    final corners = BorderRadius.circular(
      pill
          ? NushiTheme.pill
          : compact
          ? NushiTheme.control
          : size.radius,
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
                      ? theme.ui(t.textSecondary, size: pill ? 12.5 : 12)
                      : theme.ui(t.text, size: size.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: label,
                ),
              ),
              SizedBox(
                width: pill
                    ? 3
                    : compact
                    ? 1
                    : 6,
              ),
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
              height: pill
                  ? PillButton.height
                  : compact
                  ? null
                  : size.height,
              padding: pill
                  ? const EdgeInsets.fromLTRB(12, 0, 8, 0)
                  : compact
                  ? EdgeInsets.fromLTRB(5, 1, flush ? 0 : 3, 1)
                  : EdgeInsets.fromLTRB(size.pad - 2, 0, size.pad - 5, 0),
              decoration: BoxDecoration(
                color: compact
                    ? (look.hover ? _tint(t, look) : null)
                    : (look.hover
                          ? Color.alphaBlend(_tint(t, look), t.lifted)
                          : t.lifted),
                borderRadius: corners,
              ),
              foregroundDecoration: focusRing(t, look, radius: corners),
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

/// An icon that opens a menu ("More": ⋯). With [heldOpen] it stays tinted
/// while its menu is open, as a macOS toolbar's button and Claude desktop's
/// browser ⋯ do. [color] and [padding] are its [IconTap]'s.
class MenuIcon extends StatefulWidget {
  const new(
    IconData this.icon, {
    required this.tooltip,
    required this.entries,
    super.key,
    this.size = 16,
    this.onOpen,
    this.onClose,
    this.color,
    this.padding = 5,
    this.filter = true,
    this.heldOpen = false,
  }) : line = null;

  /// The same button with a drawn [LineIcon].
  const new line(
    LineIcon this.line, {
    required this.tooltip,
    required this.entries,
    super.key,
    this.size = 16,
    this.onOpen,
    this.onClose,
    this.color,
    this.padding = 5,
    this.filter = true,
    this.heldOpen = false,
  }) : icon = null;

  final IconData? icon;
  final LineIcon? line;
  final String tooltip;
  final List<MenuEntry> entries;
  final double size;
  final Color? color;
  final double padding;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  /// Whether a long list gets a filter field ([Menu.filter]).
  final bool filter;

  /// Whether it's tinted while its menu is open.
  final bool heldOpen;

  @override
  State<MenuIcon> createState() => _MenuIconState();
}

class _MenuIconState extends State<MenuIcon> {
  bool _open = false;

  void _opened(bool open) {
    if (widget.heldOpen && mounted) setState(() => _open = open);
  }

  @override
  Widget build(BuildContext context) => Menu(
    entries: widget.entries,
    onOpen: () {
      _opened(true);
      widget.onOpen?.call();
    },
    onClose: () {
      _opened(false);
      widget.onClose?.call();
    },
    filter: widget.filter,
    builder: (context, open) {
      final onTap = widget.entries.isEmpty ? null : open;
      return switch (widget.line) {
        final line? => IconTap.line(
          line,
          tooltip: widget.tooltip,
          size: widget.size,
          color: widget.color,
          padding: widget.padding,
          held: _open,
          onTap: onTap,
        ),
        null => IconTap(
          widget.icon!,
          tooltip: widget.tooltip,
          size: widget.size,
          color: widget.color,
          padding: widget.padding,
          held: _open,
          onTap: onTap,
        ),
      };
    },
  );
}
