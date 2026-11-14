import 'package:flutter/material.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';

/// The phone's touch target: 44 points, as iOS asks.
const touch = 44.0;

/// Below this height above the keyboard, a screen drops its bar.
const crampedHeight = 200.0;

/// The phone's text: larger than the Mac's.
TextStyle phoneText(
  BuildContext context, {
  Color? color,
  double size = 16,
  FontWeight? weight,
}) {
  final theme = NushiTheme.of(context);
  return theme.ui(color ?? theme.t.text, size: size, weight: weight);
}

/// A screen: a bar with a title, a back button when it can go back, and
/// [actions]; the body inside the safe area (notch and home indicator).
class PhoneScreen extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    super.key,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Below the body, above the home indicator (a composer).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    // This screen's own route, not the navigator's stack: the root built
    // while another screen was on top would keep a back button after it
    // went (the chats showed one on the iPhone).
    final back = !(ModalRoute.of(context)?.isFirst ?? true);
    // With the keyboard up in landscape (or in a browser's tab, under its
    // bars) there may be room for little more than the field being typed
    // in: the bar goes, so that field shows.
    final mq = MediaQuery.of(context);
    final cramped =
        mq.viewInsets.bottom > 0 &&
        mq.size.height - mq.viewInsets.bottom < crampedHeight;
    return Scaffold(
      backgroundColor: t.base,
      body: SafeArea(
        bottom: bottom == null,
        child: LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!cramped)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.line)),
                  ),
                  child: SizedBox(
                    height: touch + 8,
                    child: Row(
                      children: [
                        if (back)
                          PhoneIcon(
                            Icons.arrow_back_ios_new,
                            label: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          )
                        else
                          const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: phoneText(
                              context,
                              size: 17,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...actions,
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              Expanded(child: body),
              // A composer taller than the strip left (a reply's card and the
              // field, over the keyboard in landscape) scrolls, its field at
              // the bottom.
              if (bottom case final b?)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SafeArea(top: false, child: b),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An icon button with a 44-point target: [Pressable]'s focus ring and
/// press, a round tint behind the icon under the finger.
class PhoneIcon extends StatelessWidget {
  const new(this.icon, {required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The round tint's size, inside the target.
  static const _tint = 36.0;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final round = BorderRadius.circular(NushiTheme.pill);
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        builder: (context, look) => SizedBox.square(
          dimension: touch,
          child: Center(
            child: Container(
              width: _tint,
              height: _tint,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: look.pressed
                    ? t.pressed
                    : look.hover
                    ? t.hover
                    : null,
                borderRadius: round,
              ),
              foregroundDecoration: focusRing(t, look, radius: round),
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? t.textMuted : t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An action in a line of the phone's text (Try again, Reload, New chat
/// here): [LinkText] at the phone's size, a button's room either side,
/// and a 44-point target ([TouchTargets]).
class PhoneLink extends StatelessWidget {
  const new(this.label, {required this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: LinkText(label, size: 14, onTap: onTap),
  );
}

/// A full-width button, 44 points tall: [primary] filled with the accent,
/// any other with a button's own fill, no outline (ADR 0111); on
/// [Pressable], so it shows a press at once and wears the focus ring.
class PhoneButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onTap,
    super.key,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final fg = onTap == null
        ? t.textMuted
        : primary
        ? t.onAccent
        : destructive
        ? t.crashed
        : t.text;
    final filled = primary && onTap != null;
    final corners = BorderRadius.circular(NushiTheme.card);
    return Pressable(
      onTap: onTap,
      builder: (context, look) => Container(
        height: touch + 4,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (look.pressed ? t.accentPressed : t.accent)
              : look.pressed
              ? Color.alphaBlend(t.pressed, t.lifted)
              : look.hover
              ? Color.alphaBlend(t.hover, t.lifted)
              : t.lifted,
          borderRadius: corners,
        ),
        foregroundDecoration: filled
            ? accentFocusRing(t, look, radius: corners)
            : focusRing(t, look, radius: corners),
        child: Text(
          label,
          style: phoneText(context, color: fg, weight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// A section's heading in a list.
class PhoneHeading extends StatelessWidget {
  const new(this.text, {super.key, this.detail = ''});

  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: phoneText(
                context,
                color: t.textSecondary,
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
            if (detail.isNotEmpty)
              TextSpan(
                text: '  $detail',
                style: phoneText(context, color: t.textMuted, size: 13),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Shows [message] at the bottom of the screen.
void phoneSay(BuildContext context, String message) =>
    showToast(ScaffoldMessenger.maybeOf(context), message, replace: true);

/// A small spinner, for what's on its way.
class PhoneSpinner extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 16,
    child: Spinner(
      strokeWidth: 2,
      color: NushiTheme.of(context).t.textSecondary,
    ),
  );
}
