import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/preview.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/web_page.dart';

// Pages where the app has no web view of its own (Linux, ADR 0102): a file's
// preview and a browser tab each show a placeholder in the page's place,
// whose button opens the page in the default browser. Only the user's click
// opens it: what the agent shows (ADR 0068) and the Servers menu put a
// placeholder up, and nothing more. Plain Dart, for any platform without
// web views.

/// A file's page where there's no web view: [load] keeps the path the
/// daemon confirmed, which its placeholder opens in the default browser.
/// The browser reads the file as it likes: [load]'s root is a web view's
/// to hold, and none is here.
class OutsidePage implements PageHost {
  final _path = ValueNotifier<String?>(null);

  @override
  Widget view(BuildContext context) => ValueListenableBuilder(
    valueListenable: _path,
    builder: (context, path, _) => OutsideView(
      icon: (path == null ? null : previewKind(path))?.icon,
      name: path == null ? '' : plainPath(baseName(path)),
      onOpen: path == null
          ? null
          : () => unawaited(openInBrowserOrSay(context, Uri.file(path))),
    ),
  );

  @override
  Future<void> load(String path, String root) async {
    _path.value = path;
    unawaited(lookUpDefaultBrowser());
  }

  /// The browser has its own copy to reload.
  @override
  Future<void> reload() async {}

  @override
  void dispose() => _path.dispose();
}

/// A browser tab's page where there's no web view: [open] sets the tab's
/// address, which its placeholder opens in the default browser; it never
/// opens it itself. It has no history, never fails, and blocks nothing:
/// those are the browser's.
class OutsideTab implements BrowserHost {
  new(this.tab);

  final BrowserTab tab;
  final _back = ValueNotifier<bool>(false);
  final _forward = ValueNotifier<bool>(false);
  final _failed = ValueNotifier<PageFailure?>(null);
  final _blocked = ValueNotifier<Uri?>(null);

  @override
  Widget view(BuildContext context) => ValueListenableBuilder(
    valueListenable: tab.address,
    builder: (context, address, _) {
      final url = Uri.tryParse(address);
      return OutsideView(
        line: LineIcon.globe,
        name: hostOf(address),
        onOpen: isWebPage(url)
            ? () => unawaited(openInBrowserOrSay(context, url!))
            : null,
      );
    },
  );

  /// A web page only, as a tab loads ([isWebPage]: no user name).
  @override
  Future<void> open(Uri url) async {
    if (isWebPage(url)) tab.address.value = '$url';
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> back() async {}

  @override
  Future<void> forward() async {}

  @override
  ValueListenable<bool> get canBack => _back;

  @override
  ValueListenable<bool> get canForward => _forward;

  @override
  ValueListenable<PageFailure?> get failed => _failed;

  @override
  ValueListenable<Uri?> get blockedLocal => _blocked;

  /// No page is drawn here to take a picture of.
  @override
  Future<Uint8List> snapshot() =>
      throw UnsupportedError('no page to take a picture of');

  @override
  void dispose() {
    _back.dispose();
    _forward.dispose();
    _failed.dispose();
    _blocked.dispose();
  }
}

/// What a page's placeholder says (ADR 0102).
const outsideNote = 'Pages open in your browser.';

/// A page's placeholder: its kind's [icon] (or a drawn [line] one), its
/// [name] (a file's, a host), that pages open in the browser, and the
/// primary button that opens it there, naming the default browser ("Open
/// in Firefox", [defaultBrowser]); disabled without [onOpen].
class OutsideView extends StatelessWidget {
  const new({
    required this.name,
    required this.onOpen,
    super.key,
    this.icon,
    this.line,
  });

  final IconData? icon;
  final LineIcon? line;
  final String name;
  final VoidCallback? onOpen;

  static const _iconSize = 28.0;

  /// The widest the name runs before it wraps.
  static const _nameWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(NushiTheme.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            switch (line) {
              final line? => line.view(size: _iconSize, color: t.textMuted),
              null => Icon(
                icon ?? Icons.web_outlined,
                size: _iconSize,
                color: t.textMuted,
              ),
            },
            const SizedBox(height: 12),
            if (name.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _nameWidth),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.ui(t.text, size: 15, weight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              outsideNote,
              textAlign: TextAlign.center,
              style: theme.ui(t.textSecondary),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: defaultBrowser,
              builder: (context, browser, _) => Button(
                label: 'Open in ${browser ?? 'your browser'}',
                icon: Icons.open_in_new,
                kind: ButtonKind.primary,
                onPressed: onOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
