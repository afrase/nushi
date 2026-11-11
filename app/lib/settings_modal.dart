import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/chat_keys.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

/// The app's keys that stop at Settings (ADR 0087): every action's but
/// ⌘,'s, which shuts it, the palette's and the chat's; none reaches what's
/// behind it. A field in Settings still gets its own (they're handled
/// before these).
final Map<ShortcutActivator, Intent> _stopped = {
  for (final k in [
    ...actKeys.keys,
    paletteKey,
    paletteKeyToo,
    ...chatKeys.keys,
  ])
    if (k != settingsKey) k: const DoNothingAndStopPropagationIntent(),
};

/// [app], with Settings over it while [open] (ADR 0087): the app dimmed
/// and out of the focus's and the keys' reach, Settings at most [maxSize],
/// at least [inset] from the window's edges, centered. A click on the dim
/// shuts it, and the focus goes back where it was before it opened.
class SettingsModal extends StatefulWidget {
  const new({
    required this.daemon,
    required this.open,
    required this.app,
    super.key,
  });

  final Daemon daemon;
  final bool open;
  final Widget app;

  /// The modal's largest size.
  static const maxSize = Size(960, 720);

  /// Its least distance from the window's edges.
  static const inset = 40.0;

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  /// What had the focus as Settings opened, given it back as it shuts.
  FocusNode? _before;

  @override
  void initState() {
    super.initState();
    if (widget.open) _before = FocusManager.instance.primaryFocus;
  }

  @override
  void didUpdateWidget(SettingsModal old) {
    super.didUpdateWidget(old);
    // Before the app below is shut out of the focus, which drops it.
    if (widget.open && !old.open) _before = FocusManager.instance.primaryFocus;
    if (!widget.open && old.open) {
      final back = _before;
      _before = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (back?.context?.mounted ?? false) back!.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeFocus(
            excluding: widget.open,
            child: ExcludeSemantics(excluding: widget.open, child: widget.app),
          ),
        ),
        if (widget.open) ...[
          Positioned.fill(
            // The dim covers the headers, so its top moves the window.
            child: TitleBand(
              onTap: widget.daemon.closeSettings,
              child: GestureDetector(
                key: const ValueKey('settings-dim'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.daemon.closeSettings,
                // The scrim's black, a good deal lighter than over an image
                // (more on a dark set, where less shows): the app stays in
                // sight, and a theme picked shows on it.
                child: ColoredBox(
                  color: t.scrim.withValues(
                    alpha: t.brightness == Brightness.dark ? 0.42 : 0.24,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(SettingsModal.inset),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints.loose(SettingsModal.maxSize),
                  child: Shortcuts(
                    shortcuts: _stopped,
                    child: FocusScope(
                      autofocus: true,
                      child: Container(
                        key: const ValueKey('settings-modal'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.base,
                          borderRadius: BorderRadius.circular(NushiTheme.panel),
                          border: Border.all(color: t.borderStrong),
                          boxShadow: [
                            BoxShadow(color: t.shadow, blurRadius: 30),
                          ],
                        ),
                        child: SettingsView(widget.daemon),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
