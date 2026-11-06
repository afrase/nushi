import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';

/// A browser tab's bar, under the pane's title row (ADR 0094): Back,
/// Forward and Reload, "Not secure" for a page that came over plain http
/// from another machine ([notSecure]), then the address field, which
/// takes the rest. Out of the field's focus it shows the page's host apart
/// from the rest, the host's end always in sight ([_Shown]); in it, the
/// whole address to edit. A new tab has no page yet ([host] null): only
/// its field works.
class BrowserBar extends StatelessWidget {
  const new({
    required this.host,
    required this.page,
    required this.address,
    required this.focus,
    required this.onGo,
    super.key,
  });

  final BrowserHost? host;

  /// The page's address (the tab's), which the mark follows; [address] is
  /// the field's text, which may be being typed.
  final ValueListenable<String> page;
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
            tooltip: 'Reload  ${Act.reloadPage.shortcut}',
            size: 15,
            onTap: host == null ? null : () => host.reload().ignore(),
          ),
          ValueListenableBuilder(
            valueListenable: page,
            builder: (context, at, _) => notSecure(at)
                ? Padding(
                    padding: const EdgeInsets.only(left: 6, right: 2),
                    child: Text(
                      'Not secure',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.ui(t.textSecondary, size: 11.5),
                    ),
                  )
                : const SizedBox(width: 6),
          ),
          Expanded(
            child: SizedBox(
              height: 26,
              child: ListenableBuilder(
                listenable: Listenable.merge([focus, page]),
                builder: (context, _) => _field(
                  theme,
                  focus.hasFocus ? null : addressParts(page.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The field, and over it, while [shown] (no one types in it), the
  /// page's address as [_Shown] draws it, the field's own text hidden
  /// under it; a click goes through to the field.
  Widget _field(NushiTheme theme, ({String host, String rest})? shown) {
    final t = theme.t;
    final style = theme.ui(t.text, size: 12);
    return Stack(
      fit: StackFit.expand,
      children: [
        TextField(
          controller: address,
          focusNode: focus,
          style: shown == null
              ? style
              : style.copyWith(color: Colors.transparent),
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Enter an address',
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          onSubmitted: onGo,
        ),
        if (shown != null)
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Shown(
                  shown,
                  host: style,
                  rest: style.copyWith(color: t.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A page's address out of the field's focus: its host in the text's
/// color and the rest muted, cut at the right; a host too long for the
/// field loses its start instead, behind an ellipsis, so the end of the
/// host, the part a page can't choose freely (`….evil.example`), stays in
/// sight, as browsers keep the site's own domain on screen.
class _Shown extends StatelessWidget {
  const new(this.parts, {required this.host, required this.rest});

  final ({String host, String rest}) parts;
  final TextStyle host;
  final TextStyle rest;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context);
      // Measured as the Text below draws it: over the default style.
      final style = DefaultTextStyle.of(context).style.merge(host);
      double width(String text) {
        final p = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scale,
          maxLines: 1,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      var name = parts.host;
      if (width(name) > box.maxWidth) {
        // The longest end of the host that fits after the ellipsis.
        var (lo, hi) = (1, name.length);
        while (lo < hi) {
          final mid = (lo + hi) ~/ 2;
          if (width('…${name.substring(mid)}') <= box.maxWidth) {
            hi = mid;
          } else {
            lo = mid + 1;
          }
        }
        // From a label's start, as a domain is read in labels.
        final dot = name.indexOf('.', lo);
        if (name[lo - 1] != '.' && dot >= 0 && dot < name.length - 1) {
          lo = dot + 1;
        }
        name = '…${name.substring(lo)}';
      }
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: name, style: host),
            if (name == parts.host) TextSpan(text: parts.rest, style: rest),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

final ValueListenable<bool> _never = ValueNotifier(false);
