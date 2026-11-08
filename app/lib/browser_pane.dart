import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nushi/browser_address.dart';
import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_menu.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/daemon.dart';
import 'package:nushi/native.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/server_logs.dart';
import 'package:nushi/servers_menu.dart';
import 'package:nushi/theme/theme.dart';

/// The chat header's browser button (ADR 0094): it shows the preview's last
/// browser tab, or a new one, on the Chat tab; lit while one shows there.
class BrowserButton extends StatelessWidget {
  const new({required this.chat, super.key});

  final ChatState chat;

  /// What it says, and its row in the header's ⋯ when it folds there:
  /// Show browser or Hide browser.
  static String tooltip({required bool shown}) =>
      '${shown ? 'Hide' : 'Show'} browser';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chat.preview, chat.tab]),
    builder: (context, _) {
      final t = NushiTheme.of(context).t;
      return IconTap.line(
        LineIcon.globe,
        tooltip: tooltip(shown: chat.browserShown),
        color: chat.browserShown ? t.accentInk : t.textSecondary,
        onTap: chat.showOrHideBrowser,
      );
    },
  );
}

/// What a new browser tab says under its address field.
const browserHint = 'Enter an address, like example.com or localhost:3000';

/// A browser tab in the preview pane (ADR 0094), as Claude desktop's
/// browser: the pane's title row (its tabs as chips, a + that opens a new
/// browser tab; at the right Servers ([ServersButton]), ⋯ ([BrowserMenu]),
/// Expand and Close, which
/// closes every tab), then [BrowserBar], then the page, or for a new tab a
/// hint, over a server's logs drawer while one is open ([ServerLogsDrawer]).
/// Like a file's view it's made again as its tab shows: the page loads
/// again from the tab's address.
class BrowserPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.tab,
    required this.onClose,
    super.key,
    this.tabsKey,
    this.expanded = false,
    this.onExpand,
    this.daemon,
  });

  final ChatState chat;
  final BrowserTab tab;
  final VoidCallback onClose;

  /// The key of its [PreviewTabs] (`PreviewPane.tabsKey`).
  final Key? tabsKey;

  /// Whether it takes the whole chat area, over the transcript (ADR 0094).
  final bool expanded;

  /// Expands it, or with it [expanded] collapses it: its title row's button,
  /// and Esc while it's expanded. Null: no button.
  final VoidCallback? onExpand;

  /// The daemon, for the Servers button (ADR 0098); null: no button.
  final Daemon? daemon;

  @override
  State<BrowserPane> createState() => _BrowserPaneState();
}

class _BrowserPaneState extends State<BrowserPane> implements BrowserControls {
  BrowserHost? _host;
  late final _address = TextEditingController(text: widget.tab.address.value);
  final _field = FocusNode(debugLabel: 'address');

  /// The pane's own focus, taken as it expands, so Esc reaches it there
  /// (what had the focus, the chat's box, is hidden behind it).
  final _pane = FocusNode(debugLabel: 'browser pane', skipTraversal: true);

  BrowserTab get _tab => widget.tab;

