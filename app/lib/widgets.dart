import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_view/markdown_view.dart';
import 'package:nushi/clock.dart';
import 'package:nushi/commits.dart';
import 'package:nushi/controls.dart';
import 'package:nushi/errors.dart';
import 'package:nushi/motion.dart';
import 'package:nushi/spinner.dart';
import 'package:nushi/theme/theme.dart';
import 'package:nushi/toast.dart';

export 'package:nushi/controls.dart';
export 'package:nushi/errors.dart';
export 'package:nushi/toast.dart';

/// Shows [message] in a toast, as a failure ([showFailure]).
void showError(BuildContext context, Object message) =>
    showFailure(Toasts.maybeOf(context), errorText(message));

/// Runs a call, showing its error, if any, in a toast: the app's, also
/// once the widget that asked is gone (a trust card replaced it).
Future<void> tryOrShow(
  BuildContext context,
  Future<void> Function() call,
) async {
  final toasts = Toasts.maybeOf(context);
  try {
    await call();
  } on Object catch (e) {
    showFailure(
      context.mounted ? Toasts.maybeOf(context) : toasts,
      errorText(e),
    );
  }
}

/// What a call run by [runAndSay] answers with: its words and an icon of
/// their own (a check, an info mark), never the spinner's place holder.
typedef CallAnswer = ({String text, Widget icon});

/// Runs a call that shows nothing of its own while it runs, saying so in
/// a toast: [running] with a spinner (when it takes longer than a
/// moment), then its answer, or its error ([showFailure]). The answer is
/// [done] with a check, or what [answer] makes of the call's result (it
/// may act on it first: Check for updates forgets a dismissed release);
/// with neither, or [answer] giving null (what it made shows), the toast
/// just goes. The two never look alike (ADR 0128). The answer takes the
/// spinner's place when it showed, else waits its turn, so a quick call
/// never knocks out a toast that was showing; the error always takes the
/// showing toast's place, so it never waits unseen behind another call's
/// spinner (which stays minutes).
Future<void> runAndSay<T>(
  BuildContext context,
  Future<T> Function() call, {
  required String running,
  String? done,
  CallAnswer? Function(T result)? answer,
}) async {
  assert(done == null || answer == null, 'done or answer, not both');
  final toasts = Toasts.maybeOf(context);
  final t = NushiTheme.of(context).t;
  // Said only past a moment: a quick call goes straight to its answer.
  var shown = false;
  final slow = Timer(Waits.slow, () {
    shown = true;
    showToast(
      toasts,
      running,
      leading: const Spinner(),
      replace: true,
      duration: const Duration(minutes: 5),
    );
  });
  final T result;
  try {
    result = await call();
  } on Object catch (e) {
    showFailure(toasts, errorText(e), replace: true);
    return;
  } finally {
    slow.cancel();
  }
  final said = switch (done) {
    final done? => (
      text: done,
      icon: Icon(Icons.check_circle, size: 16, color: t.done),
    ),
    null => answer?.call(result),
  };
  if (said != null) {
    showToast(toasts, said.text, leading: said.icon, replace: shown);
  } else if (shown) {
    toasts?.hide();
  }
}

/// One call at a time: [run] does nothing while a call it started runs (a
/// double click answers once), and shows the call's error, if any, as
/// [tryOrShow] does. [value] says whether one runs.
class Runner extends ValueNotifier<bool> {
  new() : super(false);

  bool _disposed = false;

