# 0012. The diff viewer uses the published diff_view package

## Context
The diff viewer is half the product. `diff_view` (pub.dev, source in `~/Developer/diff_view`) already has the painter and the line and word diff.

## Decision
The app depends on `diff_view`. Improvements to diffing or painting go into that package, never into a copy inside Nushi.

## Consequences
- Some changes need a `diff_view` release (or a temporary `path:` override) before Nushi can use them.
