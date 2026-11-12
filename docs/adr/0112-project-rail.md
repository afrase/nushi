# 0112. A rail of project tiles at the sidebar's left

Status: accepted, 2026-11-12; tried as a beta (ADR 0108) before it's released.

## Context
The redesign's mock (ADR 0111) has a Projects page: a narrow rail of square tiles beside the chats, one a project, and the same tile small before each project's name. ADR 0111 left it as a separate decision. The owner approved it (2026-11-12), with one complaint about the mock itself: same-shaped two-letter squares look alike, so a tile has to tell projects apart by more than two letters.

## Decision
- **The project rail** is a column 48 wide at the left of the sidebar's chats, under its top strip, so it hides with the sidebar: **All projects**, a short hairline, a tile for each project in the sidebar's order (kept empty ones too), then a dashed **Add project…**, which adds a folder picked in the system's panel to the sidebar's projects (`keepProject`) and starts no chat. Tiles are 38 square with a control's corners; the first is level with New chat, which is as high. It scrolls when they don't fit.
- **A tile narrows the sidebar to its project** (`sidebarProject`, an app preference): its group, its pinned chats, its archived ones, and of each section the chats that are its, a section with none of them left out; "No folder" is left out too. All projects shows everything. The tile picked wears a ring of `accentInk`, 2 wide and 2 off the tile, so it reads on a tile of any color. ⌘1–⌘9 and ⌘[ ⌘] go through what shows. When a chat of another project opens or starts, the sidebar goes to that project (to all, for a chat with no folder), so the open chat's row is never left out; picking a tile opens nothing.
- **What a tile shows**, first of: what the user set in **Change tile…** (an emoji or up to two characters, and one of the eight chat colors; either without the other); the repository's own icon; the folder's initials (the first letters of its first two words, or a word's first two) on a color. Colors are `Tokens.avatars`, as a chat's color is, kept by name, never a hex. A project with no chosen color takes the one its path names unless a project that joined the sidebar before it has it, then the next free: up to eight projects all differ, and a project's color changes only if an earlier one is removed.
- **The repository's icon comes from the daemon** (`GetProjectIcon`, API 116; `internal/projecticon`): the app never reads a project's files. Only these paths, in this order, each as `.png` then `.jpg`: `icon`, `logo`, `.github/icon`, `.github/logo`, `assets/icon`, `assets/logo`, `docs/images/logo`; then the PNG with the most pixels in `Assets.xcassets/AppIcon.appiconset`, `macos/Runner/…` or `app/macos/Runner/…` of the same; then `build/icon`, `src-tauri/icons/icon`, `public/icon`, `public/logo`, `public/favicon`, `static/favicon`, `web/favicon`, `app/web/favicon`. A file is taken only if it's a regular file inside the folder (no link followed), 256 KiB at most, a PNG or JPEG by its first bytes, 32 to 1,024 pixels a side and no more than half again as wide as high; else the next path is tried. The app asks once per folder and keeps the answer until it quits. The limits are in `docs/security.md`.
- **The same tile, 18 square**, starts each project's header in the list. A project's menu (its header's and its tile's right-click) gained **Change tile…**.
- **It shows when the sidebar is arranged by project**, the Arrange menu's **Project rail** is checked (`projectRail`, on at first), and the sidebar is at least 250 wide. Narrower, or under another grouping, there's no rail and the sidebar shows every project.
- **The sidebar keeps its width.** The rail takes 54 of it from the chats: showing or hiding it moves neither the sidebar's edge nor the buttons in its strip (ADR 0111: a toggle never moves when pressed).

## Consequences
- At the sidebar's first width (260) the chats' rows are 54 narrower with the rail. At 250, where the rail goes, they have what the sidebar's own minimum (200) gives them without it.
- A daemon older than API 116 answers no icon; tiles show initials until it's replaced, and the app asks again once it's back.
- No SVG and no ICO: the app draws neither without a new dependency, and an SVG is a document someone else wrote. A repository with only a `favicon.ico` or a `logo.svg` gets initials.
- The daemon doesn't know the sidebar's projects (the app keeps them), so it can't check the folder against them: the call is the Mac's only (`macOnly`, and the handler checks for the Mac's socket), as the calls that read any folder's git state are.
- The phone has no rail: its list is one column of every project.

## Alternatives considered
- Widening the sidebar by the rail's width: its edge, and Arrange and the hide button with it, would move each time the rail came or went.
- Keeping the rail at any width: under 250 the rows beside it are too narrow to read a title.
- A color from the path alone: with five projects two often shared one. In the rail's order rather than the order joined: dragging a project would recolor others.
- Tiles as the only list of projects, the groups' headers gone: Remove from sidebar, the collapse and the + live on the header, and the other groupings have no rail.
- Asking the daemon for the kept projects' icons only: it would need the app's list sent to it first, for a call the Mac alone can make anyway.
