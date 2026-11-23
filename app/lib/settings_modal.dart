import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/settings_view.dart';
import 'package:nushi/theme/theme.dart';

/// The app's keys that stop at Settings (ADR 0087): every action's but
/// ⌘,'s, which shuts it, the palette's and the chat's; none reaches what's
/// behind it. A field in Settings still gets its own (they're handled
/// before these). Esc, which shuts it, joins them in the modal.
final Map<ShortcutActivator, Intent> _stopped = {
  for (final k in appKeys.keys)
    if (k != settingsKey) k: const DoNothingAndStopPropagationIntent(),
};

/// [app], with Settings over it while [open] (ADR 0087): the app dimmed
/// and out of the focus's and the keys' reach, Settings growing with the
/// window up to [maxSize] (as tall as the window allows), at least
/// [inset] from the window's edges, centered. A click on the dim
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

  /// The modal's largest size: past this width a page's column (at most
  /// `SettingsPage.maxWidth`) would only leave empty space; no limit on
  /// its height, so a long page shows more of itself in a tall window.
  static const maxSize = Size(1120, double.infinity);

  /// Its least distance from the window's edges.
  static const inset = 40.0;

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  /// What had the focus as Settings opened, given it back as it shuts.
  FocusNode? _before;

  /// Settings' own focus: taken as it opens, so Esc and the keys stopped
  /// here reach it from wherever the focus was.
  final _scope = FocusScopeNode(debugLabel: 'settings');

  @override
  void initState() {
    super.initState();
    if (widget.open) _opened();
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  /// Notes what had the focus, then takes it once Settings is built.
  void _opened() {
    _before = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.open && !_scope.hasFocus) _scope.requestFocus();
    });
  }

  @override
  void didUpdateWidget(SettingsModal old) {
    super.didUpdateWidget(old);
    // Before the app below is shut out of the focus, which drops it.
    if (widget.open && !old.open) _opened();
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
                    shortcuts: {
                      ..._stopped,
                      const SingleActivator(LogicalKeyboardKey.escape):
                          VoidCallbackIntent(widget.daemon.closeSettings),
                    },
                    child: FocusScope(
                      node: _scope,
                      autofocus: true,
                      child: Container(
                        key: const ValueKey('settings-modal'),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: t.base,
                          borderRadius: BorderRadius.circular(NushiTheme.panel),
                          border: Border.all(color: t.floatLine),
                          boxShadow: floatShadows(t),
                        ),
                        // Its pages scroll down to the rounded corners.
                        child: RoundedScroll(
                          corner: NushiTheme.panel,
                          child: SettingsView(widget.daemon),
                        ),
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
