import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/browser_page.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

/// A browser tab's bar, under the pane's title row (ADR 0094): Back,
/// Forward and Reload, then the address field, which takes the rest. A new
/// tab has no page yet ([host] null): only its field works.
class BrowserBar extends StatelessWidget {
  const new({
    required this.host,
    required this.address,
    required this.focus,
    required this.onGo,
    super.key,
  });

  final BrowserHost? host;
  final TextEditingController address;
  final FocusNode focus;

  /// The field's text, on Return.
  final ValueChanged<String> onGo;

  /// Its height, its border in it.
  static const height = 38.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final host = this.host;
    Widget step(
      IconData icon,
      String tooltip,
      ValueListenable<bool>? can,
      Future<void> Function() go,
    ) => ValueListenableBuilder(
      valueListenable: can ?? _never,
      builder: (context, on, _) => IconTap(
        icon,
        tooltip: tooltip,
        size: 15,
        onTap: on ? () => go().ignore() : null,
      ),
    );
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 1),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        spacing: NushiTheme.iconGap,
        children: [
          step(Icons.arrow_back, 'Back', host?.canBack, () => host!.back()),
          step(
            Icons.arrow_forward,
            'Forward',
            host?.canForward,
            () => host!.forward(),
          ),
          IconTap(
            Icons.refresh,
            tooltip: 'Reload',
            size: 15,
            onTap: host == null ? null : () => host.reload().ignore(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 26,
              child: TextField(
                controller: address,
                focusNode: focus,
                style: theme.ui(t.text, size: 12),
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Enter a local address',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                onSubmitted: onGo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final ValueListenable<bool> _never = ValueNotifier(false);
