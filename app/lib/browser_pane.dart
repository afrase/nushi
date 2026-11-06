import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nushi/browser_bar.dart';
import 'package:nushi/browser_page.dart';
import 'package:nushi/chat.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/panes.dart';
import 'package:nushi/preview_entry.dart';
import 'package:nushi/preview_tabs.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/tool_parts.dart' show plainPath;
import 'package:nushi/web_page.dart' show openInBrowser;

/// The chat header's browser button (ADR 0094): it shows the preview's last
/// browser tab, or a new one, on the Chat tab; lit while one shows there.
class BrowserButton extends StatelessWidget {
  const new({required this.chat, super.key});

  final ChatState chat;

  /// What it says, and its row in the header's ⋯ when it folds there.
  static const tooltip = 'Browser';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chat.preview, chat.tab]),
    builder: (context, _) {
      final t = NushiTheme.of(context).t;
      return IconTap.line(
        LineIcon.globe,
        tooltip: tooltip,
        color: chat.browserShown ? t.accentInk : t.textSecondary,
        onTap: chat.showBrowser,
      );
    },
  );
}

/// What a new browser tab says under its address field.
const browserHint = 'Enter a local address, like localhost:3000';

/// A browser tab in the preview pane (ADR 0094): the pane's title row (its
/// tabs, or the one tab's title, a + that opens a new browser tab, Close,
/// which closes every tab), then [BrowserBar], then the page, or for a new
/// tab a hint. Like a file's view it's made again as its tab shows: the
/// page loads again from the tab's address.
class BrowserPane extends StatefulWidget {
  const new({
    required this.chat,
    required this.tab,
    required this.onClose,
    super.key,
    this.tabsKey,
  });

  final ChatState chat;
  final BrowserTab tab;
  final VoidCallback onClose;

  /// The key of its [PreviewTabs] (`PreviewPane.tabsKey`).
  final Key? tabsKey;

  @override
  State<BrowserPane> createState() => _BrowserPaneState();
}

class _BrowserPaneState extends State<BrowserPane> implements BrowserControls {
  BrowserHost? _host;
  late final _address = TextEditingController(text: widget.tab.address.value);
  final _field = FocusNode(debugLabel: 'address');

  BrowserTab get _tab => widget.tab;

  @override
  void initState() {
    super.initState();
    _tab
      ..view = this
      ..address.addListener(_moved);
    _field.addListener(_moved);
    if (addressOf(_tab.address.value) case (:final url, here: true)) {
      _open(url);
    } else {
      // A new tab waits on its address.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _field.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (identical(_tab.view, this)) _tab.view = null;
    _tab.address.removeListener(_moved);
    _field.removeListener(_moved);
    _host?.dispose();
    _address.dispose();
    _field.dispose();
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
    final host = _host ??= newBrowserHost(_tab);
    unawaited(host.open(url));
  }

  /// The field's text on Return: a local page loads here, another site
  /// opens in the default browser (the user asked, ADR 0094), and anything
  /// else is refused, saying why.
  void _go(String text) {
    final say = ScaffoldMessenger.maybeOf(context);
    void note(String text) => say
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    switch (addressOf(text)) {
      case (:final url, here: true):
        _field.unfocus();
        setState(() => _open(url));
      case (:final url, here: false):
        unawaited(openInBrowser(url).catchError((_) {}));
        _address.text = _tab.address.value;
        note('Opened in your browser: a browser tab shows this Mac’s pages');
      case null:
        note('Only a local address opens here, like localhost:3000');
    }
  }

  @override
  void focusAddress() {
    // WebKit may hold the keys while Flutter still thinks the field has the
    // focus: asked again, the field takes them back.
    _field
      ..unfocus()
      ..requestFocus();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHeader(
          child: Row(
            spacing: 8,
            children: [
              LineIcon.globe.view(size: 14, color: t.textSecondary),
              Expanded(child: _tabs()),
              IconTap.line(
                LineIcon.close,
                tooltip: 'Close',
                size: 15,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        BrowserBar(host: host, address: _address, focus: _field, onGo: _go),
        Expanded(
          child: ColoredBox(
            color: t.base,
            child: host == null ? const _NewTab() : _page(host),
          ),
        ),
      ],
    );
  }

  /// The tabs (or the one tab's title) and the + right after them.
  Widget _tabs() => ValueListenableBuilder(
    valueListenable: widget.chat.previewTabs,
    builder: (context, open, _) => Row(
      children: [
        Flexible(
          child: open.length > 1
              ? PreviewTabs(
                  key: widget.tabsKey,
                  chat: widget.chat,
                  tabs: open,
                  current: _tab,
                )
              : _Title(_tab),
        ),
        IconTap.line(
          LineIcon.plus,
          tooltip: 'New browser tab',
          size: 14,
          padding: 4,
          onTap: widget.chat.openBrowserTab,
        ),
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
            failed.isEmpty ? const SizedBox.shrink() : _Failed(_tab, failed),
      ),
    ],
  );
}

/// The one browser tab's title, plain, where a tab's would be, its address
/// in a tooltip.
class _Title extends StatelessWidget {
  const new(this.tab);

  final BrowserTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([tab.title, tab.address]),
      builder: (context, _) => Tooltip(
        message: plainPath(tab.address.value),
        child: Padding(
          padding: const EdgeInsets.only(left: previewNameInset, right: 4),
          child: Text(
            tab.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.ui(theme.t.text, size: 12),
          ),
        ),
      ),
    );
  }
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

/// Over a page that didn't load: where it was going, and WebKit's reason.
class _Failed extends StatelessWidget {
  const new(this.tab, this.reason);

  final BrowserTab tab;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final where = Uri.tryParse(tab.address.value)?.authority ?? '';
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
                where.isEmpty ? 'The page didn’t load' : 'Can’t reach $where',
                textAlign: TextAlign.center,
                style: theme.ui(t.text, weight: FontWeight.w500),
              ),
              Text(
                reason,
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
