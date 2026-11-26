import 'package:diff_view/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nushi/diff_box.dart';
import 'package:nushi/gen/nushi/v1/nushi.pb.dart';
import 'package:nushi/markdown.dart';
import 'package:nushi/theme/theme.dart';

import 'fake_daemon.dart';
import 'harness.dart';

const _old = '''
class Sprinkler < Base
  # @param beds [Array<Bed>] every bed on the plot
  def driest_bed(beds)
    @next = beds.min_by(&:moisture) || self.nearest(:shed)
  end
end
''';

const _new = '''
class Sprinkler < Base
  NOZZLES = 4

  # @param beds [Array<Bed>] every bed on the plot
  # @return [Bed, nil] none on a day it rained
  def driest_bed(beds)
    @next = beds.min_by(&:moisture) || self.nearest(:shed) || @@spare
    puts "#{beds.size} beds, #{NOZZLES} nozzles", nil, @next
  end
end
''';

const _block = r'''
A code block:

```ts
/** @param bed which one to soak */
export class Sprinkler extends Base {
  minutes = 12;
  soak(bed: number): string {
    return `${bed} is soaked` + /x+/g;
  }
}
```
''';

/// A Ruby diff and a TypeScript code block, in both themes.
const _others = r'''
```jsonnet
// The service, one per region.
local service(name, port=8080) = {
  apiVersion: 'v1',
  kind: 'Service',
  metadata+: { name: name, labels:: { app: name } },
  spec: { ports: [{ port: port }] },
};

{
  regions:: ['eu', 'us'],
  note: |||
    Rendered by the deploy job.
  |||,
  services: [service(r + '-api') for r in self.regions],
  count: std.length(self.services),
}
```

```tf
# Where the logs go.
resource "aws_s3_bucket" "logs" {
  bucket = "${var.name}-logs"
  tags   = { team = "infra" }

  lifecycle {
    prevent_destroy = true
  }
}
```

```zig
const std = @import("std");

/// Adds one.
pub fn inc(x: u32) u32 {
    return x + 1;
}
```
''';

void main() {
  setUpAll(loadFonts);
  for (final (name, tokens) in [
    ('dark', Tokens.dark),
    ('light', Tokens.light),
  ]) {
    testWidgets('syntax colors ($name)', (tester) async {
      viewport(tester, const Size(900, 560));
      await tester.pumpWidget(
        themed(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 240,
                child: DiffBox(
                  FileChange(path: 'garden.rb', oldText: _old, newText: _new),
                  fit: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: AgentMarkdown(_block),
              ),
            ],
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      // The diff's colors come from an isolate.
      final lines = tester
          .widget<SideBySideDiff>(find.byType(SideBySideDiff))
          .controller
          .lines;
      await untilReal(
        tester,
        () => lines.lineAt(PaneSide.neu, 0)!.syntax.isNotEmpty,
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/syntax_$name.png'),
      );
    });

    testWidgets('jsonnet, HCL and Zig ($name)', (tester) async {
      viewport(tester, const Size(720, 760));
      await tester.pumpWidget(
        themed(
          const Padding(
            padding: EdgeInsets.all(12),
            child: SingleChildScrollView(child: AgentMarkdown(_others)),
          ),
          tokens: tokens,
          banner: false,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/syntax_others_$name.png'),
      );
    });
  }
}
