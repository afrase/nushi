part of 'source_view.dart';

// A source view's two lists: wrapped, each line a row of its number and
// its text; run on, the lines scrolling sideways under their numbers,
// which stay over them in the view's colour.

extension on _SourceViewState {
  /// The Blame gutter's look in a pane [pane] wide, while Blame is on.
  BlameLook? _lookIn(double pane, _Drawn d) => widget.blame == null
      ? null
      : BlameLook(context, pane: pane, scaler: d.scaler);

  /// The padding in a [viewport] that high: scrolled past the end, the
  /// last line can come to the top.
  EdgeInsets _padded(double viewport) {
    final pad = _pad;
    if (!widget.pastEnd) return pad;
    return pad.copyWith(
      bottom: pastEndPadding(
        viewport,
        _lineHeight,
        top: pad.top,
        bottom: pad.bottom,
      ),
    );
  }

  /// The lines wrapped, the Blame gutter left of the numbers while on.
  Widget _wrappedView(_Drawn d) {
    Widget blamed(int i, Widget line, {required BlameLook? look}) =>
        look == null
        ? line
        : Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: look.width + blameGap),
                child: line,
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: look.width,
                child: _blameCell(i, look),
              ),
            ],
          );
    return _selectable(
      _wholeWrapped,
      LayoutBuilder(
        builder: (context, box) {
          final look = _lookIn(box.maxWidth, d);
          return ListView.builder(
            key: _wrapped,
            controller: _down,
            padding: _padded(box.maxHeight),
            itemCount: _lines.length,
            itemBuilder: (context, i) => blamed(
              look: look,
              i,
              _marked(
                i,
                cell: d.digits * d.char + markGap + markBar + markRoom,
                bar: d.digits * d.char + markGap,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectionContainer.disabled(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: markGap + markBar + markRoom,
                        ),
                        child: Text(d.number(i), style: d.gutter),
                      ),
                    ),
                    Expanded(child: d.line(i, wrapped: true)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The lines run on, scrolling sideways under their numbers' column.
  Widget _runOnView(_Drawn d) {
    final (t, char, digits) = (d.t, d.char, d.digits);
    final pad = _pad;
    return LayoutBuilder(
      builder: (context, box) {
        final look = _lookIn(box.maxWidth, d);
        final blameWidth = look == null ? 0.0 : look.width + blameGap;
        // The numbers' column, the view's inset with them: it stays as
        // the lines scroll under it, over them in the view's color.
        final numbers = _numbers =
            pad.left +
            blameWidth +
            digits * char +
            markGap +
            markBar +
            markRoom +
            1;
        final width = numbers + _widest * char + pad.right;
        return MacScrollbar(
          controller: _down,
          notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
          child: MacScrollbar(
            controller: _across,
            notificationPredicate: (n) =>
                n.depth == 0 && n.metrics.axis == Axis.horizontal,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: _selectable(
                _wholeRunOn,
                SingleChildScrollView(
                  controller: _across,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: max(box.maxWidth, width),
                    child: ListView.builder(
                      key: _runOn,
                      controller: _down,
                      padding: EdgeInsets.only(
                        top: pad.top,
                        bottom: _padded(box.maxHeight).bottom,
                      ),
                      itemExtent: _lineHeight,
                      itemCount: _lines.length,
                      itemBuilder: (context, i) => Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: numbers),
                            child: d.line(i, wrapped: false),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: numbers,
                            child: SelectionContainer.disabled(
                              child: ListenableBuilder(
                                listenable: _across,
                                builder: (context, child) =>
                                    Transform.translate(
                                      offset: Offset(
                                        _across.hasClients ? _across.offset : 0,
                                        0,
                                      ),
                                      child: child,
                                    ),
                                child: ColoredBox(
                                  color: t.base,
                                  child: look == null
                                      ? _marked(
                                          i,
                                          cell: numbers,
                                          bar:
                                              pad.left +
                                              digits * char +
                                              markGap,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: pad.left,
                                            ),
                                            child: Text(
                                              d.number(i),
                                              style: d.gutter,
                                              softWrap: false,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SizedBox(width: pad.left),
                                            SizedBox(
                                              width: look.width,
                                              child: _blameCell(i, look),
                                            ),
                                            const SizedBox(width: blameGap),
                                            Expanded(
                                              child: _marked(
                                                i,
                                                cell:
                                                    numbers -
                                                    pad.left -
                                                    blameWidth,
                                                bar: digits * char + markGap,
                                                child: Text(
                                                  d.number(i),
                                                  style: d.gutter,
                                                  softWrap: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
