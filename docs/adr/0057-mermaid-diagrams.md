# 0057. Mermaid diagrams: a pinned mermaid.js, drawn by WebKit, pictures in the transcript

Status: accepted, 2026-10-28 (step 378).

## Context
Agents draw diagrams as Mermaid: ```` ```mermaid ```` blocks in their messages and Markdown files, and `.mmd` files. Only mermaid.js draws them faithfully (its layouts, its text measured by a browser), and the owner wants no CDN at runtime and few JS dependencies.

## Decision
- **One copy of `mermaid.min.js`, pinned** in `tools/mermaid/mermaid.lock` (its release, sha256 and size), fetched at build time from jsDelivr into a cache outside the repository and checked (`make mermaid`, before `package`, `web` and `app`); not committed. A new release is `go run ./tools/mermaid -lock X.Y.Z`, which takes the file only when jsDelivr and unpkg give the same bytes. It sits beside `mermaid.html` (Nushi's page, `show(source, opts)`) among the app's Flutter assets, so the Mac app and the phone's web build both carry it.
- **Mermaid's strict security level** everywhere: labels are text, no clicks or links. The page's web views refuse every navigation but the page itself.
- **The Mac.** A `.mmd` file's preview is a WKWebView of `mermaid.html` (each change drawn again). A block in the transcript or in a Markdown preview is drawn once, by one hidden WKWebView in an off-screen window (Swift, `nushi/mermaid`), at the block's width, snapshot as a PNG at the screen's scale, kept by its text and colors, and shown as an image (Diagram and Source in its bar), scaled down in a narrower block. A web view per block would be heavy; SVG through Flutter can't draw Mermaid's HTML labels.
- **The phone.** A `.mmd` file shows in the sandboxed frame of 0054's previews (step 376), its page Nushi's `mermaid.html` with the relay's copy of the script (served with `Cross-Origin-Resource-Policy: cross-origin` for the frame's opaque origin, and kept out of the service worker's shell); a transcript block shows its source and Show diagram, which opens that frame full screen.
- **Never half a diagram**: a block still streaming in (its fence not closed; heal's `openMark`) shows its source; a diagram that doesn't parse shows its source and the error in one muted line.

## Consequences
- 5.4 MB more in the app and the web build (1.1 MB with Brotli, fetched by the phone only when it shows a diagram).
- A transcript diagram doesn't follow a resize past the width it was drawn at (it scales down, never up) until the app runs again; a theme change draws it anew.
- A Mermaid upgrade is a lock change and a rebuild; nothing updates by itself.
