# 0026. The transcript lays out every item

## Context
Until milestone I the transcript was a lazy list. A lazy list only estimates its height from the items built so far, so the scrollbar thumb changed size while scrolling, the height shifted under the user, and following the bottom pulled a slow scroll back down.

## Decision
- The transcript is a `Column` in a `SingleChildScrollView`: every item is laid out. Each entry's widget is kept while its items are the same objects, so a streamed chunk rebuilds only the message it changes; a code block is highlighted once.
- It fills in from the bottom (2026-10-30): a transcript that opens at its bottom builds its last 12 entries in its first frame and 24 more in each frame after, until all are laid out; what shows stays put if the user scrolls up meanwhile. Picking a long chat showed nothing for one 200–330 ms frame (debug, 300 items), so the click seemed lost; now its first frame is 35–75 ms and the rest comes in about five frames. One that opens at its top (a finished subagent's) builds all at once.
- Following the bottom stops only on the user's own scroll up (not a fling's spring back past the bottom) and resumes at the bottom.

## Consequences
- Opening a very long chat costs a full layout (measured in a debug widget test with 300 items: 28 ms per streamed chunk, 100 ms for a relayout; a lazy list was 8 ms per chunk but 418 ms to jump to the top). Release builds are several times faster.
- Going back to a lazy list brings the scroll bugs back unless the list can know its height.
- While it fills in (about 0.1 s), the scrollbar's thumb shrinks and the top isn't there yet.
