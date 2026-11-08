# 0102. Loops run on a 20 Hz pulse, only while Nushi is in front

Status: accepted, 2026-11-09.

## Context
What loops for as long as a state lasts (a working chat's ring, the slow pulse of work in the background, a pull request's running checks, a shine over "Thinking…", the reply's caret, a spinner) repainted from a Ticker at the display's rate. A state like that can last hours: a command in the background, a dev server a code block started. On the Mac, Impeller draws the whole window again on every frame (no raster cache), so each tick redraws all of the window's text. One Claude chat with a `sleep 10` loop in the background kept an idle Nushi at 40-50% of a core and the window server at ~60%: `sample` saw about 50 frames a second, the raster thread busy in Impeller's text work the whole time.

## Decision
- **One clock, `pulseClock`** (`app/lib/motion.dart`), for everything that loops: a timer at `pulseRate`, 20 ticks a second, about the fewest at which a shine still sweeps rather than steps across a title (its band moves two text widths in two seconds). A ring grows less than a pixel a tick, and a breath or the caret fades. Its time is its ticks, so every loop is in step and a test's fake time moves it.
- **It ticks only while Nushi is in front**: the app's state is resumed (the Mac's window focused, the phone's page in front; unknown counts as in front). Inactive (visible beside the focused app), hidden or paused, it stands still.
- **Standing still, each loop draws its rest look**, as under Reduce Motion: a working chat's dot without its ring, the background ring at full strength, a spinner's ring three parts drawn, a shine's text as it is. The clock notifies once as it stops and once as it starts, so each loop repaints into or out of it.
- **It stops when no one listens**, but only after the work at hand: a painter made anew on a rebuild leaves the clock and its successor joins in the same frame.
- What runs once (a check drawing, a title typing) and the reply's pacing stay on the per-frame `frameClock`: they end on their own, a run within a second or two, the pacing once the reply's text has shown.

## Consequences
- An idle Nushi draws nothing; one with a loop showing draws 20 frames a second while focused, none otherwise.
- A chat working while the user is in their editor beside Nushi shows its state by color and shape, not motion, until Nushi is focused again.
- The rate is reasoned from the shine's speed (a band moving a text width a second moves 5% of it a tick), not compared on screen with others; if a shine steps, `pulseRate` is the one number to raise.

## Alternatives considered
- The display's rate while focused, still while hidden: keeps the half a core for as long as Nushi has the focus and anything loops.
- Moving while visible but not focused: what's beside the editor is what the user glances at, but a background command can run for hours with Nushi on a second display, at the same cost.
- Fewer ticks (10 a second): a shine's band would jump a tenth of the text's width each tick.