  Future<void> run(BuildContext context, Future<void> Function() call) async {
    if (value) return;
    value = true;
    try {
      await tryOrShow(context, call);
    } finally {
      if (!_disposed) value = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A [Button] whose action is a call: off while it runs, so a double click
/// sends once; [runner] shares that with other buttons (a card's answers),
/// else it's the button's own. Off when [run] is null.
class RunButton extends StatefulWidget {
  const new({
    required this.label,
    required this.run,
    super.key,
    this.runner,
    this.kind = ButtonKind.secondary,
    this.icon,
    this.hint,
    this.tooltip = '',
    this.running,
    this.wrap = false,
  });

  final String label;
  final Future<void> Function()? run;
  final Runner? runner;
  final ButtonKind kind;
  final IconData? icon;
  final String? hint;
  final String tooltip;

  /// Its label while the call runs ("Reloading…"); [label] if none. The
  /// button keeps room for both, so it doesn't change width as it's
  /// pressed, longer or shorter, and what's beside it stays put.
  final String? running;
  final bool wrap; // Button.wrap

  @override
  State<RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<RunButton> {
  Runner? _own;

  Runner get _runner => widget.runner ?? (_own ??= Runner());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _runner,
    builder: (context, running, _) => Button(
      label: running ? widget.running ?? widget.label : widget.label,
      roomFor: [?widget.running, widget.label],
      kind: widget.kind,
      icon: widget.icon,
      hint: widget.hint,
      tooltip: widget.tooltip,
      wrap: widget.wrap,
      onPressed: switch (widget.run) {
        final run? when !running => () => _runner.run(context, run),
        _ => null,
      },
    ),
  );
}

/// Scrolls the row keyed [row] (a list's selected row) into view once this
/// frame is drawn: at the list's end when moving [down], else its start;
/// then, a frame later (rows the scroll brought in are built), [then].
/// A lazy list builds the rows near the screen only, so the selection moves
/// a row at a time with this, never past what's built.
void revealRow(GlobalKey row, {required bool down, VoidCallback? then}) {
  final binding = WidgetsBinding.instance;
  binding
    ..addPostFrameCallback((_) async {
      if (row.currentContext case final c? when c.mounted) {
        await Scrollable.ensureVisible(
          c,
          alignmentPolicy: down
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
      if (then != null) {
        binding
          ..addPostFrameCallback((_) => then())
          ..scheduleFrame();
      }
    })
    ..scheduleFrame();
}

/// Scrolls [scroll]'s list of rows [row] high just far enough that its
/// [index]th shows: [revealRow] for a row that may not be built yet.
void revealRowAt(ScrollController scroll, int index, double row) {
  if (!scroll.hasClients) return;
  final p = scroll.position;
  final top = index * row;
  if (top < p.pixels) {
    p.jumpTo(top);
  } else if (top + row > p.pixels + p.viewportDimension) {
    p.jumpTo(top + row - p.viewportDimension);
  }
}

/// What [builder] makes, built knowing whether the pointer is over it: for
/// what shows only under the pointer (a row's Stop, a card's Remove).
class Hover extends StatefulWidget {
  const new({required this.builder, super.key});

  final Widget Function(BuildContext context, {required bool hover}) builder;

  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(context, hover: _hover),
  );
}

/// A dialog: [title], [content] [width] wide (460 unless a form needs
/// more), and its [actions], at the right unless [actionsAlignment] says
/// otherwise, large (ADR 0122). [onClose] puts a × at the title's end, as
/// Claude desktop's dialogs that are lists to manage have.
Widget nushiDialog(
  String title,
  Widget content,
  List<Widget> actions, {
  VoidCallback? onClose,
  MainAxisAlignment? actionsAlignment,
  double width = 460,
  // design: the one AlertDialog, which every other dialog is.
}) => AlertDialog(
  title: onClose == null
      ? Text(title)
      : Row(
          children: [
            Expanded(child: Text(title)),
            // Its glyph's right edge at the content's, past the button's
            // padding.
            Transform.translate(
              offset: const Offset(5, 0),
              child: IconTap.line(
                LineIcon.close,
                tooltip: 'Close',
                onTap: onClose,
              ),
            ),
          ],
        ),
  content: SizedBox(width: width, child: content),
  actions: [for (final a in actions) ControlScale.large(child: a)],
  actionsAlignment: actionsAlignment,
);

/// Asks [title] with [text] in a dialog; true once [action] is pressed
/// ([destructive]: it deletes or loses something, so it's in red, and
/// Cancel has the focus, so Enter never deletes, as the Mac's alerts).
Future<bool> confirm(
  BuildContext context,
  String title,
  String text,
  String action, {
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => nushiDialog(title, Text(text), [
        Button(
          label: 'Cancel',
          autofocus: destructive,
          onPressed: () => Navigator.pop(context, false),
        ),
        Button(
          label: action,
          kind: destructive ? ButtonKind.destructive : ButtonKind.primary,
          autofocus: !destructive,
          onPressed: () => Navigator.pop(context, true),
        ),
      ]),
    ) ??
    false;

/// The chevron of something that opens: down while [open].
class Chevron extends StatelessWidget {
  const new({required this.open, super.key, this.size = 14, this.color});

  final bool open;
  final double size;
  final Color? color; // the muted text color if not given

  @override
  Widget build(BuildContext context) => Icon(
    open ? Icons.expand_more : Icons.chevron_right,
    size: size,
    color: color ?? NushiTheme.of(context).t.textMuted,
  );
}

/// A tool call's title (a command) whole, wrapped, in monospace, on a
/// block of code's surface; [bare], where it sits on one already (a
/// call's open row), the text alone.
class FullTitle extends StatelessWidget {
  const new(this.title, {super.key, this.bare = false});

  final String title;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    final text = Marks(
      child: Text(
        title,
        style: theme.code(t.text, size: 12).copyWith(height: 1.35),
      ),
    );
    if (bare) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.codeBlock,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: text,
    );
  }
}

/// [child] dimmed, and not to be clicked, while [on]: what it shows is
/// being replaced.
class Dimmed extends StatelessWidget {
  const new({required this.on, required this.child, super.key});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: on,
    child: AnimatedOpacity(
      opacity: on ? 0.4 : 1,
      duration: Motion.quick,
      child: child,
    ),
  );
}

/// A list's rows while the first answer is on its way: bars where a row's
/// key, title and details will be, never a blank view.
class RowsLoading extends StatelessWidget {
  const new({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = NushiTheme.of(context).t;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.lifted,
        borderRadius: BorderRadius.circular(NushiTheme.tag),
      ),
    );
    return Semantics(
      label: 'Loading',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  bar(72, 9),
                  // Titles of a few widths, as a list's are.
                  FractionallySizedBox(
                    widthFactor: const [0.8, 0.55, 0.7][i % 3],
                    child: bar(double.infinity, 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// What the bar says of what shows: "Updated 3m ago, refreshing" for
/// what was kept from last time while it's asked again, "Updated 3m ago"
/// once asking failed, "Loading…" with nothing kept; "Couldn't refresh,
/// as of 3m ago" once a quiet poll [failed] (what shows is the last
/// answer, from [updated]; ADR 0046).
String? updatedLine(
  DateTime? updated, {
  required bool loading,
  bool failed = false,
}) {
  if (updated == null) return loading ? 'Loading…' : null;
  final when = ago(clock().difference(updated), updated);
  if (failed && !loading) return '$couldNotRefresh, as of $when';
  return 'Updated $when${loading ? refreshingWords : ''}';
}

/// What [updatedLine] adds while it's asked again.
const refreshingWords = ', refreshing';

/// How a failed refresh's line starts, all a narrow bar says of it.
const couldNotRefresh = "Couldn't refresh";

/// [updatedLine]'s [line] as it shows (the bars', an issue's or a pull
/// request's page): muted, or once a quiet poll [failed] in the failure's
/// ink after its mark, so "Couldn't refresh" never reads as a plain time
/// (docs/design.md: a state cue is unmistakable); [short] (a narrow bar)
/// says only that, the whole line on hover. [busy] puts a spinner before
/// it while it's asked again (a page's own line, where a Refresh is
/// pressed).
Widget updatedText(
  BuildContext context,
  String line, {
  required bool failed,
  bool short = false,
  bool busy = false,
  double size = 12,
  Key? key,
}) {
  final theme = NushiTheme.of(context);
  final t = theme.t;
  if (!failed) {
    final style = theme.ui(t.textMuted, size: size);
    if (!busy) return Text(line, key: key, style: style);
    return Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        SizedBox.square(
          dimension: size,
          child: Spinner(color: t.textMuted),
        ),
        Text(line, style: style),
      ],
    );
  }
  final shown = Row(
    key: key,
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [
      Icon(Icons.sync_problem, size: size + 2, color: t.crashed),
      Flexible(
        child: Text(
          short && line.startsWith(couldNotRefresh) ? couldNotRefresh : line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.ui(t.crashed, size: size),
        ),
      ),
    ],
  );
  return short ? tooltip(context, line, shown) : shown;
}

/// A line above the list: a problem, or what shows is old. [margin] sets
/// it in from what it sits in (a pane's edges by default; the composer's
/// box lines it up with its own).
class Notice extends StatelessWidget {
  const new(
    this.text, {
    super.key,
    this.action,
    this.onAction,
    this.margin = const EdgeInsets.fromLTRB(10, 8, 10, 0),
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context);
    final t = theme.t;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: t.needsSoft,
        borderRadius: BorderRadius.circular(NushiTheme.control),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: theme.ui(t.needs, size: 12))),
          if (action case final a?) ...[
            const SizedBox(width: 8),
            Button(label: a, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
