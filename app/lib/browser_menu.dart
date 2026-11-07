import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:nushi/allowed_sites.dart';
import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_local.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/menu.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/settings.dart' show linksInBrowserTab, localNetworkSites;
import 'package:nushi/theme/theme.dart';
import 'package:nushi/widgets.dart';

// A browser tab's ⋯ menu (ADR 0094), in Claude desktop's order and words
// where they apply: Save screenshot; Open links in built-in browser, Manage
// allowed sites…, Local network access; under Cookies, Clear browsing data.
// Claude's Import cookies isn't here: it would mean decrypting another
// browser's stored logins.

/// The ⋯ at a browser tab's title row's right end: its menu, held tinted
/// while it's open, reached from the keyboard like the app's other menus
/// (Tab to it, Return or Space, the arrows).
class BrowserMenu extends StatelessWidget {
  const new({
    required this.tab,
    required this.host,
    super.key,
    this.size = 18,
    this.padding = 5,
  });

  final BrowserTab tab;

  /// The page's host, null for a new tab.
  final BrowserHost? host;

  /// Its glyph's size and the room around it ([IconTap]'s).
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      linksInBrowserTab,
      localNetworkSites,
      tab.address,
    ]),
    // Under the button, ending under its right edge, as Claude's does.
    builder: (context, _) => TrailingMenus(
      child: MenuIcon.line(
        LineIcon.more,
        tooltip: 'More',
        size: size,
        padding: padding,
        color: NushiTheme.of(context).t.text,
        filter: false,
        heldOpen: true,
        entries: _entries(context),
      ),
    ),
  );

  List<MenuEntry> _entries(BuildContext context) {
    final address = tab.address.value;
    final host = this.host;
    final page = host != null && isWebPage(Uri.tryParse(address));
    final access = localNetworkAccess(address, localNetworkSites.value);
    final site = Uri.tryParse(address)?.host ?? '';
    return [
      MenuEntry(
        'Save screenshot',
        onPick: page ? () => unawaited(saveScreenshot(context, host)) : null,
      ),
      MenuEntry.divider,
      MenuEntry(
        'Open links in built-in browser',
        checked: linksInBrowserTab.value,
        onPick: () => linksInBrowserTab.value = !linksInBrowserTab.value,
      ),
      MenuEntry(
        'Manage allowed sites…',
        onPick: () => unawaited(showAllowedSites(context)),
      ),
      if (access case (:final allowed, :final fixed))
        MenuEntry(
          'Local network access',
          detail: allowed ? 'Allowed' : 'Blocked',
          tooltip: !fixed
              ? ''
              : allowed
              ? 'A page on your Mac or local network always reaches it'
              : 'This site’s address can’t be allowed',
          // The site it's for, over its choices: the page may move while
          // the menu is open, and the rows follow it. Fixed, none: the row
          // shows its value, unavailable.
          submenu: fixed
              ? const []
              : [
                  MenuEntry.heading(site.toLowerCase()),
                  MenuEntry(
                    'Blocked',
                    checked: !allowed,
                    onPick: () => disallowLocalNetwork(site),
                  ),
                  MenuEntry(
                    'Allowed for this site',
                    checked: allowed,
                    onPick: () => allowLocalNetwork(site),
                  ),
                ],
        ),
      MenuEntry.divider,
      const MenuEntry.heading('Cookies'),
      MenuEntry(
        'Clear browsing data',
        danger: true,
        onPick: () => unawaited(clearBrowsing(context, host)),
      ),
    ];
  }
}

/// Where Save screenshot saves a file of the name it's given: the Mac's
/// save panel, PNG, null when it's cancelled. Tests set their own.
Future<String?> Function(String name) screenshotPath = (name) async =>
    (await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG image', extensions: ['png']),
      ],
      confirmButtonText: 'Save',
    ))?.path;

/// A screenshot's name, as macOS names one: "Screenshot 2026-11-06 at
/// 14.03.22.png".
String screenshotName(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Screenshot ${at.year}-${two(at.month)}-${two(at.day)} at '
      '${two(at.hour)}.${two(at.minute)}.${two(at.second)}.png';
}

/// Save screenshot: the page in sight, as it is when picked ([host]'s
/// snapshot, WebKit's), saved as a PNG where the save panel says.
Future<void> saveScreenshot(BuildContext context, BrowserHost host) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final png = await host.snapshot();
    final path = await screenshotPath(screenshotName(clock()));
    if (path == null) return;
    await File(path).writeAsBytes(png, flush: true);
  } on Object catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Couldn’t save the screenshot: ${errorText(e)}'),
        ),
      );
  }
}

/// Clear browsing data: once the user says so, every site's cookies,
/// storage and caches go from WebKit's store ([clearBrowsingData]), and the
/// page showing ([host]'s) loads again without them; another tab's page
/// loads afresh as it shows.
Future<void> clearBrowsing(BuildContext context, BrowserHost? host) async {
  final sure = await confirm(
    context,
    'Clear browsing data?',
    'Every site’s cookies, storage and cache go from Nushi’s browser tabs, '
        'which signs you out of the sites you signed in to there. Your own '
        'browser keeps its data.',
    'Clear',
    destructive: true,
  );
  if (!sure || !context.mounted) return;
  await runAndSay(
    context,
    () async {
      await clearBrowsingData();
      await host?.reload();
    },
    running: 'Clearing browsing data…',
    done: 'Browsing data cleared',
  );
}
