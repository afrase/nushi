import 'package:flutter/material.dart';

import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

/// A toast's action: its words and what pressing it does (Undo, Go to
/// chat). Pressing it also takes the toast away.
typedef ToastAction = ({String label, VoidCallback onPressed});

/// Shows the app's one toast in [messenger]: [text], after [icon] when
/// given (the failure's color when [failed]), then [action] as a compact
/// button and, when [closable], a × (docs/design.md's Toasts). It stays
/// [duration]; with [replace], it takes the place of the one showing,
/// else it waits its turn. Its look is the theme's snack bar: `lifted`
/// with a hairline, 420 wide on the Mac. [margin] places it (above a
/// bar).
void showToast(
  ScaffoldMessengerState? messenger,
  String text, {
  IconData? icon,
  bool failed = false,
  ToastAction? action,
  bool closable = false,
  bool replace = false,
  Duration duration = const Duration(seconds: 4),
  EdgeInsetsGeometry? margin,
  Key? key,
}) {
  if (messenger == null) return;
  if (replace) messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      key: key,
      margin: margin,
      duration: duration,
      content: ToastLine(
        text,
        icon: icon,
        failed: failed,
        action: action == null
            ? null
            : (
                label: action.label,
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  action.onPressed();
                },
              ),
        onClose: closable ? messenger.hideCurrentSnackBar : null,
      ),
    ),
  );
}

/// A toast's line: [icon] (the failure's color when [failed]), [text],
/// then [action] and × ([onClose]) when given, from the app's own
/// controls, compact (ADR 0122).
class ToastLine extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.icon,
    this.action,
    this.onClose,
    this.failed = false,
  });

  final IconData? icon;
  final String text;
  final ToastAction? action;
  final VoidCallback? onClose;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Row(
      spacing: 8,
      children: [
        if (icon case final icon?)
          Icon(icon, size: 16, color: failed ? t.crashed : t.textSecondary),
        Expanded(child: Text(text)),
        if (action case final action?)
          ControlScale.compact(
            child: Button(label: action.label, onPressed: action.onPressed),
          ),
        if (onClose case final close?)
          IconTap(Icons.close, size: 14, tooltip: 'Dismiss', onTap: close),
      ],
    );
  }
}
