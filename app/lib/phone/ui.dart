import 'package:flutter/material.dart';
import 'package:nushi/theme/theme.dart';

/// The phone's touch target: 44 points, as iOS asks.
const touch = 44.0;

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
    return Scaffold(
      backgroundColor: t.base,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.borderSubtle)),
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
            if (bottom case final b?) SafeArea(top: false, child: b),
          ],
        ),
      ),
    );
  }
}

/// An icon button with a 44-point target.
class PhoneIcon extends StatelessWidget {
  const new(this.icon, {required this.label, required this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: touch / 2,
        child: SizedBox.square(
          dimension: touch,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? t.textMuted : t.text,
          ),
        ),
      ),
    );
  }
}

/// A full-width button, 44 points tall: [primary] filled with the accent.
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
    return Material(
      color: primary && onTap != null ? t.accent : t.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: primary ? BorderSide.none : BorderSide(color: t.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: touch + 4,
          child: Center(
            child: Text(
              label,
              style: phoneText(context, color: fg, weight: FontWeight.w600),
            ),
          ),
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
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

/// A small spinner, for what's on its way.
class PhoneSpinner extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: NushiTheme.of(context).t.textSecondary,
    ),
  );
}
