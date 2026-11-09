# 0106. A preview's path line, source button and outline

Status: accepted, 2026-11-09. Amends [ADR 0071](0071-one-look-for-tabs.md) (the preview's Preview and Source tabs).

## Context
The owner asked for Markdown previews as Claude's desktop app has them (2026-11-09, with screenshots): the file's path in a quiet line over the document, which copies it; a single `</>` button at its right end ("View source") in place of the Preview and Source tabs; and an outline, a rail of dashes left of the text, one per heading, whose menu lists the headings and goes to one. Nushi's tabs sat in the pane's title row, beside Live, wrap and the actions, for Markdown, HTML, SVG, CSV and Mermaid alike.

## Decision
- **Every file preview has a path line** under its title row, the Mac's and the phone's: the path relative to the chat's folder (`docs / roadmap.md`), from `~` outside it. A click copies what it shows as a path (`docs/roadmap.md`, or the absolute path outside the folder) and says "Copied".
- **The source button replaces the tabs for every file that rendered with them**, not only Markdown, so the header is one shape: `</>` at the path line's right end, under Close, "View source"; while the source shows it's lit (the accent's fill and ink, `IconTap.lit`), "View preview". Source is still remembered per file, and the source is still where a file is edited (ADR 0096). The wrap button stays in the title row.
- **The outline is Markdown's only**, with two headings or more, and not over the source: the pins rail's widgets ([ADR 0085](0085-pinned-messages-kept-by-the-daemon.md), now `Rail`) with an outline's look (the current dash in the accent, the others indented by level, the menu's titles lined up and indented). Levels count from the top-most heading, from the next one when a single title leads (as Claude's does), at most three. The current heading is the last at or above the view's top; one picked stays current while the view stays where the pick took it, though the text's end keeps it from the top. A pick scrolls smoothly, at once under Reduce Motion; the phone opens the menu with a tap.
- **The headings are found by marks in the text**: `StreamingMarkdown.headingMark` puts a zero-size widget at the start of each heading's line, once the text has finished streaming, through marked ATX and setext heading syntaxes. Each mark tells the outline its level, text and place; the outline orders them by place. Copying a heading leaves the mark out; a finder of a heading's exact text no longer matches (`find.textContaining`).

## Consequences
- The title row lost a control and the tabs' width; the path line costs a line of height in every preview.
- The text of a Markdown preview with an outline starts 40 points further right (36 from the edge in a pane under 480 wide, and on the phone), for the rail.

## Alternatives considered
- Tabs for the other kinds, the button for Markdown: two shapes of header for one pane.
- Finding headings by splitting the text into a body per section: a reference link's definition is the whole text's, and the gaps between bodies differ from the blocks'.
- Finding the heading widgets in the render tree by style: depends on how flutter_markdown_plus builds them.
