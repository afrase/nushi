import 'package:flutter/material.dart';

import 'theme/theme.dart';
import 'widgets.dart';

/// Key/value rows: env vars or headers.
class Pairs {
  final rows = <(TextEditingController, TextEditingController)>[];

  void load(Object? m) {
    _later(rows);
    rows.clear();
    for (final MapEntry(:key, :value) in (m as Map? ?? {}).entries) {
      add('$key', '$value');
    }
  }

  void add([String k = '', String v = '']) => rows.add((
    TextEditingController(text: k),
    TextEditingController(text: v),
  ));

  /// Takes row [i] out.
  void removeAt(int i) => _later([rows.removeAt(i)]);

  /// Disposes rows' fields once the frame that drops them is done.
  static void _later(
    List<(TextEditingController, TextEditingController)> gone,
  ) {
    final copy = [...gone];
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispose(copy));
  }

  static void _dispose(
    List<(TextEditingController, TextEditingController)> rows,
  ) {
    for (final (k, v) in rows) {
      k.dispose();
      v.dispose();
    }
  }

  void dispose() => _dispose(rows);

  Map<String, String> get map => {
    for (final (k, v) in rows)
      if (k.text.trim().isNotEmpty) k.text.trim(): v.text,
  };
}

/// Key/value rows, each removable, and a row to add one.
class PairRows extends StatelessWidget {
  const new(this.pairs, this.hint, this.changed, {super.key});

  final Pairs pairs;
  final String hint;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final theme = NushiTheme.of(context), t = theme.t;
    final mono = theme.code(t.text, size: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (k, v)) in pairs.rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: k,
                    style: mono,
                    decoration: InputDecoration(hintText: hint),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: v,
                    style: mono,
                    decoration: const InputDecoration(hintText: 'value'),
                  ),
                ),
                IconTap(
                  Icons.close,
                  tooltip: 'Remove',
                  size: 14,
                  onTap: () {
                    pairs.removeAt(i);
                    changed();
                  },
                ),
              ],
            ),
          ),
        Button(
          label: 'Add',
          icon: Icons.add,
          kind: ButtonKind.ghost,
          height: 22,
          onPressed: () {
            pairs.add();
            changed();
          },
        ),
      ],
    );
  }
}