  @override
  void initState() {
    super.initState();
    _tab
      ..view = this
      ..address.addListener(_moved);
    _field.addListener(_moved);
    unawaited(lookUpDefaultBrowser());
    if (addressOf(_tab.address.value) case final url?) {
      _open(url);
      // Made expanded (another tab picked while the pane is): the pane
      // takes the focus the old one had, so Esc still reaches it.
      if (widget.expanded) _takeFocus();
    } else {
      // A new tab waits on its address.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _field.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(BrowserPane old) {
    super.didUpdateWidget(old);
    if (widget.expanded && !old.expanded) _takeFocus();
  }

  /// Gives the pane the focus after this frame, unless its field has it.
  void _takeFocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !_field.hasFocus) _pane.requestFocus();
  });

  @override
  void dispose() {
    if (identical(_tab.view, this)) _tab.view = null;
    _tab.address.removeListener(_moved);
    _field.removeListener(_moved);
    _host
      ?..blockedLocal.removeListener(_blocked)
      ..dispose();
    _address.dispose();
    _field.dispose();
    _pane.dispose();
    super.dispose();
  }

  /// The page moved, or the field was left: it says where the page is,
  /// unless it's being typed in.
  void _moved() {
    if (!_field.hasFocus && _address.text != _tab.address.value) {
      _address.text = _tab.address.value;
    }
  }

  void _open(Uri url) {
    final host = _host ??= native.web.tab(_tab)
      ..blockedLocal.addListener(_blocked);
    unawaited(host.open(url));
  }

  /// The page went for a local address and was refused: the pane says so,
  /// and how to go there anyway.
  void _blocked() {
    final url = _host?.blockedLocal.value;
    if (url == null || !mounted) return;
    _note(
      'This site can’t open ${hostOf('$url')}: it’s on your Mac or local '
      'network. Type the address to open it.',
    );
  }

  /// Says [text] under the pane, in place of what it said last.
  void _note(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// The field's text on Return: a page loads here, a file's address opens
  /// the file's preview ([fileAddressOf]), and what isn't an address is
  /// refused, saying why (nothing is searched for).
  void _go(String text) {
    if (fileAddressOf(text) case final path?) {
      _field.unfocus();
      widget.chat.openPreview(path);
      return;
    }
    final url = addressOf(text);
    if (url != null) {
      _field.unfocus();
      setState(() => _open(url));
      return;
    }
    _note(
      text.trim().toLowerCase().startsWith('file:')
          ? 'Not a file on this Mac: try file:///path, or /path'
          : 'Not an address: try one like example.com or localhost:3000',
    );
  }

  @override
  void focusAddress() {
    // WebKit may hold the keys while Flutter still thinks the field has the
    // focus (a click into the page doesn't tell Flutter). Asking for the
    // focus a node already has does nothing, so the field lets it go first,
    // at once, and then takes it again, which opens its text input anew.
    if (_field.hasFocus) {
      _field.unfocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
    }
    _field.requestFocus();
    _address.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _address.text.length,
    );
  }

  @override
  void reload() => _host?.reload().ignore();

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    final host = _host;
    final expand = widget.onExpand;
    final pane = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHeader(
          inset: previewChipInset,
          end: previewChipInset,
          child: Row(
            children: [
              Expanded(child: _tabs()),
              const SizedBox(width: 6),
              // Each in a box of one size, the glyphs as large as Claude's
              // and in the text's ink, a disabled one muted (IconTap).
              if (widget.daemon case final daemon?)
                ServersButton(
                  chat: widget.chat,
                  daemon: daemon,
                  padding: _boxed(18),
                  collapse: widget.expanded ? expand : null,
                ),
              BrowserMenu(tab: _tab, host: host, size: 20, padding: _boxed(20)),
              if (expand != null)
                IconTap.line(
                  widget.expanded ? LineIcon.collapse : LineIcon.expand,
                  tooltip: widget.expanded ? 'Collapse' : 'Expand',
                  size: 18,
                  padding: _boxed(18),
                  color: t.text,
                  onTap: expand,
                ),
              IconTap.line(
                LineIcon.close,
                tooltip: 'Close',
                size: 22,
                padding: _boxed(22),
                color: t.text,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        BrowserBar(
          host: host,
          page: _tab.address,
          address: _address,
          focus: _field,
          onGo: _go,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: t.base,
                    child: host == null ? const _NewTab() : _page(host),
                  ),
                ),
                // A server's output under the page it serves (ADR 0100).
                if (widget.daemon case final daemon?)
                  ServerLogsDrawer(
                    chat: widget.chat,
                    servers: daemon.devServers,
                    room: box.maxHeight,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    // Esc collapses it, from anywhere in it Flutter has the keys (a page
    // in WebKit keeps its own).
    return CallbackShortcuts(
      bindings: {
        if (widget.expanded && expand != null)
          const SingleActivator(LogicalKeyboardKey.escape): expand,
      },
      child: Focus(focusNode: _pane, child: pane),
    );
  }

  /// The side of each button's box at the title row's right end.
  static const _box = 32.0;

  /// The padding that sets an icon of [size] in a [_box].
  static double _boxed(double size) => (_box - size) / 2;

  /// The tabs, chips even when there's one, as Claude's, and the + right
  /// after them.
  Widget _tabs() => ValueListenableBuilder(
    valueListenable: widget.chat.previewTabs,
    builder: (context, open, _) => Row(
      spacing: 2,
      children: [
        Flexible(
          child: PreviewTabs(
            key: widget.tabsKey,
            chat: widget.chat,
            tabs: open.isEmpty ? [_tab] : open,
            current: _tab,
          ),
        ),
        NewBrowserTab(chat: widget.chat),
      ],
    ),
  );

  /// The page, and over it why it didn't load when it didn't.
  Widget _page(BrowserHost host) => Stack(
    fit: StackFit.expand,
    children: [
      ClearOfEdge(child: host.view(context)),
      ValueListenableBuilder(
        valueListenable: host.failed,
        builder: (context, failed, _) =>
            failed == null ? const SizedBox.shrink() : _Failed(failed),
      ),
    ],
  );
}

/// A new tab's page: what to type.
class _NewTab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NushiTheme.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            LineIcon.globe.view(size: 28, color: t.textMuted),
            Text(
              browserHint,
              textAlign: TextAlign.center,
              style: theme.ui(t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Over a page that didn't load: where it was going (the address that
/// failed, not the tab's), what went wrong ([failedHeading]), and the web
/// view's reason.
class _Failed extends StatelessWidget {
  const new(this.failure);

  final PageFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final where = hostOf(failure.url);
    return ColoredBox(
      color: t.base,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(NushiTheme.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                failedHeading(failure.kind, where),
                textAlign: TextAlign.center,
                style: theme.ui(t.text, weight: FontWeight.w500),
              ),
              Text(
                failure.reason,
                textAlign: TextAlign.center,
                style: theme.ui(t.textSecondary, size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
