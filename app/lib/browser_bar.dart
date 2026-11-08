import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nushi/app_actions.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/web_page.dart' show openInBrowserOrSay;
import 'package:nushi/web_views.dart';

/// A browser tab's bar, under the pane's title row (ADR 0094), drawn as
/// Claude desktop's: Back, Forward and Reload, "Not secure" for a page that
/// came over plain http from another machine ([notSecure]), then the
/// address field, which takes the rest: a rounded, filled field with a
/// fine border that out of its focus shows only the page's host, centred,
/// the host's end always in sight ([_Shown]); in it, the whole address to
/// edit; inside its right end, for a web page, a button that opens the page
/// in the default browser ([_Outside]). A new tab has no page yet ([host]
/// null): only its field works. Without the app's own web views (Linux,
/// ADR 0102) there's no Back, Forward or Reload: the page is the browser's.
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

  /// Its height, its border in it: the chat header's, as Claude's bar is
  /// as high as its title row and a little more.
  static const height = 44.0;

  /// The field's height, and its corners' radius.
  static const fieldHeight = 30.0;
  static const _round = 8.0;

  /// The room at the bar's ends.
  static const inset = 8.0;

  /// Back, Forward and Reload's glyphs and the room around each: as large
  /// as Claude's, in the text's ink, so a disabled one (muted) stands out.
  static const _icon = 21.0;
  static const _iconPadding = 4.0;

  /// The key of the address field's box, its fill and border.
  static const ValueKey<String> fieldKey = ValueKey('address field');

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final host = this.host;
    Widget step(
      LineIcon icon,
      String tooltip,
      ValueListenable<bool>? can,
      Future<void> Function() go,
    ) => ValueListenableBuilder(
      valueListenable: can ?? _never,
      builder: (context, on, _) => IconTap.line(
        icon,
        tooltip: tooltip,
        size: _icon,
        padding: _iconPadding,
        color: t.text,
        onTap: on ? () => go().ignore() : null,
      ),
    );
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(inset, 0, inset, 1),
      decoration: BoxDecoration(
        color: t.raised,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        spacing: 3,
        children: [
          if (webEmbedded) ...[
            step(LineIcon.back, 'Back', host?.canBack, () => host!.back()),
            step(
              LineIcon.forward,
              'Forward',
              host?.canForward,
              () => host!.forward(),
            ),
            IconTap.line(
              LineIcon.reload,
              tooltip: 'Reload  ${Act.reloadPage.shortcut}',
              size: _icon,
              padding: _iconPadding,
              color: t.text,
              onTap: host == null ? null : () => host.reload().ignore(),
            ),
          ],
          ValueListenableBuilder(
            valueListenable: page,
            builder: (context, at, _) => notSecure(at)
                ? Padding(
                    padding: const EdgeInsets.only(left: 4, right: 2),
                    child: Text(
                      'Not secure',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.ui(t.textSecondary, size: 12),
                    ),
                  )
                : const SizedBox(width: 2),
          ),
          Expanded(
            child: SizedBox(
              height: fieldHeight,
              child: ListenableBuilder(
                listenable: Listenable.merge([focus, page]),
                builder: (context, _) {
                  final shown = hostOf(page.value);
                  return _field(
                    theme,
                    focus.hasFocus || shown.isEmpty ? null : shown,
                    outside: isWebPage(Uri.tryParse(page.value)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The field, and over it, while [shown] (no one types in it), the
  /// page's host as [_Shown] draws it, centred, the field's own text hidden
  /// under it; a click goes through to the field. Inside its right end, for
  /// a web page, the button that opens it in the default browser
  /// ([_Outside]).
  Widget _field(NushiTheme theme, String? shown, {required bool outside}) {
    final t = theme.t;
    final style = theme.ui(t.text);
    final hostStyle = theme.ui(t.text, size: 14);
    // Room for the button, and as much on the left, so the host centres
    // in the field.
    final side = outside ? _Outside.room : 10.0;
    // The field's box is drawn here, as Claude's: a fill, a fine border,
    // the focus's color while it's typed in. A click anywhere in it is the
    // field's, as over its text line.
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: t.fieldFill,
        border: Border.all(
          color: focus.hasFocus ? t.focus : t.borderSubtle,
          width: focus.hasFocus ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(_round),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 10, right: side),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: address,
                focusNode: focus,
                style: shown == null
                    ? style
                    : style.copyWith(color: Colors.transparent),
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Enter an address',
                ),
                onSubmitted: onGo,
              ),
            ),
          ),
          if (shown != null)
            IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: side),
                child: Align(child: _Shown(shown, style: hostStyle)),
              ),
            ),
          if (outside)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: _Outside(page: page),
              ),
            ),
        ],
      ),
    );
    return MouseRegion(
      key: fieldKey,
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: focus.requestFocus,
        child: box,
      ),
    );
  }
}

/// The button inside the address field's right end that opens the tab's
/// page in the default browser, named in its tooltip as Claude desktop's is
/// ("Open in Google Chrome", [defaultBrowser]), its own tint under the
/// pointer.
class _Outside extends StatelessWidget {
  const new({required this.page});

  final ValueListenable<String> page;

  /// The field's room for it, at its right end.
  static const room = 32.0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: defaultBrowser,
    builder: (context, name, _) => IconTap.line(
      LineIcon.openOutside,
      tooltip: name == null ? 'Open in your browser' : 'Open in $name',
      size: 18,
      padding: 4,
      color: NushiTheme.of(context).t.text,
      onTap: () {
        if (Uri.tryParse(page.value) case final url? when isWebPage(url)) {
          openInBrowserOrSay(context, url).ignore();
        }
      },
    ),
  );
}

/// A page's host out of the field's focus, centred as Claude desktop's
/// is; a host too long for the field loses its start, behind an ellipsis,
/// so the end of the host, the part a page can't choose freely
/// (`….evil.example`), stays in sight, as browsers keep the site's own
/// domain on screen.
class _Shown extends StatelessWidget {
  const new(this.host, {required this.style});

  final String host;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context);
      // Measured as the Text below draws it: over the default style.
      final measured = DefaultTextStyle.of(context).style.merge(style);
      double width(String text) {
        final p = TextPainter(
          text: TextSpan(text: text, style: measured),
          textDirection: TextDirection.ltr,
          textScaler: scale,
          maxLines: 1,
        )..layout();
        final w = p.width;
        p.dispose();
        return w;
      }

      var name = host;
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
      return Text(
        name,
        style: style,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

final ValueListenable<bool> _never = ValueNotifier(false);
